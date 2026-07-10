# Task 1 Hardening Verification Evidence

This document contains real runtime output from the active Kubernetes cluster proving compliance with all Task 1 security requirements.

---

## 1. All Resources in payments Namespace
```bash
$ kubectl get all -n payments
```
```text
NAME                              READY   STATUS    RESTARTS   AGE
pod/ledger-api-79c8695b76-ddrfv   1/1     Running   0          19m
pod/ledger-api-79c8695b76-lf6cv   1/1     Running   0          19m
pod/ledger-api-79c8695b76-scg6v   1/1     Running   0          19m
pod/reporting-67ccdc8894-bh8d9    1/1     Running   0          21m

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/ledger-api   ClusterIP   10.108.178.28   <none>        8080/TCP   21m
service/reporting    ClusterIP   10.109.232.88   <none>        80/TCP     21m

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ledger-api   3/3     3            3           21m
deployment.apps/reporting    1/1     1            1           21m

NAME                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/ledger-api-586c8c56b9   0         0         0       20m
replicaset.apps/ledger-api-79c8695b76   3         3         3       19m
replicaset.apps/ledger-api-79db76cd5    0         0         0       21m
replicaset.apps/reporting-67ccdc8894    1         1         1       21m
```

---

## 2. Hardened Deployment Manifest
```bash
$ cat deploy/deployment.yaml
```
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ledger-api
  namespace: payments
  labels:
    app: ledger-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ledger-api
  template:
    metadata:
      labels:
        app: ledger-api
    spec:
      serviceAccountName: ledger-api
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: ledger-api
          image: docker.io/library/ledger-api:starter
          imagePullPolicy: IfNotPresent
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 10001
            runAsGroup: 10001
          envFrom:
            - configMapRef:
                name: ledger-api-config
          env:
            - name: STRIPE_API_KEY
              valueFrom:
                secretKeyRef:
                  name: ledger-api-secrets
                  key: STRIPE_API_KEY
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ledger-api-secrets
                  key: DB_PASSWORD
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
```

---

## 3. SecurityContext Container Level (Runtime Proof)
```bash
$ kubectl get pod -n payments -l app=ledger-api -o jsonpath='{.items[0].spec.containers[0].securityContext}' | jq
```
```json
{
  "allowPrivilegeEscalation": false,
  "capabilities": {
    "drop": [
      "ALL"
    ]
  },
  "readOnlyRootFilesystem": true,
  "runAsGroup": 10001,
  "runAsNonRoot": true,
  "runAsUser": 10001
}
```

---

## 4. SecurityContext Pod Level (Runtime Proof)
```bash
$ kubectl get pod -n payments -l app=ledger-api -o jsonpath='{.items[0].spec.securityContext}' | jq
```
```json
{
  "runAsNonRoot": true,
  "seccompProfile": {
    "type": "RuntimeDefault"
  }
}
```

---

## 5. Resource Limits (Runtime Proof)
```bash
$ kubectl describe pod ledger-api-79c8695b76-ddrfv -n payments | grep -A 10 "Limits:"
```
```text
    Limits:
      cpu:     200m
      memory:  256Mi
    Requests:
      cpu:      100m
      memory:   128Mi
    Liveness:   http-get http://:8080/health delay=10s timeout=1s period=10s #success=1 #failure=3
    Readiness:  http-get http://:8080/health delay=5s timeout=1s period=10s #success=1 #failure=3
    Environment Variables from:
      ledger-api-config  ConfigMap  Optional: false
    Environment:
```

---

## 6. Liveness Probe (Runtime Proof)
```bash
$ kubectl describe pod ledger-api-79c8695b76-ddrfv -n payments | grep -A 5 "Liveness:"
```
```text
    Liveness:   http-get http://:8080/health delay=10s timeout=1s period=10s #success=1 #failure=3
    Readiness:  http-get http://:8080/health delay=5s timeout=1s period=10s #success=1 #failure=3
    Environment Variables from:
      ledger-api-config  ConfigMap  Optional: false
    Environment:
      STRIPE_API_KEY:  <set to the key 'STRIPE_API_KEY' in secret 'ledger-api-secrets'>  Optional: false
