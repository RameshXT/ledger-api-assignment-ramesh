# Task 1 — Deploy & Harden the Workload — Complete Checklist

Source: Official assignment PDF, Task 1 section. This is the full scope — required items 
AND bonus items. Nothing here is optional to skip without a documented reason in the README.

Target repo to deploy: https://github.com/bhabani-dodo/ledger-api-assignment

## REQUIRED ITEMS

### 1. Deployment basics
- [ ] Deploy `ledger-api` from the given repo
- [ ] Deploy at least ONE neighbour service (a second workload, for testing isolation/RBAC later)
- [ ] Both services must use: Deployments, Services, ConfigMaps, Ingress
  - Deployment = how the app runs (replicas, image, etc.)
  - Service = internal networking so pods can be reached
  - ConfigMap = non-secret configuration values externalized from code
  - Ingress = external access point (URL routing into the cluster)

### 2. Lock down securityContext (on every container)
- [ ] Run as non-root (`runAsNonRoot: true`, set a `runAsUser`)
- [ ] Read-only root filesystem (`readOnlyRootFilesystem: true`)
- [ ] Drop ALL Linux capabilities (`capabilities: drop: ["ALL"]`)
- [ ] Seccomp profile set to `RuntimeDefault`

### 3. Resource management & health (on EVERY container — not just ledger-api)
- [ ] Resource requests set (CPU + memory)
- [ ] Resource limits set (CPU + memory)
- [ ] Liveness probe configured
- [ ] Readiness probe configured

### 4. Identity & permissions
- [ ] Create a dedicated, least-privilege ServiceAccount for ledger-api (do NOT use the default ServiceAccount)
- [ ] Write RBAC (Role + RoleBinding) scoped to exactly what ledger-api needs — nothing broader

### 5. Secrets management
- [ ] Move all secrets out of git / plaintext
- [ ] Use ONE of: Sealed Secrets, SOPS+age, or External Secrets Operator (Sealed Secrets is already installed in the cluster — this is the path already set up)
- [ ] Confirm: no plaintext secret/key exists anywhere in the repo (double-check git history too, not just current files)

### 6. Admission control guardrails (Kyverno — already installed in cluster)
- [ ] Write policy: reject any container running as root
- [ ] Write policy: reject any image using the `:latest` tag
- [ ] Write policy: reject any unsigned image (Note: the verifyImages Kyverno policy for unsigned-image rejection is intentionally deferred to Task 2, since image signing (Cosign) is implemented there and the policy needs the signing setup to exist first, as referenced in the TODO comment in [kyverno-policies.yaml](file:///Ubuntu-24.04/home/rameshxt/dodo-payments/ledger-project/task-1-hardening/deploy/kyverno-policies.yaml#L58))
- [ ] Apply these policies to the cluster and confirm they're active

## BONUS ITEMS (explicitly listed in assignment — attempt what time allows, document what's skipped and why)

### Bonus 1 — Persona-based RBAC
- [ ] Create THREE separate RBAC roles, each least-privilege, for:
  - [ ] Developer persona
  - [ ] Operator persona
  - [ ] Admin persona
- Each role should only allow the actions that persona realistically needs (e.g. developer might get read/deploy access, operator might get scaling/restart access, admin gets broader cluster management)

### Bonus 2 — Pod Security Standards
- [ ] Enforce Pod Security Standards at the "restricted" level on the namespace
- (This is a built-in Kubernetes label-based enforcement, separate from and in addition to Kyverno — namespace label like `pod-security.kubernetes.io/enforce: restricted`)

### Bonus 3 — Prove the guardrail works
- [ ] Take the ORIGINAL insecure deployment manifest (from the unmodified repo)
- [ ] Attempt to apply it to the cluster AFTER Kyverno policies are active
- [ ] Capture screenshot/terminal output showing Kubernetes/Kyverno REJECTS it
- This is explicit proof-of-control evidence for the write-up

## EVIDENCE / DOCUMENTATION REQUIREMENTS (apply across all of Task 1)
- [ ] README.md inside `task-1-hardening/` explaining approach and design decisions for every item above
- [ ] Architecture diagram (draw.io or Excalidraw) showing ledger-api + neighbour service + how Ingress/Services connect them
- [ ] Screenshots or terminal recordings proving:
  - [ ] Pods running successfully (after hardening)
  - [ ] securityContext settings applied (e.g. `kubectl get pod <name> -o yaml` showing the security fields)
  - [ ] Resource limits/probes active
  - [ ] ServiceAccount + RBAC applied and scoped correctly
  - [ ] Secrets are NOT plaintext (show Sealed Secret vs. what it decrypts to, without exposing the real secret value)
  - [ ] Kyverno policies active and enforcing (ties into Bonus 3 above)

## GENERAL ASSIGNMENT-WIDE RULES THAT APPLY TO TASK 1
- [ ] Everything must run free/local — no cloud account required (Minikube satisfies this)
- [ ] Public GitHub repository, one folder per task — this task's folder is `task-1-hardening/`
- [ ] Prioritize quality over completeness if time runs short — document explicitly what was skipped and what you'd do with more time, rather than leaving it unexplained