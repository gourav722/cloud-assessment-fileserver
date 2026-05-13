# Cloud Assessment — File Server

A production-style cloud delivery for a Go HTTP file server.  
Serves files from a persistent local directory with in-memory caching.  
Returns `200` with file contents on a hit, `404` JSON on a miss.

---

## What This Repo Covers

| Area | Implementation |
|---|---|
| Application | Go HTTP file server with in-memory cache |
| Container | Multi-stage Dockerfile, non-root user |
| IaC | Terraform modules (kind + Azure stub) |
| Kubernetes | Helm chart with dev/prod values, PVC, probes |
| Persistent Storage | PersistentVolumeClaim — survives pod restarts |
| CI/CD | GitHub Actions — lint → build → push → deploy-dev → deploy-prod (gated) |
| Registry | GHCR (GitHub Container Registry) |

---

## Prerequisites

### Windows — install everything via winget

Open PowerShell **as Administrator** and run:

```powershell
winget install Docker.DockerDesktop
winget install Kubernetes.kind
winget install Kubernetes.kubectl
winget install Helm.Helm
winget install Hashicorp.Terraform
winget install GoLang.Go
winget install GnuWin32.Make
```

Restart PowerShell after installing, then verify:

```powershell
docker --version
kind --version
kubectl version --client
helm version
terraform --version
go version
make --version
```

> **Run make commands in Git Bash** (included with Git for Windows), not PowerShell.  
> Add make to PATH in Git Bash: `export PATH=$PATH:/c/Program\ Files\ \(x86\)/GnuWin32/bin`  
> Make it permanent: `echo 'export PATH=$PATH:/c/Program\ Files\ \(x86\)/GnuWin32/bin' >> ~/.bashrc`

> **Docker Desktop** must be running before `make up`. Open it from Start Menu and wait for **"Engine running"** in the bottom left.

### Linux / Mac — install via package manager

```bash
# Mac (Homebrew)
brew install kind kubectl helm terraform go make
brew install --cask docker

# Ubuntu/Debian
sudo apt-get install docker.io golang make
# kind, kubectl, helm, terraform — follow official docs below
```

### Required versions

| Tool | Version | Docs |
|---|---|---|
| Docker Desktop | >= 24.0 | https://www.docker.com/products/docker-desktop |
| kind | >= 0.20 | https://kind.sigs.k8s.io/docs/user/quick-start |
| kubectl | >= 1.28 | https://kubernetes.io/docs/tasks/tools |
| Helm | >= 3.12 | https://helm.sh/docs/intro/install |
| Terraform | >= 1.5.0 | https://developer.hashicorp.com/terraform/install |
| Go | >= 1.24 | https://go.dev/dl |
| make | any | built-in on Linux/Mac |

---

## Single-Command Reproduction

Clone the repo and run one command:

```bash
git clone https://github.com/gourav722/cloud-assessment-fileserver.git
cd cloud-assessment-fileserver
make up
```

This will:
1. Build the Docker image
2. Provision a local kind cluster via Terraform
3. Create a PersistentVolumeClaim
4. Deploy the application via Helm
5. Print the status of all Kubernetes resources

---

## Verify It Works

Open a second terminal and run:

```bash
# Start port-forward
make open
```

Then in a third terminal:

```bash
# Test 1 — file exists (expect 200 + file contents)
curl http://localhost:8080/test.txt

# Test 2 — file missing (expect 404 + JSON error)
curl http://localhost:8080/missing-file.txt
```

Expected responses:

```bash
# test.txt
seeded file from initContainer

# missing-file.txt
{"error":"file not found"}
```

Or run both tests automatically:

```bash
make test
```

---

## Tear Down

```bash
make down
```

Destroys the kind cluster and all resources.

---

## Available Make Commands

