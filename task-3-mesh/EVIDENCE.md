# Service Mesh and Zero Trust Security Evidence

This document provides raw logs, configurations, and outputs that prove the successful implementation of all Task 3 security controls.

---

## 1. Istio Installation and CNI Fix

Istio was installed using the demo profile with the CNI component enabled in the kube system namespace.

### Istio CNI Installation Command and Output

```bash
$ istioctl install --set profile=demo --set components.cni.enabled=true --set components.cni.namespace=kube-system -y
- Processing resources for Istio core.
✔ Istio core installed ⛵️
- Processing resources for CNI, Istiod.
- Processing resources for CNI, Istiod. Waiting for DaemonSet/kube-system/istio-cni-node
✔ CNI installed 🔌
✔ Istiod installed 🧠
- Processing resources for Egress gateways, Ingress gateways.
✔ Egress gateways installed 🛫
✔ Ingress gateways installed 🛬
- Pruning removed resources
✔ Installation complete
```

### Namespace Pod Security Standards Label Verification

Verification was done that the payments namespace remained under the restricted pod security profile.

```bash
$ kubectl get ns payments --show-labels
```
```text
NAME       STATUS   AGE   LABELS
payments   Active   19h   istio-injection=enabled,kubernetes.io/metadata.name=payments,pod-security.kubernetes.io/enforce=restricted
```

### Kube System Namespace Pod Status

It was confirmed that the Calico node and Istio CNI node pods are running successfully.

```bash
$ kubectl get pods -n kube-system | grep -E "calico|istio-cni"
calico-kube-controllers-565c89d6df-72pwd     1/1     Running   0             78m
calico-node-wdqjb                            1/1     Running   0             78m
istio-cni-node-xr8r5                         1/1     Running   0             69m
```

---

## 2. STRICT mTLS Proof

 A namespace wide PeerAuthentication policy was applied to enforce strict mutual TLS.

### PeerAuthentication Configuration

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: payments
spec:
  mtls:
    mode: STRICT
```

### Plaintext Request Refusal (Strict mTLS Verification)

### mTLS Mode Verification via istioctl proxy-config

The `istioctl proxy-config listener` command confirms the Envoy sidecar on the `ledger-api` pod is configured to accept **only TLS traffic** on the inbound listener (port 15006). All four filter chains on port 15006 show `Trans: tls`, confirming STRICT mTLS is enforced at the data plane level. There is no plaintext `raw_buffer` chain on the inbound port.

```bash
$ kubectl get peerauthentication -n payments -o wide
NAME      MODE     AGE
default   STRICT   8h

$ kubectl get peerauthentication default -n payments -o jsonpath='{.spec.mtls.mode}'
STRICT

$ istioctl proxy-config listener ledger-api-784cf8bcc8-4dsmr.payments --port 15006
ADDRESSES PORT  MATCH                                                    DESTINATION
0.0.0.0   15006 Addr: *:15006                                            Non-HTTP/Non-TCP
0.0.0.0   15006 Trans: tls; App: istio-http/1.0,istio-http/1.1,istio-h2 InboundPassthroughCluster
0.0.0.0   15006 Trans: tls                                               InboundPassthroughCluster
0.0.0.0   15006 Trans: tls; Addr: *:8080                                 Cluster: inbound|8080||
```

Note: `istioctl authn tls-check` was removed in Istio 1.6. The equivalent check in Istio 1.30 is `istioctl proxy-config listener` on the inbound port. All inbound filter chains showing `Trans: tls` with no `raw_buffer` entry confirms STRICT mTLS is active.

### Plaintext Request Refusal (Strict mTLS Verification)

A plaintext HTTP call was attempted to the ledger api service from a temporary pod outside the mesh. The connection was immediately reset by the Envoy proxy.

```bash
$ kubectl exec tmp-non-mesh -n default -- curl -iv http://ledger-api.payments.svc.cluster.local:8080/health
```
```text
  % Total   % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0* Host ledger-api.payments.svc.cluster.local:8080 was resolved.
