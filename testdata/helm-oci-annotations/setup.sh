#!/usr/bin/env bash
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$here/../.." && pwd)
cluster=${CLUSTER_NAME:-kargo-helm-annotations}
context="kind-$cluster"
kubeconfig="$here/.state/$cluster.kubeconfig"

for tool in docker kind kubectl helm; do
  command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
done
docker info >/dev/null

# A published release does not contain this change. Build this checkout by default.
image=${KARGO_IMAGE:-"kargo-helm-annotations:$(date +%s)"}
if [[ ${image##*/} != *:* || $image == *@* ]]; then
  echo 'KARGO_IMAGE must be a tagged image, not a digest reference' >&2
  exit 1
fi
if [[ -z ${KARGO_IMAGE:-} ]]; then
  docker build --target back-end-builder --tag kargo-helm-annotations-builder:local "$root"
  docker build --tag "$image" "$here"
fi

mkdir -p "$here/.state"
# Never change the user's default kubeconfig or target an ambient context.
if kind get clusters | grep -Fxq "$cluster"; then
  kind export kubeconfig --name "$cluster" --kubeconfig "$kubeconfig"
else
  kind create cluster --name "$cluster" --kubeconfig "$kubeconfig" --wait 120s
fi
kind load docker-image --name "$cluster" "$image"
kube=(kubectl --kubeconfig "$kubeconfig" --context "$context")
helm_context=(--kubeconfig "$kubeconfig" --kube-context "$context")

helm upgrade --install cert-manager cert-manager \
  "${helm_context[@]}" \
  --repo https://charts.jetstack.io --version v1.19.3 \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true --wait --timeout 5m

# The chart pins NATS exactly. Update also works without a preconfigured Helm repo.
helm dependency update "$root/charts/kargo"
helm upgrade --install kargo "$root/charts/kargo" \
  "${helm_context[@]}" \
  --namespace kargo --create-namespace \
  --values "$here/kargo-values.yaml" \
  --set-string "image.repository=${image%:*}" \
  --set-string "image.tag=${image##*:}" \
  --set image.pullPolicy=Never \
  --wait --wait-for-jobs --timeout 10m

"${kube[@]}" apply -f "$here/project.yaml"
"${kube[@]}" wait --for=condition=Ready project/helm-oci-annotations --timeout=120s
"${kube[@]}" apply -f "$here/warehouse.yaml"

"${kube[@]}" --namespace helm-oci-annotations wait \
  --for=condition=Ready warehouse/fluxcd --timeout=300s

printf '\nOpen the dashboard with:\n'
printf 'kubectl --kubeconfig %q --context %q -n kargo port-forward service/kargo-api 8080:80\n' \
  "$kubeconfig" "$context"
printf '\nVisit http://localhost:8080 and log in with admin / admin.\n'
