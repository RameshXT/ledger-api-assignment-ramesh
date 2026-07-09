# Trivy Vulnerability Scan Findings & Analysis

During our supply chain security hardening, Trivy's image-scan gate flagged multiple HIGH/CRITICAL CVEs in our base container image (built on Debian 13.5). This document details these findings, explains our mitigation strategy, and states our security policy decisions.

---

## 1. Patched Vulnerabilities (App-Level & Bundled Tools)

Through targeted upgrades, we successfully resolved all application-level and Python environment vulnerabilities:
* **Python Dependencies**: Upgraded `requests` from `2.20.0` to `2.32.3`. This pulled in a modern `urllib3` version, successfully patching 5 high-severity `urllib3` CVEs.
* **Bundled Build Tools**: Added a step in our Dockerfile to upgrade `pip`, `setuptools`, and `wheel` before installing requirements. This patched the vulnerabilities originating from the base image's pre-installed Python packaging tools.

---

## 2. Unfixed OS-Level Vulnerabilities (Debian Base Image)

Trivy flagged 18 HIGH/CRITICAL CVEs originating from core packages in the `python:3.11-slim` base image (Debian 13.5) that have **blank "Fixed Version" fields** upstream:

| Package | CVE ID | Severity | Status | Reason / Justification |
| :--- | :--- | :--- | :--- | :--- |
| `bsdutils` | CVE-2026-53615 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `gzip` | CVE-2026-41992 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `libacl1` | CVE-2026-54369 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `libblkid1` | CVE-2025-69720 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `liblastlog2-2` | CVE-2025-69720 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `libmount1` | CVE-2025-69720 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `libncursesw6` | CVE-2026-8376 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `libsmartcols1` | CVE-2025-69720 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `libtinfo6` | CVE-2026-8376 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `libuuid1` | CVE-2025-69720 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `login` | CVE-2025-69720 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `mount` | CVE-2025-69720 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `ncurses-base` | CVE-2026-8376 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `ncurses-bin` | CVE-2026-8376 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `perl-base` | CVE-2026-42496 | HIGH | fix_deferred | Patch deferred by Debian security team. |
| `perl-base` | CVE-2026-8376 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `perl-base` | CVE-2026-42497 | HIGH | fix_deferred | Patch deferred by Debian security team. |
| `perl-base` | CVE-2026-48962 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `perl-base` | CVE-2026-9538 | HIGH | affected | No upstream patch available from Debian security team yet. |
| `util-linux` | CVE-2025-69720 | HIGH | affected | No upstream patch available from Debian security team yet. |

### Understanding "fix_deferred" Status
The vulnerabilities in `perl-base` are flagged as **`fix_deferred`** by the Debian security tracker. This means the security team has officially acknowledged the CVEs but has chosen to defer patching them to a later date. This is common when a fix is complex, risks introducing regressions in stable core libraries, or has low real-world exploitability in standard server environments.

---

## 3. Policy Decision: .trivyignore with Review Gates

Since these vulnerabilities cannot be patched by application-level code, leaving `ignore-unfixed: false` in place would block our CI/CD pipeline indefinitely on issues we cannot control.

We have selected **Option (a)**: We will create a `.trivyignore` file at the repository root to temporarily bypass these specific, unpatchable OS-level CVEs. To prevent this from becoming a permanent security blindspot, the bypass is governed by the following rules:
1. **Explicit Justification**: Each ignored CVE must be listed with a clear explanation that no upstream fix exists.
2. **Review/Expiry Dates**: Every entry will include a comment specifying an expiry date (e.g., 30 days from now).
3. **Pipeline Enforcement**: Trivy will continue to block any *new* packages or dependencies that introduce patchable HIGH/CRITICAL vulnerabilities.