* IPv6: (none)
* IPv4: 10.108.178.28
*   Trying 10.108.178.28:8080...
* Connected to ledger-api.payments.svc.cluster.local (10.108.178.28) port 8080
> GET /health HTTP/1.1
> Host: ledger-api.payments.svc.cluster.local:8080
> User-Agent: curl/8.8.0
> Accept: */*
> 
* Recv failure: Connection reset by peer
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
* Closing connection
curl: (56) Recv failure: Connection reset by peer
command terminated with exit code 56
```

### Plaintext Success under Permissive Mode (Contrast Check)

The PeerAuthentication policy mode was temporarily switched to permissive. The plaintext request succeeded.

```bash
$ kubectl patch peerauthentication default -n payments --type merge -p '{"spec":{"mtls":{"mode":"PERMISSIVE"}}}'
```
```text
peerauthentication.security.istio.io/default patched
```
```bash
$ kubectl exec tmp-non-mesh -n default -- curl -s http://ledger-api.payments.svc.cluster.local:8080/health
```
```json
{"status":"ok","version":"v1"}
```

### Reversion to STRICT Mode

The policy was reverted back to strict. Plaintext calls were refused once again.

```bash
$ kubectl patch peerauthentication default -n payments --type merge -p '{"spec":{"mtls":{"mode":"STRICT"}}}'
peerauthentication.security.istio.io/default patched

$ kubectl exec tmp-non-mesh -n default -- curl -iv http://ledger-api.payments.svc.cluster.local:8080/health
*   Trying 10.108.178.28:8080...
* Connected to ledger-api.payments.svc.cluster.local (10.108.178.28) port 8080
> GET /health HTTP/1.1
> Host: ledger-api.payments.svc.cluster.local:8080
> User-Agent: curl/8.8.0
> Accept: */*
> 
* Recv failure: Connection reset by peer
* Closing connection
curl: (56) Recv failure: Connection reset by peer
command terminated with exit code 56
```

---

## 3. AuthorizationPolicy Proof

A default deny policy was configured along with an explicit allow policy for the reporting service.

### AuthorizationPolicy Configuration

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: payments
spec: {}
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-reporting-to-ledger
  namespace: payments
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/payments/sa/reporting
  selector:
    matchLabels:
      app: ledger-api
```

### Unauthorized Request Rejection

A request was sent from an unauthorized mesh pod. It was blocked immediately with an HTTP 403 Forbidden status.

```bash
$ kubectl exec tmp-unauth-mesh -n payments -c client -- curl -iv http://ledger-api.payments.svc.cluster.local:8080/health
* Connected to ledger-api.payments.svc.cluster.local (10.103.48.248) port 8080
> GET /health HTTP/1.1
> Host: ledger-api.payments.svc.cluster.local:8080
> User-Agent: curl/8.8.0
> Accept: */*
> 
* Request completely sent off
< HTTP/1.1 403 Forbidden
< content-length: 19
< content-type: text/plain
< date: Fri, 10 Jul 2026 04:38:08 GMT
< server: envoy
< x-envoy-upstream-service-time: 13
< 
RBAC: access denied
```

### Authorized Request Success

A request was sent from the authorized reporting pod. The request succeeded with an HTTP 200 OK status.

```bash
$ kubectl exec reporting-7b55d78b8d-vbgnn -n payments -c client -- curl -iv http://ledger-api.payments.svc.cluster.local:8080/health
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0* Host ledger-api.payments.svc.cluster.local:8080 was resolved.
* IPv6: (none)
* IPv4: 10.108.178.28
*   Trying 10.108.178.28:8080...
* Connected to ledger-api.payments.svc.cluster.local (10.108.178.28) port 8080
> GET /health HTTP/1.1
> Host: ledger-api.payments.svc.cluster.local:8080
> User-Agent: curl/8.8.0
> Accept: */*
> 
* Request completely sent off
HTTP/1.1 200 OK
content-type: application/json
content-length: 21
server: envoy
date: Fri, 10 Jul 2026 03:56:49 GMT
x-envoy-upstream-service-time: 13

{
  "status": "ok"
}
< HTTP/1.1 200 OK
< content-type: application/json
< content-length: 21
< server: envoy
< date: Fri, 10 Jul 2026 03:56:49 GMT
< x-envoy-upstream-service-time: 13
< 
{ [21 bytes data]
100    21  100    21    0     0    164      0 --:--:-- --:--:-- --:--:--   165
* Connection #0 to host ledger-api.payments.svc.cluster.local left intact
```

