# Dodo Payments: DevSecOps Assessment Submission

**Candidate:** Ramesh Kanna G
**Role:** Security & DevOps Engineer

---

## Tasks

| Task | Folder | Key Links |
| :--- | :--- | :--- |
| Task 1: Workload Hardening | [`task-1-hardening/`](./task-1-hardening/) | [README](./task-1-hardening/README.md) · [Evidence](./task-1-hardening/EVIDENCE.md) · [Manifests](./task-1-hardening/deploy/) |
| Task 2: Secure CI/CD | [`task-2-cicd/`](./task-2-cicd/) | [README](./task-2-cicd/README.md) · [Evidence](./task-2-cicd/EVIDENCE.md) · [Pipeline](./.github/workflows/ci-cd.yml) |
| Task 3: Service Mesh | [`task-3-mesh/`](./task-3-mesh/) | [README](./task-3-mesh/README.md) · [Evidence](./task-3-mesh/EVIDENCE.md) |
| Task 4: Recon & Pentest | [`task-4-recon-pentest/`](./task-4-recon-pentest/) | [README](./task-4-recon-pentest/README.md) · [Pentest Report](./task-4-recon-pentest/PENTEST_REPORT.md) · [Attack Surface Report](./task-4-recon-pentest/recon/ATTACK_SURFACE_REPORT.md) |

---

## Task 1: Workload Hardening

Non-root containers, read-only filesystem, all capabilities dropped, Sealed Secrets (plaintext keys removed from git), Kyverno policies blocking root and `:latest` images, dedicated least-privilege ServiceAccount.

**Bonus:** Persona RBAC (developer/operator/admin), Pod Security Standards `restricted`, Kyverno rejection proof.

| Artifact | |
| :--- | :--- |
| [README.md](./task-1-hardening/README.md) | Approach and design decisions |
| [EVIDENCE.md](./task-1-hardening/EVIDENCE.md) | kubectl logs, Kyverno rejection events, Sealed Secrets proof |
| [Architecture Diagram](./task-1-hardening/task1-architecture-diagram.png) | Deployment topology |
| [deploy/](./task-1-hardening/deploy/) | All Kubernetes manifests |
| [insecure-test-DO-NOT-USE.yaml](./task-1-hardening/insecure-test-DO-NOT-USE.yaml) | Insecure manifest used to verify Kyverno blocks |

---

## Task 2: Secure CI/CD Pipeline and Supply Chain

GitHub Actions pipeline (build, scan, sign, deploy), Gitleaks + Semgrep + Trivy hard-blocking gates, Cosign keyless signing with SLSA provenance, ArgoCD GitOps with drift detection.

**Bonus:** Full CVE triage with justifications and 30-day expiry in `.trivyignore`.

| Artifact | |
| :--- | :--- |
| [README.md](./task-2-cicd/README.md) | Pipeline architecture and fail policies |
| [EVIDENCE.md](./task-2-cicd/EVIDENCE.md) | Pipeline logs, Cosign verify, ArgoCD drift proof |
| [Architecture Diagram](./task-2-cicd/task2-architecture-diagram.png) | CI/CD supply chain flow |
| [TRIVY-FINDINGS.md](./task-2-cicd/TRIVY-FINDINGS.md) | CVE triage and fix status |
| [GITLEAKS-FINDINGS.md](./task-2-cicd/GITLEAKS-FINDINGS.md) | Secrets scan results and rationale |
| [DEFERRED-FINDINGS.md](./task-2-cicd/DEFERRED-FINDINGS.md) | Semgrep findings deferred to Task 4 |
| [ci-cd.yml](./.github/workflows/ci-cd.yml) | Full GitHub Actions pipeline |
| [argocd-app.yaml](./task-2-cicd/argocd-app.yaml) | ArgoCD Application manifest |

---

## Task 3: Service Mesh and Zero Trust

Istio with CNI (compatible with restricted PSS), mTLS STRICT across the namespace, default-deny AuthorizationPolicy with explicit allow by SPIFFE identity, Kubernetes NetworkPolicy layered underneath for defence in depth.

**Bonus:** Ingress Gateway with TLS, canary release (90/10 VirtualService), PCI DSS CDE scope mapping.

| Artifact | |
| :--- | :--- |
| [README.md](./task-3-mesh/README.md) | Mesh design, cert rotation, NetworkPolicy vs AuthorizationPolicy |
| [EVIDENCE.md](./task-3-mesh/EVIDENCE.md) | 403 block proof, cert inspection, ArgoCD drift detection |
| [Architecture Diagram](./task-3-mesh/task3-architecture-diagram.png) | Zero-trust mesh topology |
| [peer-authentication.yaml](./task-3-mesh/peer-authentication.yaml) | mTLS STRICT policy |
| [auth-deny-all.yaml](./task-3-mesh/auth-deny-all.yaml) | Default-deny AuthorizationPolicy |
| [auth-allow-reporting.yaml](./task-3-mesh/auth-allow-reporting.yaml) | Explicit allow by SPIFFE identity |
| [net-deny-all.yaml](./task-3-mesh/net-deny-all.yaml) | L3/L4 default-deny NetworkPolicy |
| [gateway.yaml](./task-3-mesh/gateway.yaml) | Istio Ingress Gateway with TLS |
| [argocd-app-mesh.yaml](./task-3-mesh/argocd-app-mesh.yaml) | ArgoCD Application for mesh policies |

---

## Task 4: Reconnaissance and Penetration Testing

**Part A:** Passive OSINT of `dodopayments.tech`: 110 subdomains discovered, 56 live endpoints, TLS posture grade B (TLS 1.0/1.1 flagged, SWEET32/BEAST identified). No active attacks performed.

**Part B:** Authorized pentest of local `ledger-api` container: 4 findings (SSRF, Reversible Tokenization, Missing Auth, Insecure Deserialization). Full CVSS v3.1 vectors, PoC, attack chain, defensive mapping, and retest included.

| Artifact | |
| :--- | :--- |
| [README.md](./task-4-recon-pentest/README.md) | Methodology and deliverable index |
| [PENTEST_REPORT.md](./task-4-recon-pentest/PENTEST_REPORT.md) | Full pentest report |
| [ATTACK_SURFACE_REPORT.md](./task-4-recon-pentest/recon/ATTACK_SURFACE_REPORT.md) | Full recon report |
| [EVIDENCE.md](./task-4-recon-pentest/recon/EVIDENCE.md) | Raw command outputs and logs |
| [recon/](./task-4-recon-pentest/recon/) | Raw tool output files |
| [vulnerable-app/](./task-4-recon-pentest/vulnerable-app/) | Local Flask target used for testing |

---

## Tools and Versions

| Tool | Version |
| :--- | :--- |
| minikube | v1.38.1 |
| Docker | 29.6.1 |
| kubectl | v1.36.2 |
| Helm | v3.21.2 |
| Istio / istioctl | 1.30.2 |
| Kyverno | v1.18.1 (chart 3.8.1) |
| ArgoCD | stable manifest |
| Sealed Secrets | latest controller manifest |
| Trivy | 0.71.2 |
| Gitleaks | 8.30.1 |
| Semgrep | 1.168.0 |
| Cosign | v3.1.1 |
| Subfinder | v2.14.0 |
| httpx | v1.9.0 |
| Amass | v3.19.2 |
| Assetfinder | v0.1.1 |
| testssl.sh | v3.3dev |
| WhatWeb | 0.5.5 |
