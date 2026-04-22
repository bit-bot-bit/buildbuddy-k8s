# buildbuddy-k8s

Helm chart for deploying BuildBuddy on Kubernetes with optional production-oriented
features:

- Bitnami `postgresql` and `redis` dependencies
- Optional BuildBuddy executor StatefulSet for remote execution
- Secret-backed environment injection and external config secret support
- Separate HTTP and gRPC ingress definitions
- Pod disruption budgets, service accounts, and executor RBAC

## Repository usage

This repository is structured as a standalone Helm chart repository. The chart root
is the repository root, not a nested `charts/<name>` directory.

GitHub Actions are expected to:

- lint and render the chart on every change
- package the chart into a `.tgz` artifact
- publish the packaged chart to a GitHub Release on successful `main` builds

## Current defaults

The chart still boots with a simple single-replica app deployment backed by local
disk and SQLite. Production features are opt-in.

## Example: app only

```yaml
replicaCount: 1
service:
  type: ClusterIP
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: buildbuddy.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Example: production-oriented install

```yaml
replicaCount: 2
pdb:
  enabled: true
  minAvailable: 1

postgresql:
  enabled: true

redis:
  enabled: true

ingress:
  enabled: true
  className: nginx
  certManager:
    clusterIssuer: letsencrypt
  hosts:
    - host: buildbuddy.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: buildbuddy-tls
      hosts:
        - buildbuddy.example.com
  grpc:
    enabled: true
    hosts:
      - host: grpc.buildbuddy.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: buildbuddy-grpc-tls
        hosts:
          - grpc.buildbuddy.example.com

executor:
  enabled: true
  replicaCount: 2
  pdb:
    enabled: true
    minAvailable: 1
```

## Secret handling

- Set `configExistingSecret` to mount an externally managed Secret containing
  `config.yaml`.
- Set `secretEnv` to generate a Secret from chart values and inject it with
  `envFrom`.
- Set `extraEnvSecrets` or `executor.extraEnvSecrets` to reference existing
  environment Secrets without templating their contents into Helm values.

## Packaging

The included workflow only builds the chart package artifact for downstream release
automation.

Chart versions are generated automatically from git tags:

- if no chart release tag exists yet, the initial package version is `0.1.0`
- if [Chart.yaml](/var/home/tearle/Work/build-buddy/buildbuddy-k8s/Chart.yaml:1)
  has no `version`, the initial package version still defaults to `0.1.0`
- each new package build advances the patch version relative to the latest chart
  tag in the repository
- if you later raise the base version in `Chart.yaml` manually, that becomes the
  next release floor

The workflow uploads the generated `.tgz` as a GitHub Actions artifact and, on
successful `main` builds, publishes the same chart package to a versioned GitHub
Release.

## Release publishing

On successful pushes to `main`, the CI workflow now:

- computes the chart version
- packages `buildbuddy-<version>.tgz`
- creates or updates the GitHub Release tagged `buildbuddy-v<version>`
- uploads the packaged chart asset to that release

Example:

- tag: `buildbuddy-v0.1.0`
- release asset: `buildbuddy-0.1.0.tgz`

That is the stable URL Argo CD and Helmfile can fetch:

`https://github.com/bit-bot-bit/buildbuddy-k8s/releases/download/buildbuddy-v0.1.0/buildbuddy-0.1.0.tgz`
