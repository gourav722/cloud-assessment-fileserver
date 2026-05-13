# ============================================================
# test-local.ps1
# Mirrors every step in ci.yml so you can verify locally
# before pushing to GitHub.
#
# Run from project root: .\test-local.ps1
# Prerequisites: Go, Docker Desktop, kind, kubectl, helm, terraform
# ============================================================

$ErrorActionPreference = "Stop"
$SHA = git rev-parse --short HEAD

function Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Pass($msg) { Write-Host "    PASS: $msg" -ForegroundColor Green }
function Fail($msg) { Write-Host "    FAIL: $msg" -ForegroundColor Red; exit 1 }

# ----------------------------------------------------------------
# 1. Go build + test
# ----------------------------------------------------------------
Step "Go Build"
Set-Location app
go build .
if ($LASTEXITCODE -ne 0) { Fail "go build failed" }
Pass "go build"

Step "Go Test"
go test ./... -v
if ($LASTEXITCODE -ne 0) { Fail "go test failed" }
Pass "go test"
Set-Location ..

# ----------------------------------------------------------------
# 2. Helm lint
# ----------------------------------------------------------------
Step "Helm Lint (base)"
helm lint helm/fileserver
if ($LASTEXITCODE -ne 0) { Fail "helm lint base failed" }
Pass "helm lint base"

Step "Helm Lint (dev values)"
helm lint helm/fileserver -f helm/fileserver/values-dev.yaml
if ($LASTEXITCODE -ne 0) { Fail "helm lint dev failed" }
Pass "helm lint dev"

Step "Helm Lint (prod values)"
helm lint helm/fileserver -f helm/fileserver/values-prod.yaml
if ($LASTEXITCODE -ne 0) { Fail "helm lint prod failed" }
Pass "helm lint prod"

# ----------------------------------------------------------------
# 3. Terraform validate — kind
# ----------------------------------------------------------------
Step "Terraform Init + Validate (kind)"
Set-Location terraform
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
if ($LASTEXITCODE -ne 0) { Fail "terraform validate (kind) failed" }
Pass "terraform validate kind"
Set-Location ..

# ----------------------------------------------------------------
# 4. Terraform validate — azure stub
# ----------------------------------------------------------------
Step "Terraform Init + Validate (azure stub)"
Set-Location terraform/azure
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
if ($LASTEXITCODE -ne 0) { Fail "terraform validate (azure) failed" }
Pass "terraform validate azure"
Set-Location ../..

# ----------------------------------------------------------------
# 5. Docker build
# ----------------------------------------------------------------
Step "Docker Build"
docker build -t "fileserver:$SHA" ./app
if ($LASTEXITCODE -ne 0) { Fail "docker build failed" }
Pass "docker build fileserver:$SHA"

# ----------------------------------------------------------------
# 6. kind cluster
# ----------------------------------------------------------------
Step "Create kind Cluster (skipping if already exists)"
$existing = kind get clusters 2>$null | Where-Object { $_ -eq "chart-testing" }
if (-not $existing) {
    kind create cluster --name chart-testing
    if ($LASTEXITCODE -ne 0) { Fail "kind create cluster failed" }
}
Pass "kind cluster ready"

# ----------------------------------------------------------------
# 7. Load image into kind
# ----------------------------------------------------------------
Step "Load image into kind"
kind load docker-image "fileserver:$SHA" --name chart-testing
if ($LASTEXITCODE -ne 0) { Fail "kind load failed" }
Pass "image loaded into kind"

# ----------------------------------------------------------------
# 8. Create PVC
# ----------------------------------------------------------------
Step "Create PVC"
@"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fileserver-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
"@ | kubectl apply -f -
if ($LASTEXITCODE -ne 0) { Fail "PVC creation failed" }
Pass "PVC created"

# ----------------------------------------------------------------
# 9. Helm deploy
# ----------------------------------------------------------------
Step "Helm Deploy"
helm upgrade --install fileserver ./helm/fileserver `
    --set image.repository=fileserver `
    --set "image.tag=$SHA" `
    --set image.pullPolicy=Never `
    --set existingPvc=fileserver-pvc `
    --wait `
    --timeout 90s
if ($LASTEXITCODE -ne 0) { Fail "helm deploy failed" }
Pass "helm deploy"

# ----------------------------------------------------------------
# 10. Verify resources
# ----------------------------------------------------------------
Step "Verify Kubernetes Resources"
kubectl get pods
kubectl get pvc
kubectl get svc

# ----------------------------------------------------------------
# 11. HTTP tests
# ----------------------------------------------------------------
Step "End-to-End HTTP Tests"

Write-Host "    Starting port-forward (svc/fileserver 8080->8081)..."
$pf = Start-Process -FilePath "kubectl" `
    -ArgumentList "port-forward svc/fileserver 8080:8081" `
    -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 5

try {
    # Test 1 — happy path
    Write-Host "    Test 1: GET /test.txt (expect 200)"
    $r = Invoke-WebRequest -Uri "http://localhost:8080/test.txt" -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        Pass "200 OK — body: $($r.Content)"
    } else {
        Fail "Expected 200, got $($r.StatusCode)"
    }

    # Test 2 — 404 path
    Write-Host "    Test 2: GET /missing-file.txt (expect 404)"
    try {
        Invoke-WebRequest -Uri "http://localhost:8080/missing-file.txt" -UseBasicParsing | Out-Null
        Fail "Expected 404 but got 200"
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        $body   = $_.ErrorDetails.Message
        if ($status -eq 404 -and $body -match "file not found") {
            Pass "404 with correct JSON body: $body"
        } else {
            Fail "Got status $status, body: $body"
        }
    }

} finally {
    Stop-Process -Id $pf.Id -Force -ErrorAction SilentlyContinue
}

# ----------------------------------------------------------------
# Done
# ----------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " All local tests passed — safe to push!    " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  git add .github/workflows/ci.yml"
Write-Host "  git commit -m 'ci: add full pipeline with HTTP end-to-end tests'"
Write-Host "  git push origin main"
Write-Host ""
Write-Host "Then watch the run at:"
Write-Host "  https://github.com/<your-username>/<repo>/actions" -ForegroundColor Cyan

# ----------------------------------------------------------------
# Cleanup (optional — comment out to keep cluster for manual testing)
# ----------------------------------------------------------------
# Step "Teardown kind cluster"
# kind delete cluster --name chart-testing
