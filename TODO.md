# BuildBuddy Helm Chart - Next Steps & TODO

This document outlines the remaining features and improvements required to make the `buildbuddy-k8s` Helm chart fully production-ready. These are instructions and a roadmap for further development.

## 1. Implement BuildBuddy Executor
The BuildBuddy application supports Remote Execution via a dedicated executor service. 
- **Task**: Create an optional `buildbuddy-executor` StatefulSet/Deployment template.
- **Details**:
  - Add `executor.enabled` toggle to `values.yaml`.
  - Create `templates/executor-statefulset.yaml` using the `ghcr.io/buildbuddy-io/buildbuddy-executor` image.
  - Expose internal health checks and define required VolumeMounts (often an executor cache and workspace).
  - Configure RBAC (`Role` and `RoleBinding`) if the executor uses the Kubernetes scheduler to spawn test pods dynamically.

## 2. Introduce Core Dependencies (Database & Cache)
Currently, `values.yaml` defaults to a local SQLite database and local disk caching, which won't survive pod reloads or scale beyond 1 replica.
- **Task**: Add declarative external dependencies.
- **Details**:
  - Add standard bitnami `redis` and `postgresql` as optional subcharts in `Chart.yaml` (dependencies).
  - Update `templates/configmap.yaml` to dynamically inject the PostgreSQL connection string and Redis host string into the config block when these subcharts are enabled.

## 3. Secure Secrets Management
Avoid placing sensitive database credentials, API keys, or certificates in the plaintext ConfigMap.
- **Task**: Implement a `Secret` wrapper.
- **Details**:
  - Create `templates/secret.yaml`.
  - Introduce `existingSecret` fields in `values.yaml` to allow users to link existing Kubernetes secrets (e.g., from ExternalSecrets or HashiCorp Vault).
  - Mount configurations or pull environment variables directly from these mapped secrets instead of the ConfigMap.

## 4. Ingress TLS & gRPC Routing
BuildBuddy relies heavily on gRPC over port 1985 for RBE (Remote Build Execution). Many Ingress controllers (like NGINX) require specific annotations to handle gRPC properly.
- **Task**: Solidify the Ingress routing.
- **Details**:
  - Add specific gRPC ingress block (or annotations like `nginx.ingress.kubernetes.io/backend-protocol: "GRPC"`) under `templates/ingress.yaml` to properly route RBE traffic safely through TLS.
  - Link Certificate provisioning configurations for automatic SSL/TLS via cert-manager.

## 5. High Availability & Affinity Rules
The current chart creates a vanilla 1-replica StatefulSet.
- **Task**: Implement proper Pod Anti-Affinity and disruption budgets.
- **Details**:
  - Introduce an optional `PodDisruptionBudget` template.
  - Finalize standard `affinity` rules inside `values.yaml` to prevent BuildBuddy app pods from scheduling onto the same backend node, ensuring redundancy against node failures. 

---
**Note for Codex/Agent:** Pick up these tasks sequentially. Prioritize the Executor template and Redis/PostgreSQL dependency integrations, as these immediately unblock multi-replica Remote Execution.
