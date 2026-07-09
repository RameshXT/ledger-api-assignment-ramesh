# Task 2 — Secure CI/CD Pipeline & Supply Chain — Checklist

## REQUIRED ITEMS

### 1. GitHub Actions pipeline
- [x] Build image from task-1-hardening/app (or move/reference the app appropriately)
- [x] Push to GHCR (GitHub Container Registry)
- [x] Use free GitHub-hosted runners only — no cloud account

### 2. Security gates wired into pipeline
- [x] SAST — Semgrep
- [x] Dependency/CVE scan — Trivy or Grype
- [x] Image scan — Trivy (container image scanning, not just deps)
- [x] Secrets scan — Gitleaks

### 3. Signing and provenance
- [x] Sign image with Cosign (keyless mode, using GitHub OIDC)
- [x] Generate SLSA-style provenance/attestation

### 4. Fail policy documentation
- [x] For each gate above, explicitly state: what hard-blocks the pipeline, 
      what only warns, and how a CVE with no available fix yet is handled

### 5. GitOps with ArgoCD
- [x] Create ArgoCD Application resource pointing at this repo
- [x] Demonstrate drift detection: manually kubectl edit a live resource, 
      show ArgoCD detects the drift
- [x] Demonstrate self-heal: show ArgoCD automatically reverts the manual change

## BONUS ITEMS
- [ ] Upload scanner results as SARIF format so they appear in GitHub Security tab
- [ ] Cosign verify output proving the image was signed by this workflow (not 
      just that signing happened, but verifiable proof tied to the workflow identity)
- [ ] Canary or blue-green rollout strategy

## EVIDENCE/DOCUMENTATION REQUIREMENTS
- [ ] README.md explaining approach and design decisions
- [ ] EVIDENCE.md with real pipeline run outputs/links, scan results, 
      cosign verify output, ArgoCD drift/self-heal proof
- [ ] Architecture diagram showing the full pipeline flow
