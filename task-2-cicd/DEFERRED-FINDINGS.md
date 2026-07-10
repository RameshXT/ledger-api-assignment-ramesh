# Resolved Security Findings (Vulnerabilities Moved)

Previously, Semgrep identified 4 real, high-severity security findings in the active codebase. To preserve these vulnerabilities for Task 4's penetration testing while keeping the primary workload hardened, we have separated the codebases:

1. **Hardened App (`task-1-hardening/app/`)**: Fully resolved. All vulnerabilities have been patched (RCE fixed via `yaml.safe_load`, SSRF fixed via URL validation, and non-root USER configured in the Dockerfile). All `# nosemgrep` comments have been removed.
2. **Pentest Target (`task-4-recon-pentest/vulnerable-app/`)**: The original vulnerable files are maintained here as the dedicated pentesting targets with the RCE, SSRF, and root-container vulnerabilities intact.

---

## 1. Documented Findings (and their current locations)

| Vulnerability ID / Description | Original File Location (Hardened) | Status | Pentest Target Location |
| :--- | :--- | :--- | :--- |
| Unsafe YAML Deserialization (`yaml.load()`) | `task-1-hardening/app/app.py` | **Fixed** (`safe_load`) | `task-4-recon-pentest/vulnerable-app/app.py` |
| Server-Side Request Forgery (`requests.get()`) | `task-1-hardening/app/app.py` | **Fixed** (URL Allowlist) | `task-4-recon-pentest/vulnerable-app/app.py` |
| Missing USER Instruction (Runs as root) | `task-1-hardening/app/Dockerfile` | **Fixed** (USER 10001:10001) | `task-4-recon-pentest/vulnerable-app/Dockerfile` |

---

## 2. Rationale for Separation

Rather than keeping the active application vulnerable, we separated the vulnerable codebase into `task-4-recon-pentest/vulnerable-app/` to ensure:
* **Production-grade task-1-hardening/app**: The primary app is fully secure and production-ready.
* **Intact Pentest Target**: The penetration testing targets for **Task 4: Reconnaissance & Penetration Testing** remain fully functional and exploitable in their dedicated folder.