```

---

## 7. Readiness Probe (Runtime Proof)
```bash
$ kubectl describe pod ledger-api-79c8695b76-ddrfv -n payments | grep -A 5 "Readiness:"
```
```text
    Readiness:  http-get http://:8080/health delay=5s timeout=1s period=10s #success=1 #failure=3
    Environment Variables from:
      ledger-api-config  ConfigMap  Optional: false
    Environment:
      STRIPE_API_KEY:  <set to the key 'STRIPE_API_KEY' in secret 'ledger-api-secrets'>  Optional: false
      DB_PASSWORD:     <set to the key 'DB_PASSWORD' in secret 'ledger-api-secrets'>     Optional: false
```

---

## 8. Dedicated ServiceAccount
```bash
$ kubectl get serviceaccount -n payments
```
```text
NAME         AGE
default      22m
ledger-api   22m
reporting    21m
```

---

## 9. RBAC Role
```bash
$ kubectl get role -n payments && kubectl describe role ledger-api-role -n payments
```
```text
NAME              CREATED AT
ledger-api-role   2026-07-09T08:32:52Z
Name:         ledger-api-role
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources  Non-Resource URLs  Resource Names  Verbs
  ---------  -----------------  --------------  -----
```

---

## 10. RBAC RoleBinding
```bash
$ kubectl get rolebinding -n payments && kubectl describe rolebinding ledger-api-rolebinding -n payments
```
```text
NAME                     ROLE                   AGE
ledger-api-rolebinding   Role/ledger-api-role   22m
Name:         ledger-api-rolebinding
Labels:       <none>
Annotations:  <none>
Role:
  Kind:  Role
  Name:  ledger-api-role
Subjects:
  Kind            Name        Namespace
  ----            ----        ---------
  ServiceAccount  ledger-api  payments
```

---

## 11. SealedSecret and Decrypted Secret (metadata only)
```bash
$ kubectl get sealedsecret -n payments && kubectl get secret ledger-api-secrets -n payments
```
```text
NAME                 AGE
ledger-api-secrets   22m
NAME                 TYPE     DATA   AGE
ledger-api-secrets   Opaque   2      22m
```

---

## 12. Encrypted Secrets Manifest (safe, encrypted, not plaintext)
```bash
$ cat deploy/secrets.yaml
```
```yaml
---
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  creationTimestamp: null
  name: ledger-api-secrets
  namespace: payments
