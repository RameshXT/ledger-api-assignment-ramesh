# Deferred Security Findings (Intentional Vulnerabilities)

During our CI/CD security gate implementation, Semgrep identified 4 real, high-severity security findings in the `task-1-hardening/app` codebase. Rather than fixing them immediately, we have made a conscious engineering decision to leave them in place and suppress the pipeline failures using inline `nosemgrep` comments.

---

## 1. Documented Findings

| File | Line | Rule/Vulnerability ID | Description | Severity |
| :--- | :--- | :--- | :--- | :--- |
| `app/app.py` | 39 | Unsafe YAML Deserialization | Insecure `yaml.load()` usage without a SafeLoader, leading to potential Remote Code Execution (RCE). | ERROR |
| `app/app.py` | 46 | Server-Side Request Forgery (SSRF) | `/fetch` endpoint accepts user-supplied URLs and queries them via `requests.get()` without validation. | ERROR |
| `app/app.py` | 46 | Unvalidated User Input | Duplicate rule hit flagging unvalidated user input directly passed to a request library. | ERROR |
| `app/Dockerfile` | 1 | Missing USER Instruction | Dockerfile runs as root user by default instead of defining a non-root `USER` instruction. | ERROR |

---

## 2. Rationale for Deferral

These are **real, confirmed vulnerabilities**, not false positives. We have deliberately left them unfixed for the following reasons:
* **Pentesting Target**: These issues are intentionally reserved as targets for **Task 4: Reconnaissance & Penetration Testing**. 
* **OWASP Top 10 Coverage**: Leaving these specific flaws active ensures we have realistic, exploitable security holes (RCE, SSRF, Root execution) to identify, analyze, and document in our final pentest report.
* **Conscious Decision**: This is a strategic educational/testing choice, not an oversight. Once Task 4 is complete, these issues will be resolved in a subsequent hardening phase.

---

## 3. Suppression Method

To prevent blocking our CI/CD pipeline while keeping the security gate active for new code, we applied inline `# nosemgrep` comments to the specific affected lines in `app.py` and the `Dockerfile`.
