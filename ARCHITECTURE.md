# Architecture Document

## Overview

This service is a stateless Go HTTP file server backed by a persistent volume.
It reads files from `/data` (configurable via `DATA_DIR`), returns them with
in-memory caching on repeated reads, and returns a JSON 404 for unknown files.

```
┌─────────────────────────────────────────────────┐
│  Kubernetes Cluster (kind / AKS)                │
│                                                 │
│  ┌────────────┐    ┌─────────────────────────┐  │
│  │  Service   │───▶│  Deployment             │  │
│  │  ClusterIP │    │  fileserver:latest      │  │
│  └────────────┘    │                         │  │
│                    │  initContainer: busybox │  │
│                    │    seeds /data/test.txt │  │
│                    │                         │  │
│                    │  volumeMount: /data ────┼──┼──▶ PVC (managed-csi / azurefile-csi)
│                    └─────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

## IaC Module Abstraction

The Terraform layout separates cluster provisioning from application delivery:

| Module          | kind (local)         | Azure               |
|-----------------|----------------------|---------------------|
| `modules/cluster` | kind provider      | _not used_          |
| `modules/aks`   | _not used_           | AKS + AcrPull role  |
| `modules/acr`   | _not used_           | Azure Container Reg |
| `modules/pvc`   | default StorageClass | managed-csi / azurefile-csi |
| `modules/helm`  | local image name     | ACR-qualified tag   |

`modules/pvc` and `modules/helm` are **identical** in both targets.
Only the cluster and registry modules differ.

## Storage Trade-offs

| StorageClass     | Access Mode | Use case                     | Latency  |
|------------------|-------------|------------------------------|----------|
| `standard`       | RWO         | kind (local dev)             | local    |
| `managed-csi`    | RWO         | AKS single-replica dev       | ~0.5ms   |
| `azurefile-csi`  | RWX         | AKS multi-replica prod       | ~1–5ms   |

**Decision:** Dev uses `managed-csi` (RWO, 1 replica, cheaper).
Prod uses `azurefile-csi` (RWX, 2+ replicas, all pods share `/data`).

## Runbook

### Deploy (local kind)
```bash
make up
kubectl port-forward svc/fileserver-dev 8080:8080
curl http://localhost:8080/test.txt
```

### Deploy (Azure)
```bash
az login
# Bootstrap tfstate storage once:
az group create -n tfstate-rg -l eastus
az storage account create -n tfstatefileserver -g tfstate-rg --sku Standard_LRS
az storage container create -n tfstate --account-name tfstatefileserver
# Then:
make azure-up
```

### Roll back
```bash
helm rollback fileserver-dev -n default
# or via Terraform:
cd terraform && terraform apply -var-file=dev.tfvars -var="image_tag=<previous-sha>"
```

### Debug a missing-file report
1. `kubectl exec -it <pod> -- ls /data`  — confirm file exists on volume
2. `kubectl logs <pod>`  — check for path errors in app logs
3. `kubectl cp ./missing.txt <pod>:/data/missing.txt`  — seed file if missing

### Seed / restore the volume
```bash
# Copy files into the running pod:
kubectl cp ./myfiles/ <pod>:/data/

# Or re-run the init container by deleting and redeploying the pod.
```

## Next Steps (Week 2)
- Helm test hook (`helm test`) that curls the service post-deploy
- `values.schema.json` for Helm chart input validation
- Horizontal Pod Autoscaler based on CPU
- External-DNS + cert-manager for HTTPS ingress on AKS
- Azure Monitor / Log Analytics workspace wired to AKS OMS agent
- Separate tfstate per environment (dev.tfstate / prod.tfstate)
