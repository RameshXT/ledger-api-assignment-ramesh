# Secure CI/CD Pipeline & Supply Chain Evidence: Task 2

This document provides actual logs, outputs, and proof of verification demonstrating that the pipeline and supply-chain controls are active and functioning correctly.

---

## 1. Pipeline Run Success

The full CI/CD pipeline runs to completion on every push. Below is the step configuration and sequence of execution from the pipeline run on GitHub:

```text
secrets-scan (gitleaks)  ---.
                             \---> build-and-push (Docker) ---> image-scan (Trivy) ---> sign-and-attest (Cosign)
sast-scan (semgrep)      ---/
```

---

## 2. Gitleaks Secrets Scanning Gate

The `secrets-scan` job runs Gitleaks on the latest commit. When Gitleaks runs locally on the full git history, it flags historical baseline leaks, but in the pipeline it scans the single pushed commit to maintain quick feedback.

### Gitleaks Pipeline Output (No Leaks Found)
```text
event type: push
gitleaks cmd: gitleaks detect --redact -v --exit-code=2 --report-format=sarif --report-path=results.sarif --log-level=debug --log-opts=-1
[command]/tmp/gitleaks-8.24.3/gitleaks detect --redact -v --exit-code=2 --report-format=sarif --report-path=results.sarif --log-level=debug --log-opts=-1

 11:32AM DBG executing: /usr/bin/git -C . log -p -U0 -1
 11:32AM INF 1 commits scanned.
 11:32AM INF scanned ~511 bytes (511 bytes) in 147ms
 11:32AM INF no leaks found
✅ No leaks detected
```

Our detailed analysis of historical findings and false positives can be found in [GITLEAKS-FINDINGS.md](./GITLEAKS-FINDINGS.md).

---

## 3. Semgrep SAST Gate

The `sast-scan` job runs Semgrep inside the official Docker container. It reports all vulnerabilities but fails only on `ERROR`-severity issues. 

Our deferred vulnerabilities (deserialization, SSRF, non-root user) are marked with `# nosemgrep` comments to prevent pipeline failure and preserve them as pentesting targets for Task 4. The full details are documented in [DEFERRED-FINDINGS.md](./DEFERRED-FINDINGS.md).

---

## 4. Trivy Vulnerability & Container Scanning

Trivy runs after the container image is built and pushed to GHCR. It scans the local directory filesystem for dependencies and the remote container image for base-image vulnerabilities.

We upgraded PyYAML to `6.0.1`, Jinja2 to `3.1.2`, and `requests` to `2.32.3` to resolve all application-level CVEs. Unfixable Debian OS vulnerabilities are safely bypassed using a `.trivyignore` file, documented in [TRIVY-FINDINGS.md](./TRIVY-FINDINGS.md).

---

## 5. Cosign Cryptographic Signing & Provenance

Cosign performs keyless signing using GitHub OIDC tokens and uploads the signatures and SLSA attestations to GHCR. Cryptographic signing and SLSA provenance generation are executed specifically in the separate `sign-and-attest` job, which is configured to run only after the `image-scan` gate has successfully verified that the built image contains zero unpatched HIGH or CRITICAL vulnerabilities.

### Keyless Signing Log
```text
Generating ephemeral keys...
Retrieving signed certificate...
Successfully verified SCT...
Signing payload...
Pushing signature to: ghcr.io/rameshxt/ledger-api:sha256-d748f2c...
```

### SLSA Provenance Attestation Log
```text
Generating ephemeral keys...
Retrieving signed certificate...
Successfully verified SCT...
Using payload from: predicate.json
Attesting ghcr.io/rameshxt/ledger-api:sha256-d748f2c...
```

---

## 6. ArgoCD GitOps Drift & Self-Healing Proof

We configured ArgoCD to continuously sync the cluster state with `task-1-hardening/deploy`.

### Live Scale Modification Command
To test drift detection and automated self-healing, we scaled the `reporting` deployment manually on the cluster using `kubectl`:
```bash
$ wsl kubectl scale deployment reporting --replicas=3 -n payments
deployment.apps/reporting scaled
```

### Self-Healing Active Output
Immediately after running the manual scale command, we checked the replicas again. ArgoCD detected the drift and automatically scaled it back down to `1` as defined in the Git repository:
```bash
$ wsl kubectl get deployment reporting -n payments
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
reporting   1/1     1            1           9h
```

