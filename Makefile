# ============================================================
# Usage:
#   make up       — build + provision + deploy (dev)
#   make down     — teardown dev cluster
#   make test     — curl tests against running service
#   make open     — port-forward so you can curl locally
#   make status   — show pods, pvc, svc
#   make azure-up — deploy to Azure (requires az login)
# ============================================================

CLUSTER_NAME  = fileserver-cluster-dev
RELEASE_NAME  = fileserver-dev
SERVICE_NAME  = fileserver-dev
SERVICE_PORT  = 8080
LOCAL_PORT    = 8080

.PHONY: up down build deploy open test status azure-up azure-down

# ---------------------------------------------------------------
# Single command the reviewer runs
# ---------------------------------------------------------------
up: build deploy status
	@echo ""
	@echo "================================================="
	@echo " Deployment complete!"
	@echo " Run:  make open     (starts port-forward)"
	@echo " Then: make test     (verifies the service)"
	@echo "================================================="

# ---------------------------------------------------------------
# Build Docker image
# ---------------------------------------------------------------
build:
	@echo "=> Building Docker image..."
	docker build -t fileserver:latest ./app
	@echo "=> Done"

# ---------------------------------------------------------------
# Provision cluster + PVC + deploy via Helm (Terraform)
# ---------------------------------------------------------------
deploy:
	@echo "=> Running Terraform (kind cluster + PVC + Helm)..."
	cd terraform && terraform init -backend=false
	cd terraform && terraform apply -var-file=dev.tfvars -auto-approve
	@echo "=> Done"

# ---------------------------------------------------------------
# Port-forward so you can curl the service locally
# Runs in foreground — Ctrl+C to stop
# ---------------------------------------------------------------
open:
	@echo "=> Port-forwarding $(SERVICE_NAME):$(SERVICE_PORT) -> localhost:$(LOCAL_PORT)"
	@echo "   Press Ctrl+C to stop"
	@echo ""
	kubectl port-forward svc/$(SERVICE_NAME) $(LOCAL_PORT):$(SERVICE_PORT)

# ---------------------------------------------------------------
# HTTP tests — run after make open in a separate terminal
# ---------------------------------------------------------------
test:
	@echo "=> Starting port-forward in background..."
	@kubectl port-forward svc/$(SERVICE_NAME) $(LOCAL_PORT):$(SERVICE_PORT) & \
	PF_PID=$$!; \
	sleep 3; \
	echo ""; \
	echo "--- Test 1: File read (expect 200) ---"; \
	STATUS=$$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$(LOCAL_PORT)/test.txt); \
	echo "HTTP status: $$STATUS"; \
	BODY=$$(curl -s http://localhost:$(LOCAL_PORT)/test.txt); \
	echo "Body: $$BODY"; \
	if [ "$$STATUS" = "200" ]; then echo "PASS"; else echo "FAIL"; kill $$PF_PID; exit 1; fi; \
	echo ""; \
	echo "--- Test 2: Missing file (expect 404) ---"; \
	STATUS=$$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$(LOCAL_PORT)/missing.txt); \
	echo "HTTP status: $$STATUS"; \
	BODY=$$(curl -s http://localhost:$(LOCAL_PORT)/missing.txt); \
	echo "Body: $$BODY"; \
	if [ "$$STATUS" = "404" ]; then echo "PASS"; else echo "FAIL"; kill $$PF_PID; exit 1; fi; \
	echo ""; \
	echo "All tests passed!"; \
	kill $$PF_PID

# ---------------------------------------------------------------
# Show current cluster state
# ---------------------------------------------------------------
status:
	@echo "=> Cluster status:"
	@kubectl get pods
	@kubectl get pvc
	@kubectl get svc

# ---------------------------------------------------------------
# Tear down everything
# ---------------------------------------------------------------
down:
	@echo "=> Destroying dev environment..."
	cd terraform && terraform destroy -var-file=dev.tfvars -auto-approve
	@echo "=> Done"

# ---------------------------------------------------------------
# Azure target (requires: az login + bootstrapped tfstate storage)
# ---------------------------------------------------------------
azure-up:
	@echo "=> Deploying to Azure..."
	cd terraform/azure && terraform init
	cd terraform/azure && terraform apply -var-file=dev.tfvars -auto-approve

azure-down:
	@echo "=> Destroying Azure environment..."
	cd terraform/azure && terraform destroy -var-file=dev.tfvars -auto-approve
