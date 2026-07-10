# Dodo Payments: DevSecOps Assessment Submission

**Candidate:** Ramesh Kanna G
**Role:** Security & DevOps Engineer  
**Assessment:** Security & DevOps Engineer Technical Assessment

---

## Quick Navigation

| Task | Description | Folder |
| :--- | :--- | :--- |
| [Task 1: Workload Hardening](#task-1-deploy-and-harden-the-workload) | Kubernetes hardening, Sealed Secrets, Kyverno | [`task-1-hardening/`](./task-1-hardening/) |
| [Task 2: Secure CI/CD](#task-2-secure-cicd-pipeline-and-supply-chain) | GitHub Actions pipeline, Cosign, ArgoCD GitOps | [`task-2-cicd/`](./task-2-cicd/) |
| [Task 3: Service Mesh](#task-3-service-mesh-and-zero-trust-istio) | Istio mTLS, AuthorizationPolicy, NetworkPolicy | [`task-3-mesh/`](./task-3-mesh/) |
| [Task 4: Recon & Pentest](#task-4-reconnaissance-and-penetration-testing) | OSINT recon of dodopayments.tech + pentest of local target | [`task-4-recon-pentest/`](./task-4-recon-pentest/) |

---

## Task 1: Deploy and Harden the Workload

Took the original insecure `ledger-api` deployment (root container, plaintext secrets in git, no guardrails) and hardened it to production grade.

**What was done:**
- Non-root user (`10001`), read-only root filesystem, all capabilities dropped, `seccomp: RuntimeDefault`
- CPU/memory requests & limits + liveness/readiness probes on every container
- Dedicated least-privilege `ServiceAccount` with explicitly empty RBAC (`rules: []`)
- Secrets migrated out of git using **Sealed Secrets** (plaintext key gone from repo)
- **Kyverno** admission policies that reject root containers, `:latest` tags, and unsigned images
- **Bonus:** Persona-based RBAC (developer/operator/admin), Pod Security Standards `restricted` enforced at namespace, Kyverno rejection of the original insecure manifest demonstrated

### Evidence Links

| Artifact | Description |
| :--- | :--- |
| [README.md](./task-1-hardening/README.md) | Approach, design decisions, hardening rationale |
| [EVIDENCE.md](./task-1-hardening/EVIDENCE.md) | All command outputs, `kubectl` logs, Kyverno rejection events, Sealed Secrets verification |
| [Architecture Diagram](./task-1-hardening/task1-architecture-diagram.png) | Deployment topology and security layers |
| [deploy/](./task-1-hardening/deploy/) | All Kubernetes manifests (deployment, RBAC, Kyverno policies, Sealed Secrets) |
| [insecure-test-DO-NOT-USE.yaml](./task-1-hardening/insecure-test-DO-NOT-USE.yaml) | The rejected insecure manifest used to verify Kyverno guardrails |

---

## Task 2: Secure CI/CD Pipeline and Supply Chain

Rebuilt the delivery path so security is enforced by the pipeline, not by good intentions.

**What was done:**
- GitHub Actions pipeline: build → scan → sign → deploy ([`.github/workflows/ci-cd.yml`](./.github/workflows/ci-cd.yml))
- **Hard-blocking gates:** Gitleaks (secrets scan), Semgrep SAST (ERROR severity), Trivy (CRITICAL/HIGH CVEs)
- **Cosign keyless signing** (OIDC) + SLSA provenance attestation pushed to GHCR
- **ArgoCD GitOps** with `selfHeal: true` for drift detection and auto-remediation
- Deferred/unfixable CVEs explicitly tracked with justification and 30-day expiry

### Evidence Links

| Artifact | Description |
| :--- | :--- |
| [README.md](./task-2-cicd/README.md) | Pipeline architecture, fail policies, design decisions |
| [EVIDENCE.md](./task-2-cicd/EVIDENCE.md) | Pipeline run logs, Cosign verify output, ArgoCD drift detection proof |
| [Architecture Diagram](./task-2-cicd/task2-architecture-diagram.png) | CI/CD pipeline and supply chain flow |
| [TRIVY-FINDINGS.md](./task-2-cicd/TRIVY-FINDINGS.md) | Documented CVE triage with fix status, justification, expiry |
| [GITLEAKS-FINDINGS.md](./task-2-cicd/GITLEAKS-FINDINGS.md) | Secrets scan results and `.gitleaksignore` rationale |
| [DEFERRED-FINDINGS.md](./task-2-cicd/DEFERRED-FINDINGS.md) | Semgrep findings intentionally deferred to Task 4 pentest |
| [argocd-app.yaml](./task-2-cicd/argocd-app.yaml) | ArgoCD Application manifest |
| [ci-cd.yml](./.github/workflows/ci-cd.yml) | Full GitHub Actions pipeline definition |

---

## Task 3: Service Mesh and Zero-Trust (Istio)

Built a full service mesh and enforced identity-based zero-trust communication between services.

**What was done:**
- Istio installed with CNI plugin to stay compatible with Task 1's `restricted` Pod Security Standards
- **mTLS STRICT** (`PeerAuthentication`) with plaintext request refused, verified with `istioctl authn tls-check`
- **Default-deny `AuthorizationPolicy`** + explicit allow keyed on SPIFFE workload identity (not IP): unauthorized pod blocked (403), authorized `reporting` service allowed
- Certificate issuance/rotation explained: 24h TTL, 12h SDS rotation trigger, self-signed cluster root CA
- **Kubernetes `NetworkPolicy`** layered underneath for defence in depth with an explanation of what each layer catches that the other does not
- **Bonus:** Istio Ingress Gateway with TLS termination, canary release via `VirtualService` + `DestinationRule`, PCI CDE scope mapping

### Evidence Links

| Artifact | Description |
| :--- | :--- |
| [README.md](./task-3-mesh/README.md) | Mesh architecture, mTLS rationale, cert rotation, NetworkPolicy vs AuthorizationPolicy comparison |
| [EVIDENCE.md](./task-3-mesh/EVIDENCE.md) | `istioctl authn tls-check` output, 403 block proof, cert inspection, ArgoCD drift detection |
| [Architecture Diagram](./task-3-mesh/task3-architecture-diagram.png) | Zero-trust mesh topology |
| [peer-authentication.yaml](./task-3-mesh/peer-authentication.yaml) | mTLS STRICT PeerAuthentication |
| [auth-deny-all.yaml](./task-3-mesh/auth-deny-all.yaml) | Default-deny AuthorizationPolicy |
| [auth-allow-reporting.yaml](./task-3-mesh/auth-allow-reporting.yaml) | Explicit allow for `reporting` service by SPIFFE identity |
| [net-deny-all.yaml](./task-3-mesh/net-deny-all.yaml) | Kubernetes NetworkPolicy default-deny |
| [gateway.yaml](./task-3-mesh/gateway.yaml) | Istio Ingress Gateway with TLS |
| [argocd-app-mesh.yaml](./task-3-mesh/argocd-app-mesh.yaml) | Dedicated ArgoCD Application for mesh policies |

---

## Task 4: Reconnaissance and Penetration Testing

Switched sides: mapped the attack surface of `dodopayments.tech` as an outside attacker (passive only), then performed an authorized penetration test against the local `ledger-api` container.

### Part A: Passive Reconnaissance (dodopayments.tech)

**What was done:**
- Subdomain enumeration using `crt.sh` CT logs, `subfinder`, `amass (passive)`, `assetfinder` resulting in **110 subdomains discovered**
- Live host fingerprinting with `httpx` identifying **56 live endpoints**
- Technology stack fingerprinting with `whatweb`
- TLS/SSL posture reviewed with `testssl.sh`: overall grade **B**, TLS 1.0/1.1 flagged, SWEET32/BEAST identified
- Passive-only constraint strictly observed with no active scanners or exploits against any `dodopayments.tech` host

### Part B: Penetration Test (Local ledger-api Container)

**What was done:**
- **4 findings** across OWASP Top 10 categories: SSRF, Reversible Tokenization, Missing Authentication, Insecure Deserialization (non-exploitable)
- All findings include: CVSS v3.1 vector + score, affected endpoint, PoC request/response, impact, remediation
- **Bonus: Attack chain** — SSRF + Missing Auth chained into a cardholder PAN exfiltration path
- **Bonus: Retest section** — Finding 2 (tokenization) fixed and verified closed (brute-force returns `None` after patch)
- **Bonus: Defensive mapping** — each finding mapped back to Task 1 to 3 controls that would (or would not) have stopped it

### Evidence Links

| Artifact | Description |
| :--- | :--- |
| [README.md](./task-4-recon-pentest/README.md) | Methodology summary and deliverable index |
| [PENTEST_REPORT.md](./task-4-recon-pentest/PENTEST_REPORT.md) | Full penetration test report: executive summary, findings, attack chain, defensive mapping, retest |
| [ATTACK_SURFACE_REPORT.md](./task-4-recon-pentest/recon/ATTACK_SURFACE_REPORT.md) | Full recon report: 110 subdomain inventory, risk segmentation, TLS posture |
| [EVIDENCE.md](./task-4-recon-pentest/recon/EVIDENCE.md) | Raw command outputs, `dig` results, HTTP request/response logs, brute-force output, remediation diff |
| [recon/](./task-4-recon-pentest/recon/) | Raw tool output files (`subfinder.txt`, `amass.txt`, `assetfinder.txt`, `crtsh.txt`, `httpx_results.txt`, `whatweb_results.txt`, `testssl_*.txt`, `merged_subdomains.txt`) |
| [vulnerable-app/](./task-4-recon-pentest/vulnerable-app/) | The local Flask target used for authorized active testing |

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── ci-cd.yml               # GitHub Actions pipeline (Task 2)
├── task-1-hardening/               # Workload hardening manifests + evidence
├── task-2-cicd/                    # CI/CD pipeline configs + evidence
├── task-3-mesh/                    # Istio mesh + NetworkPolicy manifests + evidence
├── task-4-recon-pentest/           # Recon data, pentest report, vulnerable app
├── .gitleaksignore                 # Gitleaks suppression rules
└── .trivyignore                    # Trivy CVE suppression with justifications
```

---

*All testing was performed locally using free tooling. Kind cluster, GitHub Actions free runners, GHCR. No cloud account required.*
