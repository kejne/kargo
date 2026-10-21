# OCI Helm chart annotations: local demo

A disposable kind lab for [akuity/kargo#4416](https://github.com/akuity/kargo/issues/4416).
It builds **this checkout**, installs Kargo from the local Helm chart, and creates
a Project and Warehouse watching:

```text
oci://codeberg.org/kejne/charts/fluxcd:0.1.1
```

No annotation-based selection criteria, Argo CD, Argo Rollouts, or application
promotion are needed. The Flux chart itself is not installed.

## Run

Prerequisites: Docker with a running daemon, kind, kubectl, Helm 3, and Bash.
Allow several GB of memory/disk space and internet access to pull dependencies.
The first run builds both the Go backend and embedded dashboard inside Docker.

From the repository root:

```bash
./testdata/helm-oci-annotations/setup.sh
```

The script builds a minimal local image, creates or reuses the dedicated kind
cluster, installs cert-manager and Kargo (including PostgreSQL and NATS), and
applies `project.yaml` and `warehouse.yaml`. It waits for the Warehouse to be ready
and prints the dashboard port-forward command.

It uses an isolated kubeconfig in the ignored `.state/` directory and does not
change your default kubeconfig or current context. All cluster operations target
`kind-kargo-helm-annotations` explicitly.

Optional: use `CLUSTER_NAME=another-name` for another dedicated kind cluster, or
`KARGO_IMAGE=my-kargo:annotations` to skip building and load an already-built local
image. A published release without this feature will not display chart annotations.

## See the annotations

Run the port-forward command printed by setup, or:

```bash
kubectl --kubeconfig testdata/helm-oci-annotations/.state/kargo-helm-annotations.kubeconfig \
  --context kind-kargo-helm-annotations -n kargo \
  port-forward service/kargo-api 8080:80
```

1. Open <http://localhost:8080> and log in with **admin / admin**.
2. Open the **helm-oci-annotations** Project and select the automatically created
   Freight in its timeline.
3. Open the Helm chart's artifact metadata. Check the OCI annotations, source
   link to `https://codeberg.org/kejne/smedijan`, and build timestamp.
4. Capture this view for the PR.

The published example includes `org.opencontainers.image.title=fluxcd`,
`org.opencontainers.image.version=0.1.1`, `org.opencontainers.image.source`, and
`org.opencontainers.image.created`. It currently has no revision annotation, so
no commit-specific source link is expected. This demo reads OCI manifest metadata,
not annotations extracted from `Chart.yaml`.

To inspect the same metadata in Kubernetes:

```bash
kubectl --kubeconfig testdata/helm-oci-annotations/.state/kargo-helm-annotations.kubeconfig \
  --context kind-kargo-helm-annotations -n helm-oci-annotations get warehouse fluxcd -o yaml
kubectl --kubeconfig testdata/helm-oci-annotations/.state/kargo-helm-annotations.kubeconfig \
  --context kind-kargo-helm-annotations -n helm-oci-annotations get freight -o yaml
```

Compare `status.discoveredArtifacts.charts[0].annotations['0.1.1']` on the Warehouse
with `charts[0].annotations` on the Freight. If discovery fails, inspect the
Warehouse's status message; the example depends on the public Codeberg chart
remaining available.

## Cleanup

```bash
kind delete cluster --name kargo-helm-annotations
```

The credentials in `kargo-values.yaml` are **local fixtures only**. Do not expose
this installation publicly. The demo uses a minimal runtime image rather than a
production release image.