### Sanity Check (Deleting the Allow Rule)

The allow rule was temporarily deleted. This blocked requests from the reporting service.

```bash
$ kubectl delete authorizationpolicy allow-reporting-to-ledger -n payments
authorizationpolicy.security.istio.io/allow-reporting-to-ledger deleted

$ kubectl exec reporting-7b55d78b8d-vbgnn -n payments -c client -- curl -s http://ledger-api.payments.svc.cluster.local:8080/health
RBAC: access denied

$ kubectl apply -f task-3-mesh/auth-allow-reporting.yaml
authorizationpolicy.security.istio.io/allow-reporting-to-ledger created
```

---

## 4. Certificate Issuance and Rotation Proof

Workload certificates are generated dynamically. Workload certificates were inspected using proxy configuration details.

### Decoded Workload Certificate Details

```text
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            fa:f1:01:74:ec:ef:96:9e:0a:f5:af:27:c0:0e:8b:a7
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: O = cluster.local
        Validity
            Not Before: Jul 10 03:52:30 2026 GMT
            Not After : Jul 11 03:54:30 2026 GMT
        Subject: 
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:b8:47:4b:95:d3:2e:d6:e4:20:9f:79:fc:14:52:
                    e9:b5:47:76:77:6b:b7:ac:2b:0a:f9:95:fb:19:09:
                    4d:c9:bd:25:28:6f:56:e7:c7:b4:bc:e9:ff:b6:95:
                    a8:30:15:0c:62:7e:9e:bb:27:51:0b:5b:5f:
                    c4:1b:01:b4:c8:43:ad:60:97:59:a5:e4:72:66:28:
                    bb:3b:c6:10:23:ef:43:bc:a9:72:ec:68:e4:49:dd:
                    1c:ac:87:b4:8e:01:3b:32:bb:e8:6b:88:32:07:9d:
                    4e:56:c6:f1:cb:c6:7f:4f:a4:ac:40:b7:00:00:4f:
                    57:b7:41:74:9b:df:52:a1:1a:91:78:cc:6c:76:11:
                    dd:40:13:89:85:06:f4:da:9f:6f:b5:8d:be:6c:4a:
                    fb:0e:7d:4d:84:cc:4c:66:e3:c1:10:78:45:b2:d7:
                    7d:dd:fb:49:ca:27:ab:82:42:2e:32:b2:f7:99:e4:
                    39:e0:99:15:78:fb:91:09:2f:5c:95:7d:5c:b9:ff:
                    5a:68:44:9e:be:a7:f4:74:ee:d9:d4:d9:5e:fc:35:
                    6c:97:16:a8:44:68:81:be:f8:7e:17:95:49:92:3b:
                    62:ab:c1:70:38:c6:fa:40:b6:d2:73:7f:5a:1f:97:
                    ff:d6:2d:e1:8b:59:ff:4e:d7:ec:55:b5:0c:bf:e4:
                    c3:07
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Authority Key Identifier: 
                77:69:84:6A:E2:B7:24:40:E1:23:CE:1D:0F:B7:45:9D:08:78:4A:7C
            X509v3 Subject Alternative Name: critical
                URI:spiffe://cluster.local/ns/payments/sa/ledger-api
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        45:8b:6e:7a:da:c5:cc:c1:e3:26:f9:81:ad:cb:53:37:3b:78:
        24:8b:97:44:0d:7c:2b:cc:a1:27:8b:61:8f:a8:2d:e3:c4:88:
        cd:ff:81:b7:b0:37:08:f6:67:d5:60:db:5e:b7:33:dd:a6:9a:
        12:3b:7c:6f:ff:60:f0:d3:87:6b:e0:d5:06:fa:fb:f7:94:6b:
        11:1b:6a:0c:bc:62:c5:40:28:e5:18:09:ee:11:95:2c:b3:89:
        9b:c7:8b:83:c5:2a:f9:36:33:44:00:9d:7b:1f:ac:8f:bd:2d:
        eb:d9:bf:7f:0e:bd:3e:bd:51:b8:a1:93:6b:e2:90:ae:1d:83:
        16:5f:90:72:3b:fc:eb:34:7a:99:d1:ec:21:23:b2:6d:45:1b:
        6b:93:8b:8c:02:c7:97:8f:4d:ea:a9:64:00:cd:f4:23:53:7b:
        ff:da:74:0d:fe:07:b5:b4:da:7a:c8:cc:c9:25:ad:d7:b2:bd:
        84:85:d8:79:a1:53:00:80:75:d1:b5:b7:a4:07:fe:46:7b:c7:
        b9:56:63:d6:ee:6f:b9:83:7e:ad:49:ab:d2:49:c6:45:78:57:
        fc:ea:e6:c3:df:6c:45:07:47:92:d7:82:0c:58:cc:a1:78:6f:
        f4:61:cc:47:c2:77:50:14:db:a1:20:da:04:18:77:3c:81:9a:
        09:13:51:61
```

