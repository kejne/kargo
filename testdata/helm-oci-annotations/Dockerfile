# Reuse the repository's build stages, including the embedded dashboard.
ARG BUILDER_IMAGE=kargo-helm-annotations-builder:local
FROM ${BUILDER_IMAGE} AS builder

# Minimal runtime for this discovery/visualization lab, not a release image.
FROM alpine:3.23
RUN apk add --no-cache ca-certificates git tini && \
    adduser -D -H -u 1000 kargo
COPY --from=builder /kargo/bin/ /usr/local/bin/
USER 1000:0
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/kargo"]