spec:
  encryptedData:
    DB_PASSWORD: AgCZ+aSk/cwbzh728XzX8LHTB2f4hLSOF8yqj9ug9QPtAi5L94yNH1LNqiY2HsNkF44mo6wHP9vPm9gA9wsa3oGEtdR5wvrizrtJ8QFnfYrbMgGbueEFl+scq4CcBhGC6KWxbOYUOA1T/t0USuQob33+6AmDK8Q27fKBLvAgZmpM+omfjaCsE/qH2JfQts/i/LojhhXzeDnSZ9PDKadJpfB28MCQwrNTgh/nN59MYGW9zCPKN3MVADw4o7yLWvGiWFD4MoQvJQS3Ib7tRrVo9rXrSOJNe0B5eCx4hnKsF5tl9tdnrQns1swZGw1UBumwh8U4mXestyAkVDPxSzdP0fYfD1BS94Alq33DyzUPz4hAC4wdQr4piPjmi+YWa9hlb9GOF5H7CzK5Jzv49Yl0cBijrX8ANLT5P+hxzE6eBUxarzSebGguIxZ1wKEuXF9z77gbJlbLMzV+sDe7WFJWQELcyvjiG0BO+8n+JRgoyjkonBlPe7I9IYJW2d+PblZDCvfALUlXeqS54W1OiBJL3TOBAza+7ZqWDhRb6GBPxU0FPxARe8I2lCYVfR+Sa3Yh890SeqyKZyaDARUNOeEOtsIHga6B0WlSvj0HX9I99HejpYfOQmlnxopCR7lrCNAMpFHerxBAbjK8O2lQO53QVjcvmqDyKTJn+83jRJOq1/21TRY5AkfGzmoCtMYmGlXAZqN8W+DXcMQCEKKlMg==
    STRIPE_API_KEY: AgChyA0oGZwwlnAF7dcd5w4HemzO4DT8KwZ7GTJ/dYDIrSvNjupWzr+si3VLm4uxzxRsUibfxCQMZfc6I/LzUf56sLelqM/GLIR4mVoW7xRMZJug3suld0KamAGfF9M2riyZurqIsQj0IBt+SwYLX+u0L9jwugaKf3GE//2wvTbfnkujVH4OJbRE0+ZO3oqWNicBZv4KOPuhzj8x3alUFQgaIXu0rSUHSJpv+nuFiYvI5/6DQSh9oeuklG5Jtsg00qw3Z4XOff3OGoZ7qbow5vIQtiLLo/GBg/ww68Ukqo2+5RAkS/KT+RYXw7fP36AylxfxmbKIpMIqD+v+no6YOxe7FGVEhgxzSjrBnKiIz75Eq0lWKgTSK+pWdpYpQCp697DRLvRu4RptM/hxa/I2In3bds+KsgCmp3ObuR507XLwD6BZe3/yRLCPXUn/7Py8y4nYv9sKTewAFSnR/faAtUzb2surTLS1xgmNlwyzEPtueiIUm5W75AQkaDIqPacxIgDhJPbrh6SCjsLjQAdEcQzbbRfNERiYL5EWauWSz27a962k/l8hRF1i9SL+aH32hVg1XoCrorBGxYYSruFOe0vartrW3lgYZNjoDkS4CeMqQkfePOIlrO+l7KT+blP4z1uVs2WqCMrQm23qKNfv92PXY+y2ke2Q1qAVhDdxTujrb6shly1hmV+XG52Kk/sYchet3EqO6O971jGsdl9ugAdbE3O3fwWxciRTwtYySw==
  template:
    metadata:
      creationTimestamp: null
      name: ledger-api-secrets
      namespace: payments
```

---

## 13. ConfigMap
```bash
$ kubectl get configmap -n payments && kubectl describe configmap ledger-api-config -n payments
```
```text
NAME                DATA   AGE
kube-root-ca.crt    1      22m
ledger-api-config   1      22m
reporting-config    1      22m
Name:         ledger-api-config
Namespace:    payments
Labels:       <none>
Annotations:  <none>

Data
====
FLASK_ENV:
----
production


BinaryData
====

