# Secure CI/CD Pipeline & Supply Chain - Task 2

This folder contains the secure delivery pipeline and supply-chain configurations for the `ledger-api` service, ensuring that security is enforced by automation rather than human memory.

---

## What was built

I built a complete, secure delivery path for the `ledger-api` image:
1. **Automated Pipeline**: A GitHub Actions workflow (`.github/workflows/ci-cd.yml`) that builds, scans, signs, and deploys the container image.
2. **Security Gates**: Wired parallel Gitleaks (secrets scan) and Semgrep (SAST scan) checks as blocking gates, followed by post-build Trivy scans (for dependency CVEs and container base image vulnerabilities).
3. **Cosign keyless OIDC signing**: Container images are signed cryptographically using GitHub's OpenID Connect (OIDC) identity token.
4. **SLSA Provenance**: An attestation of the build provenance is generated and pushed to GHCR alongside the image.
5. **GitOps CD**: ArgoCD monitors this repository and manages deployments to the local cluster, automatically detecting and correcting manual runtime modifications.

---

## Security Gates & Fail Policies

To ensure the gates do not become developer bottlenecks while maintaining high security posture, we configured specific fail policies:

### 1. Gitleaks (Secrets Scan)
* **Fail Policy**: Hard-blocks. Any detected plaintext secret stops the pipeline immediately.
* **Scan Scope**: Configured to run on the latest commit (`--log-opts=-1`) during pushes to keep daily developer workflows fast.

### 2. Semgrep (SAST)
* **Fail Policy**: Hard-blocks only on **`ERROR`** severity findings (e.g. SQLi, SSRF, unsafe deserialization). Non-critical findings (warnings/info) are logged but do not block.
* **Bypass Policy**: Intentionally deferred vulnerabilities (reserved for Task 4's penetration test) are silenced explicitly with inline `# nosemgrep` comments referencing our [DEFERRED-FINDINGS.md](./DEFERRED-FINDINGS.md) file.

### 3. Trivy (Dependency / Image Scan)
* **Fail Policy**: Hard-blocks on **`CRITICAL`** or **`HIGH`** severity vulnerabilities.
* **Vulnerability Fix Policy**: 
  - Upstream-patched findings must be resolved immediately (e.g. we upgraded `requests` to `2.32.3` and upgraded pip tools in the Dockerfile).
  - Unpatched OS-level vulnerabilities with no "Fixed Version" are managed using a `.trivyignore` file with explicit review/expiry dates (30 days) and documented justifications in [TRIVY-FINDINGS.md](./TRIVY-FINDINGS.md).

---

## Supply Chain Security: Cryptographic Signing & Provenance

To satisfy PCI compliance and secure the container supply chain:
* **Keyless Signing**: The workflow installs Cosign and requests an OIDC identity token from GitHub. Cosign exchanges this token for an ephemeral signing certificate, signing the image digest and uploading the signature to GHCR.
* **SLSA Provenance**: The pipeline generates a SLSA v0.2-compliant build provenance attestation (pointing to GitHub's OIDC builder) and attaches it to the container image on GHCR.

---

## GitOps Deployment with ArgoCD

Instead of using direct `kubectl apply` commands in our CI runners, we adopted GitOps:
* **ArgoCD Application**: Defined in `argocd-app.yaml` to monitor the `task-1-hardening/deploy` directory on the `main` branch.
* **Drift Detection & Self-Healing**: Configured with `selfHeal: true`. If a user manually edits a running resource on the cluster (e.g., scaling replicas or modifying configmaps), ArgoCD immediately flags the drift and reverts the cluster state back to the Git source of truth.

---

## Verification Evidence

Step-by-step verification traces, logs, and drift-detection proof are documented in [EVIDENCE.md](./EVIDENCE.md) in this folder.