### Decoded Root CA Certificate Details

```text
issuer=O = cluster.local
subject=O = cluster.local
notBefore=Jul 10 03:47:02 2026 GMT
notAfter=Jul  7 03:47:02 2036 GMT
```

### Built in CA Verification

It was verified that there is no custom CA secret in the namespace. This confirms the control plane uses its own root authority.

```bash
$ kubectl get secret cacerts -n istio-system
Error from server (NotFound): secrets "cacerts" not found
```

---

## 5. NetworkPolicy Proof

L3/L4 NetworkPolicies were enforced in the payments namespace.

### Default Deny NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: payments
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Allow NetworkPolicies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ledger-api
  namespace: payments
spec:
  podSelector:
    matchLabels:
      app: ledger-api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: reporting
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: istio-system
      podSelector:
        matchLabels:
          app: istio-ingressgateway
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 15006
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: istio-system
    ports:
    - protocol: TCP
      port: 15012
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-reporting
  namespace: payments
spec:
  podSelector:
    matchLabels:
      app: reporting
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - ports:
    - protocol: TCP
      port: 15021
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: istio-system
    ports:
    - protocol: TCP
      port: 15012
  - to:
    - podSelector:
        matchLabels:
          app: ledger-api
    ports:
    - protocol: TCP
      port: 8080
    - protocol: TCP
      port: 15006
```

### Verification of NetworkPolicy Enforcement

When the allow rules were temporarily removed, name resolution failed because DNS egress was blocked. Direct IP requests timed out at L3/L4. This caused Envoy to return a 503 connection timeout response.

```bash
$ kubectl delete networkpolicy allow-reporting -n payments
networkpolicy.networking.k8s.io "allow-reporting" deleted from payments namespace

$ kubectl exec reporting-7b55d78b8d-vbgnn -n payments -c client -- curl -iv --connect-timeout 5 http://ledger-api.payments.svc.cluster.local:8080/health
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0  0     0    0     0    0     0      0      0 --:--:--  0:00:01 --:--:--     0  0     0    0     0    0     0      0      0 --:--:--  0:00:02 --:--:--     0  0     0    0     0    0     0      0      0 --:--:--  0:00:03 --:--:--     0  0     0    0     0    0     0      0      0 --:--:--  0:00:05 --:--:--     0* Could not resolve host: ledger-api.payments.svc.cluster.local
* Closing connection
curl: (6) Could not resolve host: ledger-api.payments.svc.cluster.local
command terminated with exit code 6

