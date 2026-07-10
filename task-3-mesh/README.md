# Service Mesh and Zero Trust Security

This folder contains the files for Task 3. We set up a service mesh using Istio. We also implemented network security policies. These controls secure the communication between our services.

## Istio Installation and CNI

We installed Istio using the demo profile. This profile is useful for local testing. It includes the control plane and ingress gateways. 

Initially, Istio sidecars required elevated root privileges to redirect network traffic. This ran into conflicts with the restricted pod security standards we set up in Task 1. To fix this, we enabled the Istio CNI plugin. The CNI plugin handles traffic redirection at the node level. This setup lets us keep the payments namespace under the restricted pod security profile.

## Mutual TLS

We configured a PeerAuthentication policy. It enforces strict mutual TLS for all services in the payments namespace. This means all connections inside the namespace must be encrypted. They must also use mutual authentication. Any plaintext request from outside or inside the namespace is rejected immediately at the transport layer. We verified this by attempting a plaintext call and confirming that the connection gets reset.

## Authorization Policies

We implemented a default deny policy for the payments namespace. This policy blocks all service to service communication by default. 

We then created an explicit allow policy for the ledger api service. This policy allows requests only from the reporting service. The rule is based on the SPIFFE workload identity of the reporting service account. It does not rely on IP addresses. We verified this by running a request from an unauthorized test pod. That request was blocked with a 403 Forbidden error.

## Certificate Issuance and Rotation

Workload certificates are issued by the istiod control plane. The agent inside the pod requests a certificate using its service account token. The control plane signs it and returns the certificate. 

We inspected the certificates issued to our pods. The issuer is the local cluster authority. The workload certificate has a validity window of 24 hours. The root authority cert is valid for 10 years. We checked the system and confirmed there is no external certificate authority secret. This proves the mesh uses its own self signed root certificate.

## Network Security Policies

We implemented a Kubernetes NetworkPolicy to enforce security at the IP and port levels. 

By default, the minikube network driver does not enforce these rules. We deleted the cluster and restarted it with Calico CNI enabled. We applied a default deny policy. We then added explicit allow policies. We verified that removing these policies causes connection timeouts. The packets are dropped by Calico.

## Bonus Features and Scope Mapping

We implemented three bonus features for this task.

1. **Ingress Gateway with TLS:** We generated a self signed certificate for testing. We loaded it as a secret. We configured an Istio Gateway and VirtualService. This exposes the ledger api service to external clients securely.
2. **Canary Releases:** We configured weighted routing rules. They split internal traffic 90/10 between version 1 and version 2 of the ledger api. We ran a loop of 40 requests to verify the traffic split works.
3. **PCI CDE Scope Mapping:** We mapped our implemented controls to PCI DSS requirements. The payments namespace acts as the cardholder data environment. All other namespaces are out of scope. We documented the specific network, encryption, and access policies that map to requirements 1, 4, 7, and 8. We also identified logging and monitoring as an active gap since we did not implement central log storage in this local cluster.

## Files in this Folder

- `README.md`: The document you are reading right now.
- `TASK3_CHECKLIST.md`: The checklist we used to track our tasks.
- `peer-authentication.yaml`: Enforces strict mutual TLS in the payments namespace.
- `auth-deny-all.yaml`: Restricts all mesh access in the namespace by default.
- `auth-allow-reporting.yaml`: Allows the reporting service account to access the ledger api.
- `net-deny-all.yaml`: Implements a default deny NetworkPolicy at the packet layer.
- `net-allow-ledger-api.yaml`: Allows ingress and egress traffic for the ledger api.
- `net-allow-reporting.yaml`: Allows ingress and egress traffic for the reporting service.
- `net-allow-unauth.yaml`: Allows the unauthorized test pod to connect to CoreDNS and the control plane.
- `gateway.yaml`: Configures the external gateway and VirtualService with TLS.
- `destination-rule.yaml`: Defines subsets for version 1 and version 2 of the ledger api.
- `virtual-service-internal.yaml`: Implements the 90/10 canary traffic split.
- `tmp-pod.yaml`: A temporary pod used to test plaintext access blocks.
- `tmp-unauth-mesh.yaml`: A temporary pod used to verify identity based authorization policy blocks.
- `patch-argocd.yaml`: A temporary patch file used to disable automated sync in ArgoCD.
- `patch-restore-sync.yaml`: A temporary patch file used to restore automated sync in ArgoCD.
- `run-count.sh`: A helper script used to verify the traffic split ratio programmatically.
- `test-split.sh`: A helper script used to send traffic to the canary services.
