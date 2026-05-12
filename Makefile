.PHONY: up down build deploy test

# Default target — full local dev flow in one command
up: build deploy
@echo ""
@echo "== Service is up =="
@echo "Run: kubectl port-forward svc/fileserver-dev 8080:8080"
@echo "Then: curl http://localhost:8080/test.txt"

build:
docker build -t fileserver:latest ./app

deploy:
cd terraform && terraform init && terraform apply -var-file=dev.tfvars -auto-approve

down:
cd terraform && terraform destroy -var-file=dev.tfvars -auto-approve

test:
@echo "Testing file read..."
curl -sf http://localhost:8080/test.txt && echo " PASS" || echo " FAIL"
@echo "Testing 404 response..."
curl -sf http://localhost:8080/missing.txt; [ $$? -eq 22 ] && echo " PASS" || echo " FAIL"

# Azure target (requires az login and bootstrapped tfstate storage)
azure-up:
cd terraform/azure && terraform init && terraform apply -var-file=dev.tfvars -auto-approve

azure-down:
cd terraform/azure && terraform destroy -var-file=dev.tfvars -auto-approve