$ kubectl exec reporting-7b55d78b8d-vbgnn -n payments -c client -- curl -iv --connect-timeout 5 http://10.244.120.127:8080/health
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying 10.244.120.127:8080...
* Connected to 10.244.120.127 (10.244.120.127) port 8080
> GET /health HTTP/1.1
> Host: 10.244.120.127:8080
> User-Agent: curl/8.8.0
> Accept: */*
> 
* Request completely sent off
  0     0    0     0    0     0      0      0 --:--:--  0:00:01 --:--:--     0  0     0    0     0    0     0      0      0 --:--:--  0:00:02 --:--:--     0  0     0    0     0    0     0      0      0 --:--:--  0:00:03 --:--:--     0  0     0    0     0    0     0      0      0 --:--:--  0:00:04 --:--:--     0  0     0    0     0    0     0      0      0 --:--:--  0:00:05 --:--:--     0  0     0    0     0    0     0      0      0 --:--:--  0:00:06 --:--:--     0  0     0    0     0    0     0      0      0 --:--:--  0:00:07 --:--:--     0  0     0    0     0    0     0      0      0 --:--:--  0:00:08 --:--:--     0  0     0    0     0    0     0      0      0 --:--:--  0:00:09 --:--:--     0  0     0    0     0    0     0      0      0 --:--:--  0:00:10 --:--:--     0HTTP/1.1 503 Service Unavailable
content-length: 91
content-type: text/plain
date: Fri, 10 Jul 2026 05:35:19 GMT
server: envoy

upstream connect error or disconnect/reset before headers. reset reason: connection timeout< HTTP/1.1 503 Service Unavailable
< content-length: 91
< content-type: text/plain
< date: Fri, 10 Jul 2026 05:35:19 GMT
< server: envoy
< 
{ [91 bytes data]
100    91  100    91    0     0      8      0  0:00:11  0:00:10  0:00:01    19100    91  100    91    0     0      8      0  0:00:11  0:00:10  0:00:01    25
* Connection #0 to host 10.244.120.127 left intact
```

### Success on Reapplying Policy

```bash
$ kubectl apply -f task-3-mesh/net-allow-reporting.yaml
networkpolicy.networking.k8s.io/allow-reporting created

$ kubectl exec reporting-7b55d78b8d-vbgnn -n payments -c client -- curl -iv --connect-timeout 5 http://ledger-api.payments.svc.cluster.local:8080/health
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0* Host ledger-api.payments.svc.cluster.local:8080 was resolved.
* IPv6: (none)
* IPv4: 10.103.48.248
*   Trying 10.103.48.248:8080...
* Connected to ledger-api.payments.svc.cluster.local (10.103.48.248) port 8080
> GET /health HTTP/1.1
> Host: ledger-api.payments.svc.cluster.local:8080
> User-Agent: curl/8.8.0
> Accept: */*
> 
* Request completely sent off
< HTTP/1.1 200 OK
< server: envoy
< date: Fri, 10 Jul 2026 05:35:32 GMT
< content-type: application/json
< content-length: 31
< x-envoy-upstream-service-time: 2
< 
{ [31 bytes data]
100    31  100    31    0     0   3430      0 --:--:-- --:--:-- --:--:--  3444100    31  100    31    0     0   3411      0 --:--:-- --:--:-- --:--:--  3444
* Connection #0 to host 10.103.48.248 left intact
HTTP/1.1 200 OK
server: envoy
date: Fri, 10 Jul 2026 05:35:32 GMT
content-type: application/json
content-length: 31
x-envoy-upstream-service-time: 2

{"status":"ok","version":"v1"}
```

*Note: For these network rules to be enforced, the minikube cluster was rebuilt with Calico CNI.*

---

## 6. Ingress Gateway with TLS Proof

The ledger api was exposed externally through the Istio Ingress Gateway.

### Gateway and VirtualService Configuration

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: ledger-api-gateway
  namespace: payments
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: ledger-api-tls
    hosts:
    - "ledger-api.local"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ledger-api-vs
  namespace: payments
spec:
  hosts:
  - "ledger-api.local"
  gateways:
  - ledger-api-gateway
  http:
  - route:
    - destination:
        host: ledger-api.payments.svc.cluster.local
        port:
          number: 8080
```

### Ingress Gateway Service Ports

```bash
$ kubectl get svc istio-ingressgateway -n istio-system
NAME                   TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                                                                      AGE
istio-ingressgateway   LoadBalancer   10.100.22.202   <pending>     15021:30886/TCP,80:30417/TCP,443:31385/TCP,31400:30219/TCP,15443:31537/TCP   67m
```

### Authorized HTTPS Request Proof

```bash
$ curl -iv https://ledger-api.local:31385/health --resolve ledger-api.local:31385:192.168.49.2 -k
* Added ledger-api.local:31385:192.168.49.2 to DNS cache
*   Trying 192.168.49.2:31385...
* Connected to ledger-api.local (192.168.49.2) port 31385
* TLSv1.3 connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
* ALPN: server accepted h2
* Server certificate:
*  subject: CN=ledger-api.local
*  start date: Jul 10 04:36:20 2026 GMT
*  expire date: Jul 10 04:36:20 2027 GMT
*  issuer: CN=ledger-api.local
*  SSL certificate verify result: self-signed certificate (18), continuing anyway.
* using HTTP/2
> GET /health HTTP/2
> Host: ledger-api.local:31385
> User-Agent: curl/8.8.0
> Accept: */*
> 
< HTTP/2 200 
< server: istio-envoy
{"status":"ok"}
```

### Unauthorized Plain HTTP Request Proof (Negative Control)

```bash
$ curl -iv http://ledger-api.local:30417/health --resolve ledger-api.local:30417:192.168.49.2
*   Trying 192.168.49.2:30417...
* connect to 192.168.49.2 port 30417 failed: Connection refused
* Failed to connect to ledger-api.local port 30417: Couldn't connect to server
```

---

## 7. Canary Release Proof

Traffic splitting was configured to distribute workloads between version 1 and version 2.

### DestinationRule and VirtualService Configuration

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: ledger-api-dr
  namespace: payments
spec:
  host: ledger-api.payments.svc.cluster.local
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: ledger-api-internal-vs
  namespace: payments
spec:
  hosts:
  - ledger-api.payments.svc.cluster.local
  http:
  - route:
    - destination:
        host: ledger-api.payments.svc.cluster.local
        subset: v1
      weight: 90
    - destination:
        host: ledger-api.payments.svc.cluster.local
        subset: v2
      weight: 10
```

### Verification Script and Traffic Tally Output

```bash
$ bash task-3-mesh/run-count.sh
v1 count:
36
v2 count:
4
total lines:
80 /tmp/canary-test-output.txt
```

*Note: Initially, these version labels existed only as manual changes. Enabling ArgoCD self heal again reverted them. This was fixed permanently by saving the version manifests inside the Git repository path tracked by ArgoCD.*

---

## 8. PCI CDE Scope Mapping

A complete table mapping these zero trust network, encryption, and access policies to PCI DSS requirements is documented in the README.md file in this directory.

---

## 9. Unexpected Findings during this Task

Two unexpected issues were encountered during the configuration phase.

1. **Pod Security Standard Regression:** Using the default Istio setup required the privileged `istio-init` container. This violated our restricted pod security standard. This was resolved by installing Istio with CNI enabled. This handled traffic redirection at the node layer and allowed the namespace to remain restricted.
2. **ArgoCD Self Heal Reversion:** When we manually updated version labels on pods for canary testing, ArgoCD self heal automatically reverted them to the tracked git baseline. This was resolved by writing the version configurations directly to the deployment yaml manifests in the git repository.

---

## 10. GitOps Management of Mesh Policies (ArgoCD)

Originally, Task 3's mesh policies (PeerAuthentication, AuthorizationPolicies, NetworkPolicies, VirtualServices, and Gateways) were applied manually to the cluster via `kubectl` and were not tracked in Git. 

To bring these under declarative GitOps management, we created a new ArgoCD Application (`ledger-mesh`) pointing to the `task-3-mesh` directory with exclusions for scripts and documentation assets.

### 1. Manual Deletion (Drift Testing)
To verify drift detection and self-healing of the mesh security controls, the `deny-all` AuthorizationPolicy was manually deleted:
```bash
$ kubectl delete authorizationpolicy deny-all -n payments
authorizationpolicy.security.istio.io "deny-all" deleted
```

### 2. Automated Restoration Proof
Within seconds, the ArgoCD controller detected the drift and automatically re-applied the `deny-all` policy:
```bash
$ kubectl get authorizationpolicy -n payments
NAME                        ACTION   AGE
allow-reporting-to-ledger   ALLOW    7h33m
deny-all                             25s
```

### 3. ArgoCD Controller Audit Logs
The audit trace from the controller shows the automatic sync detection and resolution events:
```text
Events:
  Type    Reason              Age   From                           Message
  ----    ------              ----  ----                           -------
  Normal  OperationStarted    26s   argocd-application-controller  Initiated automated sync to 'a313e4f4e3de6d80dac4074dd0225586b9a15008'
  Normal  ResourceUpdated     26s   argocd-application-controller  Updated sync status: Synced -> OutOfSync
  Normal  ResourceUpdated     26s   argocd-application-controller  Updated sync status: OutOfSync -> Synced
  Normal  OperationCompleted  25s   argocd-application-controller  Partial sync operation to a313e4f4e3de6d80dac4074dd0225586b9a15008 succeeded
```