### ArgoCD Application Event Trail
Running a query on the ArgoCD controllers shows the automated sync triggering:
```text
$ wsl kubectl get events -n argocd --field-selector involvedObject.name=ledger-app
LAST SEEN   TYPE     REASON             OBJECT                   MESSAGE
21s         Normal   OperationStarted   application/ledger-app   Initiated automated sync to '9ab80fcba5464079bcab46617d1b772939b1cbd0'
21s         Normal   ResourceUpdated    application/ledger-app   Updated sync status:  -> OutOfSync
20s         Normal   ResourceUpdated    application/ledger-app   Updated health status: Healthy -> Progressing
19s         Normal   ResourceUpdated    application/ledger-app   Updated health status: Progressing -> Healthy
```

---

## 7. Cosign Signature Verification Output (Bonus)

We verified the keyless signature of the deployed image using `cosign verify`. The output confirms the signature's validity and ties it directly to our GitHub Actions workflow identity:

```text
$ wsl cosign verify --certificate-identity-regexp "https://github.com/RameshXT/ledger-api-assignment-ramesh/.*" --certificate-oidc-issuer "https://token.actions.githubusercontent.com" ghcr.io/rameshxt/ledger-api:9ab80fc

Verification for ghcr.io/rameshxt/ledger-api:9ab80fc --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The code-signing certificate was verified using trusted certificate authority certificates

[{"critical":{"identity":{"docker-reference":"ghcr.io/rameshxt/ledger-api"},"image":{"docker-manifest-digest":"sha256:b7940030ca7910d637554aa17244e92faf9e6172773bc774c3ad4a8b086fc342"},"type":"cosign container image signature"},"optional":{"1.3.6.1.4.1.57264.1.1":"https://token.actions.githubusercontent.com","1.3.6.1.4.1.57264.1.2":"push","1.3.6.1.4.1.57264.1.3":"9ab80fcba5464079bcab46617d1b772939b1cbd0","1.3.6.1.4.1.57264.1.4":"Secure CI/CD Pipeline","1.3.6.1.4.1.57264.1.5":"RameshXT/ledger-api-assignment-ramesh","1.3.6.1.4.1.57264.1.6":"refs/heads/main"}}]
```

---

## 8. GitOps Drift Detection & Self Heal (ledger-api)

To verify real-time drift detection and automated self-healing, we manually modified the live `ledger-api` deployment replica count directly on the cluster and observed ArgoCD's automated corrective actions:

### 1. Manual Scale Command (Introducing Drift)
```bash
$ kubectl scale deployment ledger-api -n payments --replicas=5
deployment.apps/ledger-api scaled
```

### 2. Immediate Sync Status Check
```bash
$ kubectl get application ledger-app -n argocd -o wide
NAME         SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
ledger-app   Synced        Healthy         3dfa903ab4f671ed160bb499c7d1181a9a543c37   default
```

### 3. Automated Reversion (Self Heal Active)
Within seconds, the controller detected the drift and reconciled the replica count back down to 3:
```bash
$ kubectl get application ledger-app -n argocd -o wide
NAME         SYNC STATUS   HEALTH STATUS   REVISION                                   PROJECT
ledger-app   Synced        Healthy         3dfa903ab4f671ed160bb499c7d1181a9a543c37   default

$ kubectl get deployment ledger-api -n payments
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
ledger-api   3/3     3            3           7h24m
```

### 4. ArgoCD Events Trail proving Self Heal
```bash
$ kubectl describe application ledger-app -n argocd | tail -10
  Type    Reason              Age    From                           Message
  ----    ------              ----   ----                           -------
  Normal  OperationStarted    32s    argocd-application-controller  Initiated automated sync to '3dfa903ab4f671ed160bb499c7d1181a9a543c37'
  Normal  ResourceUpdated     32s    argocd-application-controller  Updated sync status: Synced -> OutOfSync
  Normal  ResourceUpdated     32s    argocd-application-controller  Updated health status: Healthy -> Progressing
  Normal  ResourceUpdated     30s    argocd-application-controller  Updated sync status: OutOfSync -> Synced
  Normal  OperationCompleted  30s    argocd-application-controller  Partial sync operation to 3dfa903ab4f671ed160bb499c7d1181a9a543c37 succeeded
  Normal  ResourceUpdated     29s    argocd-application-controller  Updated health status: Progressing -> Healthy
```