| Command | Description |
|---|---|
| `make up` | Build + provision + deploy (dev) |
| `make down` | Destroy dev cluster |
| `make open` | Port-forward service to localhost:8080 |
| `make test` | Run curl tests against the service |
| `make status` | Show pods, PVC, services |
| `make azure-up` | Deploy to Azure AKS (requires `az login`) |
| `make azure-down` | Destroy Azure environment |

---

## Project Structure

```
.
├── app/                        # Go application
│   ├── main.go                 # HTTP file server with 404 JSON handler
│   ├── Dockerfile              # Multi-stage, non-root, minimal Alpine image
│   └── go.mod / go.sum
│
├── helm/fileserver/            # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml             # Base values
│   ├── values-dev.yaml         # Dev overrides (1 replica, low resources)
│   ├── values-prod.yaml        # Prod overrides (2 replicas, RWX storage)
│   └── templates/
│       ├── deployment.yaml     # Init container seeds /data, probes configured
│       ├── service.yaml
│       ├── NOTES.txt           # Post-install instructions
│       └── _helpers.tpl
│
├── terraform/
│   ├── main.tf                 # Kind cluster root
│   ├── dev.tfvars
│   ├── prod.tfvars
│   ├── modules/
│   │   ├── cluster/            # Provisions kind cluster
│   │   ├── pvc/                # PersistentVolumeClaim (cloud-agnostic)
│   │   └── helm/               # Helm release (cloud-agnostic)
│   └── azure/                  # Azure stub (non-runnable, shows portability)
│       ├── main.tf             # Wires AKS + ACR + reuses pvc/ and helm/
│       ├── dev.tfvars
│       ├── prod.tfvars
│       └── modules/
│           ├── aks/            # AKS cluster + AcrPull role
│           └── acr/            # Azure Container Registry
│
├── .github/workflows/
│   └── fileserver.yml                  # 4-job pipeline (lint → build → deploy-dev → deploy-prod)
│
├── ARCHITECTURE.md             # Design decisions, trade-offs, runbook
├── Makefile                    # Single-command orchestration
└── README.md                   # This file
```

---

## CI/CD Pipeline

```
lint-and-validate
      ↓ must pass
build-and-push          → pushes to ghcr.io/gourav722/fileserver:<sha>
      ↓ must pass
deploy-dev              → kind cluster, HTTP tests (automatic)
      ↓ must pass
deploy-prod             → pauses for manual approval (environment: prod)
```

**Gating strategy:**
- `main` branch is protected — all changes arrive via Pull Request
- CI must pass before merge is allowed
- `deploy-prod` requires manual approval via GitHub Environment protection
- This keeps humans in the loop for production regardless of CI speed

**Image tagging:** commit SHA — immutable and fully traceable.

---

## Persistent Storage

The file directory `/data` is mounted via a `PersistentVolumeClaim` and survives:
- Pod restarts
- Rolling updates
- Helm upgrades

| Environment | StorageClass | Access Mode | Why |
|---|---|---|---|
| Dev (kind) | `standard` | ReadWriteOnce | Single replica, local provisioner |
| Dev (Azure) | `managed-csi` | ReadWriteOnce | Managed disk, low latency |
| Prod (Azure) | `azurefile-csi` | ReadWriteMany | Multi-replica, all pods share `/data` |

Initial files are seeded by an `initContainer` on first start.

---

## Azure Cloud Target

The `terraform/azure/` directory is a non-runnable stub showing how the same `pvc/` and `helm/` modules are reused for AKS. Only the cluster and registry modules differ:

```
kind target:   modules/cluster  →  kind provider
Azure target:  modules/aks      →  AKS + managed identity
               modules/acr      →  Azure Container Registry + AcrPull role
```

To run against a real Azure subscription:

```bash
az login
make azure-up
```

---

## Container Image

```bash
# Pull the latest image
docker pull ghcr.io/gourav722/fileserver:<sha>
```

Image is public on GHCR. Find the latest SHA in the Actions tab or Packages page:
```
https://github.com/gourav722?tab=packages
```