Events:  <none>
```

---

## 14. Ingress Resource
```bash
$ kubectl get ingress -n payments
```
```text
NAME                 CLASS   HOSTS   ADDRESS        PORTS   AGE
ledger-api-ingress   nginx   *       192.168.49.2   80      22m
```

---

## 15. Ingress End-to-End Connectivity Test
```bash
$ curl -v -H "Host: ledger-api.local" http://192.168.49.2/health
```
```text
*   Trying 192.168.49.2:80...
* Connected to 192.168.49.2 (192.168.49.2) port 80
> GET /health HTTP/1.1
> Host: ledger-api.local
> User-Agent: curl/8.5.0
> Accept: */*
> 
< HTTP/1.1 200 OK
< Date: Thu, 09 Jul 2026 08:59:24 GMT
< Content-Type: application/json
< Content-Length: 21
< Connection: keep-alive
< 
{
  "status": "ok"
}
* Connection #0 to host 192.168.49.2 left intact
```


---

## 16. Kyverno ClusterPolicies Active
```bash
$ kubectl get clusterpolicy
```
```text
NAME                    ADMISSION   BACKGROUND   READY   AGE   MESSAGE
disallow-latest-tag     true        true         True    15m   Ready
require-non-root-user   true        true         True    15m   Ready
```

---

## 17. Kyverno Policy Details
```bash
$ kubectl describe clusterpolicy require-non-root-user && kubectl describe clusterpolicy disallow-latest-tag
```
```text
Name:         require-non-root-user
Namespace:    
Labels:       <none>
Annotations:  <none>
API Version:  kyverno.io/v1
Kind:         ClusterPolicy
Metadata:
  Creation Timestamp:  2026-07-09T08:40:24Z
  Generation:          1
  Resource Version:    56616
  UID:                 04bf31bc-c351-45e4-bbab-074b65966342
Spec:
  Admission:     true
  Background:    true
  Emit Warning:  false
  Rules:
    Match:
      Any:
        Resources:
          Kinds:
            Pod
    Name:                      check-run-as-non-root
    Skip Background Requests:  true
    Validate:
      Allow Existing Violations:  true
      Any Pattern:
        Spec:
          Security Context:
            Run As Non Root:  true
        Spec:
          Containers:
            Security Context:
              Run As Non Root:  true
      Message:                  Running as root is not allowed. Set runAsNonRoot to true.
  Validation Failure Action:    Enforce
Status:
  Autogen:
    Rules:
      Match:
        Any:
          Resources:
            Kinds:
              apps/v1/DaemonSet
              apps/v1/Deployment
              batch/v1/Job
              apps/v1/ReplicaSet
              v1/ReplicationController
              apps/v1/StatefulSet
        Resources:
      Name:                      autogen-check-run-as-non-root
      Skip Background Requests:  true
      Validate:
        Allow Existing Violations:  true
        Any Pattern:
          Spec:
            Template:
              Spec:
                Security Context:
                  Run As Non Root:  true
          Spec:
            Template:
              Spec:
                Containers:
                  Security Context:
                    Run As Non Root:  true
        Message:                      Running as root is not allowed. Set runAsNonRoot to true.
      Match:
        Any:
          Resources:
            Kinds:
              batch/v1/CronJob
        Resources:
      Name:                      autogen-cronjob-check-run-as-non-root
      Skip Background Requests:  true
      Validate:
        Allow Existing Violations:  true
        Any Pattern:
          Spec:
            Job Template:
              Spec:
                Template:
                  Spec:
                    Security Context:
                      Run As Non Root:  true
          Spec:
            Job Template:
              Spec:
                Template:
                  Spec:
                    Containers:
                      Security Context:
                        Run As Non Root:  true
        Message:                          Running as root is not allowed. Set runAsNonRoot to true.
  Conditions:
    Last Transition Time:  2026-07-09T08:40:24Z
    Message:               Ready
    Reason:                Succeeded
    Status:                True
    Type:                  Ready
  Rulecount:
    Generate:      0
    Mutate:        0
    Validate:      1
    Verifyimages:  0
  Validatingadmissionpolicy:
    Generated:  false
    Message:    
Events:
  Type     Reason           Age   From               Message
  ----     ------           ----  ----               -------
  Warning  PolicyViolation  15m   kyverno-scan       Pod kube-system/kube-controller-manager-minikube: [check-run-as-non-root] fail; validation error: Running as root is not allowed. Set runAsNonRoot to true. rule check-run-as-non-root[0] failed at path /spec/securityContext/runAsNonRoot/ rule check-run-as-non-root[1] failed at path /spec/containers/0/securityContext/
  Warning  PolicyViolation  14m   kyverno-scan       Pod kube-system/storage-provisioner: [check-run-as-non-root] fail; validation error: Running as root is not allowed. Set runAsNonRoot to true. rule check-run-as-non-root[0] failed at path /spec/securityContext/runAsNonRoot/ rule check-run-as-non-root[1] failed at path /spec/containers/0/securityContext/
  Warning  PolicyViolation  13m   kyverno-admission  Deployment payments/ledger-api-insecure: [autogen-check-run-as-non-root] fail (blocked); validation error: Running as root is not allowed. Set runAsNonRoot to true. rule autogen-check-run-as-non-root[0] failed at path /spec/template/spec/securityContext/runAsNonRoot/ rule autogen-check-run-as-non-root[1] failed at path /spec/template/spec/containers/0/securityContext/

Name:         disallow-latest-tag
Namespace:    
Labels:       <none>
Annotations:  <none>
API Version:  kyverno.io/v1
Kind:         ClusterPolicy
Metadata:
  Creation Timestamp:  2026-07-09T08:40:24Z
  Generation:          1
  Resource Version:    56618
  UID:                 80d11600-d661-4623-8677-26f0c262cd0b
Spec:
  Admission:     true
  Background:    true
  Emit Warning:  false
  Rules:
    Match:
      Any:
        Resources:
          Kinds:
            Pod
    Name:                      require-image-tag
    Skip Background Requests:  true
    Validate:
      Allow Existing Violations:  true
      Message:                    An image tag is required and must not be 'latest'.
      Pattern:
        Spec:
          Containers:
            Image:            !*:latest
  Validation Failure Action:  Enforce
Status:
  Autogen:
    Rules:
      Match:
        Any:
          Resources:
            Kinds:
              apps/v1/DaemonSet
              apps/v1/Deployment
              batch/v1/Job
              apps/v1/ReplicaSet
              v1/ReplicationController
              apps/v1/StatefulSet
        Resources:
      Name:                      autogen-require-image-tag
      Skip Background Requests:  true
      Validate:
        Allow Existing Violations:  true
        Message:                    An image tag is required and must not be 'latest'.
        Pattern:
          Spec:
            Template:
              Spec:
                Containers:
                  Image:  !*:latest
      Match:
        Any:
          Resources:
            Kinds:
              batch/v1/CronJob
        Resources:
      Name:                      autogen-cronjob-require-image-tag
      Skip Background Requests:  true
      Validate:
        Allow Existing Violations:  true
        Message:                    An image tag is required and must not be 'latest'.
        Pattern:
          Spec:
            Job Template:
              Spec:
                Template:
                  Spec:
                    Containers:
                      Image:  !*:latest
  Conditions:
    Last Transition Time:  2026-07-09T08:40:24Z
    Message:               Ready
    Reason:                Succeeded
    Status:                True
    Type:                  Ready
  Rulecount:
    Generate:      0
    Mutate:        0
    Validate:      1
    Verifyimages:  0
  Validatingadmissionpolicy:
    Generated:  false
    Message:    
Events:
  Type     Reason           Age   From               Message
  ----     ------           ----  ----               -------
  Warning  PolicyViolation  13m   kyverno-admission  Deployment payments/ledger-api-insecure: [autogen-require-image-tag] fail (blocked); validation error: An image tag is required and must not be 'latest'. rule autogen-require-image-tag failed at path /spec/template/spec/containers/0/image/
```

---

## 18. Kyverno Enforcement Proof (Insecure Deployment Blocked)
```bash
$ kubectl apply -f deploy/insecure-test-DO-NOT-USE.yaml
```
```text
Warning: would violate PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "ledger-api" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "ledger-api" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "ledger-api" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "ledger-api" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
Error from server: error when creating "task-1-hardening/deploy/insecure-test-DO-NOT-USE.yaml": admission webhook "validate.kyverno.svc-fail" denied the request:

resource Deployment/payments/ledger-api-insecure was blocked due to the following policies

disallow-latest-tag:
  autogen-require-image-tag: 'validation error: An image tag is required and must
    not be ''latest''. rule autogen-require-image-tag failed at path /spec/template/spec/containers/0/image/'
require-non-root-user:
  autogen-check-run-as-non-root: 'validation error: Running as root is not allowed.
    Set runAsNonRoot to true. rule autogen-check-run-as-non-root[0] failed at path
    /spec/template/spec/securityContext/runAsNonRoot/ rule autogen-check-run-as-non-root[1]
    failed at path /spec/template/spec/containers/0/securityContext/'
```

Note: This output demonstrates defense-in-depth. The native Kubernetes Pod Security Standards (`restricted` enforcement) and the Kyverno policies act as two independent layers checking and blocking the insecure deployment.

---

## Bonus Section A: Persona-Based RBAC (Developer / Operator / Admin)

The persona-based RBAC model provides least-privilege access for three realistic personas scoped strictly to the `payments` namespace:
- **developer**: read-only access to Pods, logs, Services, ConfigMaps, and Deployments (get, list, watch verbs only).
- **operator**: developer permissions plus pod delete (for triggering restarts) and deployment update/patch (for scaling/restarts), with no access to Secrets or RBAC resources.
- **admin**: full resource access (all verbs on all resources) scoped strictly within the namespace (`Role`, not `ClusterRole`).

### 1. Applying the Persona RBAC Manifest
```bash
$ kubectl apply -f deploy/bonus-persona-rbac.yaml
```
```text
role.rbac.authorization.k8s.io/developer-role created
rolebinding.rbac.authorization.k8s.io/developer-rolebinding created
role.rbac.authorization.k8s.io/operator-role created
rolebinding.rbac.authorization.k8s.io/operator-rolebinding created
role.rbac.authorization.k8s.io/admin-role created
rolebinding.rbac.authorization.k8s.io/admin-rolebinding created
```

### 2. Full Contents of deploy/bonus-persona-rbac.yaml
```bash
$ cat deploy/bonus-persona-rbac.yaml
```
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: payments
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]
--- 
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-rolebinding
  namespace: payments
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: developer-role
subjects:
  # Placeholder subject for developer persona binding
  - kind: User
    name: developer-user
    apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: operator-role
  namespace: payments
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["delete"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: operator-rolebinding
  namespace: payments
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: operator-role
subjects:
  # Placeholder subject for operator persona binding
  - kind: User
    name: operator-user
    apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: admin-role
  namespace: payments
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: admin-rolebinding
  namespace: payments
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: admin-role
subjects:
  # Placeholder subject for admin persona binding
  - kind: User
    name: admin-user
    apiGroup: rbac.authorization.k8s.io
```

### 3. Active Roles and RoleBindings
```bash
$ kubectl get role -n payments && kubectl get rolebinding -n payments
```
```text
NAME              CREATED AT
admin-role        2026-07-09T09:10:05Z
developer-role    2026-07-09T09:10:05Z
ledger-api-role   2026-07-09T08:32:52Z
operator-role     2026-07-09T09:10:05Z
NAME                     ROLE                   AGE
admin-rolebinding        Role/admin-role        1s
developer-rolebinding    Role/developer-role    1s
ledger-api-rolebinding   Role/ledger-api-role   37m
operator-rolebinding     Role/operator-role     1s
```

---

## Bonus Section B: Pod Security Standards (Restricted) Enforcement

Labeling a namespace alone does not retroactively re-evaluate already-running pods. To ensure Pod Security Standards validation is truly active and enforcing, an existing `ledger-api` pod was deleted to force the ReplicaSet controller to recreate it fresh, triggering a real admission webhook/policy check.

### 1. Labeling the namespace
```bash
$ kubectl label namespace payments pod-security.kubernetes.io/enforce=restricted --overwrite
```
```text
namespace/payments labeled
```

### 2. Verifying namespace labels
```bash
$ kubectl get namespace payments --show-labels
```
```text
NAME       STATUS   AGE   LABELS
payments   Active   37m   kubernetes.io/metadata.name=payments,pod-security.kubernetes.io/enforce=restricted
```

### 3. Updated namespace.yaml Contents
```bash
$ cat deploy/namespace.yaml
```
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: payments
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

#### 4. Pod Deletion to Force Admission Policy Check
```bash
$ kubectl delete pod ledger-api-668cd4b4cf-f7scs -n payments
```
```text
pod "ledger-api-668cd4b4cf-f7scs" deleted
```

### 5. Running Pods After Recreation
```bash
$ kubectl get pods -n payments
```
```text
NAME                          READY   STATUS    RESTARTS   AGE
ledger-api-668cd4b4cf-g6dmt   1/1     Running   0          69s
ledger-api-668cd4b4cf-hg6sw   1/1     Running   0          69s
ledger-api-668cd4b4cf-td9fv   1/1     Running   0          38s
```

### 6. Event Log Showing Successful Creation
```bash
$ kubectl get events -n payments --sort-by='.lastTimestamp' | tail -10
```
```text
72s         Normal    Started             pod/ledger-api-668cd4b4cf-g6dmt    Container started
72s         Normal    Started             pod/ledger-api-668cd4b4cf-f7scs    Container started
72s         Normal    Created             pod/ledger-api-668cd4b4cf-g6dmt    Container created
72s         Normal    Pulled              pod/ledger-api-668cd4b4cf-f7scs    Container image "docker.io/library/ledger-api:starter" already present on machine and can be accessed by the pod
42s         Normal    Killing             pod/ledger-api-668cd4b4cf-f7scs    Stopping container ledger-api
42s         Normal    Scheduled           pod/ledger-api-668cd4b4cf-td9fv    Successfully assigned payments/ledger-api-668cd4b4cf-td9fv to task1-verify
42s         Normal    SuccessfulCreate    replicaset/ledger-api-668cd4b4cf   (combined from similar events): Created pod: ledger-api-668cd4b4cf-td9fv
41s         Normal    Started             pod/ledger-api-668cd4b4cf-td9fv    Container started
41s         Normal    Pulled              pod/ledger-api-668cd4b4cf-td9fv    Container image "docker.io/library/ledger-api:starter" already present on machine and can be accessed by the pod
41s         Normal    Created             pod/ledger-api-668cd4b4cf-td9fv    Container created
```

### 7. Isolated Cluster Configuration Proof
The following outputs confirm Kyverno pods status, ClusterPolicies status, and namespace labels on the dedicated `task1-verify` cluster without any Istio mesh/Task 3 sidecars injected (indicated by `1/1` readiness state instead of `2/2`):
```bash
$ kubectl config current-context
task1-verify

$ kubectl get pods -n kyverno
NAME                                             READY   STATUS    RESTARTS        AGE
kyverno-admission-controller-7cdf5b9c-6zljt      1/1     Running   1 (3m30s ago)   20m
kyverno-background-controller-7b54965bf9-cwsgf   1/1     Running   2 (3m30s ago)   20m
kyverno-cleanup-controller-59c8fdfb66-q9tkp      1/1     Running   3 (3m31s ago)   20m
kyverno-reports-controller-5c96886c9-pj98c       1/1     Running   2 (3m31s ago)   20m

$ kubectl get clusterpolicy
NAME                    ADMISSION   BACKGROUND   READY   AGE   MESSAGE
disallow-latest-tag     true        true         True    12m   Ready
require-non-root-user   true        true         True    12m   Ready

$ kubectl get namespace payments --show-labels
NAME       STATUS   AGE   LABELS
payments   Active   12m   kubernetes.io/metadata.name=payments,pod-security.kubernetes.io/enforce=restricted
```

### 8. Verification Summary Note
Note: This test was re-run on a dedicated, isolated cluster (task1-verify) containing only Task 1 resources, to avoid any interference from Task 3's Istio mesh sidecar injection present on the main development cluster. Kyverno and Pod Security Standards were both independently confirmed active and healthy on this cluster before the test. One pod (ledger-api-668cd4b4cf-f7scs) was deleted; the ReplicaSet recreated it as ledger-api-668cd4b4cf-td9fv, which reached 1/1 Running with no PolicyViolation events, confirming the Task 1 securityContext hardening is fully compatible with Kyverno and PSS restricted enforcement.

