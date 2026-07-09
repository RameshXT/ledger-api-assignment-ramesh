# Gitleaks Secrets Scanning Investigation

While testing our new Gitleaks secrets-scanning gate, the GitHub Actions run passed with no leaks detected, but a full local scan found multiple findings. Here is the breakdown of why this happened, what was found, and our policy decision.

---

## 1. What was found

The GitHub Actions runner uses the default behavior of the Gitleaks action, which scans only the single most recent commit in the push event (using `--log-opts=-1`). This allows developers to commit new code without being blocked by historical history, but it missed older findings.

To check our full repository history, we ran a manual local scan with the `--log-opts="--all"` flag, which scanned all 10 commits and flagged 5 findings.

---

## 2. Analysis of the 5 Findings

Of the 5 findings flagged by the historical scan:
* **1 REAL Finding**: A plaintext Stripe API key (`sk_live_...`) committed in `task-1-hardening/deploy/deployment.yaml` in our first commit (`f6b6128`). This was the original, insecure baseline we inherited, which we already identified and replaced with Sealed Secrets in Task 1.
* **4 FALSE POSITIVES**: Encrypted SealedSecret ciphertexts located in `task-1-hardening/deploy/secrets.yaml` and documented in `task-1-hardening/EVIDENCE.md`. These were flagged by the `generic-api-key` rule because high-entropy ciphertext mimics the random distribution of real secrets, but they do not contain any plaintext credentials.

---

## 3. Policy Decision

To keep the development feedback loop fast and prevent blocking current work due to historical baseline commits (which have already been mitigated or documented), we will:
1. **Maintain single-commit scans in CI**: The Gitleaks gate in the CI/CD pipeline will continue to scan only incoming changes (`--log-opts=-1`) on push.
2. **Execute historical audits separately**: Full-history scans will be run manually or as a scheduled periodic audit rather than hard-blocking daily pipeline runs.

---

## 4. Evidence

### Local Scan Output (Full History)
```text
Finding:     value: "sk_live_9f3a2b7c1e4d8REDACTED"
Secret:      sk_live_9f3a2b7c1e4d8REDACTED
RuleID:      stripe-access-token
Entropy:     4.582119
File:        task-1-hardening/deploy/deployment.yaml
Line:        24
Commit:      f6b612808584ee9b9b4570f0b68a673c933c7c55
Author:      Ramesh XT
Email:       rameshkanna841@gmail.com
Date:        2026-07-09T07:11:59Z
Fingerprint: f6b612808584ee9b9b4570f0b68a673c933c7c55:task-1-hardening/deploy/deployment.yaml:stripe-access-token:24
Link:        https://github.com/RameshXT/ledger-api-assignment-ramesh/blob/f6b612808584ee9b9b4570f0b68a673c933c7c55/task-1-hardening/deploy/deployment.yaml#L24

Finding:     DB_PASSWORD: AgCZ+aSk/cwbzh728XzX8LHTB2f4hLSOF8yqj9ug9QPtAi5L94yNH1LNqiY2HsNkF44mo6wHP9vPm9gA9wsa3oGEtdR5wvrizrtJ...
Secret:      AgCZ+aSk/cwbzh728XzX8LHTB2f4hLSOF8yqj9ug9QPtAi5L94yNH1LNqiY2HsNkF44mo6wHP9vPm9gA9wsa3oGEtdR5wvrizrtJ...
RuleID:      generic-api-key
Entropy:     5.953914
File:        task-1-hardening/deploy/secrets.yaml
Line:        10
Commit:      3befb713c47d3dc7aa7727689ada7844da2b6a01
Author:      Ramesh XT
Email:       rameshkanna841@gmail.com
Date:        2026-07-09T10:24:50Z
Fingerprint: 3befb713c47d3dc7aa7727689ada7844da2b6a01:task-1-hardening/deploy/secrets.yaml:generic-api-key:10
Link:        https://github.com/RameshXT/ledger-api-assignment-ramesh/blob/3befb713c47d3dc7aa7727689ada7844da2b6a01/task-1-hardening/deploy/secrets.yaml#L10

Finding:     STRIPE_API_KEY: AgChyA0oGZwwlnAF7dcd5w4HemzO4DT8KwZ7GTJ/dYDIrSvNjupWzr+si3VLm4uxzxRsUibfxCQMZfc6I/LzUf56sLelqM/GLIR4...
Secret:      AgChyA0oGZwwlnAF7dcd5w4HemzO4DT8KwZ7GTJ/dYDIrSvNjupWzr+si3VLm4uxzxRsUibfxCQMZfc6I/LzUf56sLelqM/GLIR4...
RuleID:      generic-api-key
Entropy:     5.947387
File:        task-1-hardening/deploy/secrets.yaml
Line:        11
Commit:      3befb713c47d3dc7aa7727689ada7844da2b6a01
Author:      Ramesh XT
Email:       rameshkanna841@gmail.com
Date:        2026-07-09T10:24:50Z
Fingerprint: 3befb713c47d3dc7aa7727689ada7844da2b6a01:task-1-hardening/deploy/secrets.yaml:generic-api-key:11
Link:        https://github.com/RameshXT/ledger-api-assignment-ramesh/blob/3befb713c47d3dc7aa7727689ada7844da2b6a01/task-1-hardening/deploy/secrets.yaml#L11

Finding:     DB_PASSWORD: AgCZ+aSk/cwbzh728XzX8LHTB2f4hLSOF8yqj9ug9QPtAi5L94yNH1LNqiY2HsNkF44mo6wHP9vPm9gA9wsa3oGEtdR5wvrizrtJ...
Secret:      AgCZ+aSk/cwbzh728XzX8LHTB2f4hLSOF8yqj9ug9QPtAi5L94yNH1LNqiY2HsNkF44mo6wHP9vPm9gA9wsa3oGEtdR5wvrizrtJ...
RuleID:      generic-api-key
Entropy:     5.953914
File:        task-1-hardening/EVIDENCE.md
Line:        278
Commit:      907441f8f5f5eee2bd4774b98899f24769444203
Author:      Ramesh XT
Email:       rameshkanna841@gmail.com
Date:        2026-07-09T10:25:13Z
Fingerprint: 907441f8f5f5eee2bd4774b98899f24769444203:task-1-hardening/EVIDENCE.md:generic-api-key:278
Link:        https://github.com/RameshXT/ledger-api-assignment-ramesh/blob/907441f8f5f5eee2bd4774b98899f24769444203/task-1-hardening/EVIDENCE.md?plain=1#L278

Finding:     STRIPE_API_KEY: AgChyA0oGZwwlnAF7dcd5w4HemzO4DT8KwZ7GTJ/dYDIrSvNjupWzr+si3VLm4uxzxRsUibfxCQMZfc6I/LzUf56sLelqM/GLIR4...
Secret:      AgChyA0oGZwwlnAF7dcd5w4HemzO4DT8KwZ7GTJ/dYDIrSvNjupWzr+si3VLm4uxzxRsUibfxCQMZfc6I/LzUf56sLelqM/GLIR4...
RuleID:      generic-api-key
Entropy:     5.947387
File:        task-1-hardening/EVIDENCE.md
Line:        279
Commit:      907441f8f5f5eee2bd4774b98899f24769444203
Author:      Ramesh XT
Email:       rameshkanna841@gmail.com
Date:        2026-07-09T10:25:13Z
Fingerprint: 907441f8f5f5eee2bd4774b98899f24769444203:task-1-hardening/EVIDENCE.md:generic-api-key:279
Link:        https://github.com/RameshXT/ledger-api-assignment-ramesh/blob/907441f8f5f5eee2bd4774b98899f24769444203/task-1-hardening/EVIDENCE.md?plain=1#L279

11:40AM INF 10 commits scanned.
11:40AM INF scanned ~46953 bytes (46.95 KB) in 198ms
11:40AM WRN leaks found: 5
```

### GitHub Actions Log Excerpt (Single Commit Scan)
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
