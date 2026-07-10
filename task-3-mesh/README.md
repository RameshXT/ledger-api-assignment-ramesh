# Service Mesh and Zero Trust Security

This folder contains the files for Task 3. A service mesh was set up using Istio, and network security policies were also implemented. These controls secure the communication between our services. All mesh security and traffic policies are now declaratively managed via GitOps using a dedicated ArgoCD Application (`argocd-app-mesh.yaml`), completely separate from Task 1's main application deployment (`ledger-app`).

## Istio Installation and CNI

Istio was installed using the demo profile. This profile is useful for local testing. It includes the control plane and ingress gateways. 

Initially, Istio sidecars required elevated root privileges to redirect network traffic. This ran into conflicts with the restricted pod security standards we set up in Task 1. To fix this, the Istio CNI plugin was enabled. The CNI plugin handles traffic redirection at the node level. This setup lets us keep the payments namespace under the restricted pod security profile.

## Mutual TLS

A PeerAuthentication policy was configured to enforce strict mutual TLS for all services in the payments namespace. This means all connections inside the namespace must be encrypted. They must also use mutual authentication. Any plaintext request from outside or inside the namespace is rejected immediately at the transport layer. This was verified by attempting a plaintext call and confirming that the connection gets reset.

## Authorization Policies

A default deny policy was implemented for the payments namespace. This policy blocks all service to service communication by default. 

An explicit allow policy was then created for the ledger api service. This policy allows requests only from the reporting service. The rule is based on the SPIFFE workload identity of the reporting service account. It does not rely on IP addresses. This was verified by running a request from an unauthorized test pod. That request was blocked with a 403 Forbidden error.

## Certificate Issuance and Rotation

Workload certificates are issued by the istiod control plane. The agent inside the pod requests a certificate using its service account token. The control plane signs it and returns the certificate. 

Workload certificates issued to the pods were inspected. The issuer is the local cluster authority. The workload certificate has a validity window of 24 hours. The root authority cert is valid for 10 years. The system was checked and it was confirmed that there is no external certificate authority secret. This proves the mesh uses its own self signed root certificate.

Workload certificates in this deployment follow Istio's default rotation behavior. By default, the workload certificates are valid for 24 hours (SECRET_TTL), and the local `istio-agent` running in the sidecar proxy initiates a Secret Discovery Service (SDS) key rotation request when the certificate reaches 50% of its lifetime (a 12 hour grace period/rotation trigger). In this setup, the environment variables modifying the default certificate lifetime (`SECRET_TTL`) or rotation grace periods were left at their default values, meaning certificate rotation occurs automatically every 12 hours without service disruption.

## NetworkPolicy vs AuthorizationPolicy Defense in Depth

Security is enforced at both L3/L4 and L7 using a layered approach:

1. **What Kubernetes NetworkPolicy (Calico L3/L4) Catches**: It intercepts and filters traffic at the packet level based on raw IP addresses, namespaces, and TCP/UDP ports. Because Istio's `AuthorizationPolicy` is enforced directly within the Envoy sidecar proxy, any workload running outside the mesh (without a sidecar) completely bypasses Istio L7 logic if it attempts to connect directly to app endpoints via bypass routes. Calico stops these packets immediately at L3/L4 regardless of sidecar presence.
2. **What Istio AuthorizationPolicy (L7/Identity) Catches**: It authenticates and authorizes requests based on cryptographically verifiable SPIFFE identities associated with workload ServiceAccounts. As demonstrated by the `tmp-unauth-mesh` test recorded in `EVIDENCE.md`, the L4 NetworkPolicy deliberately allowed the TCP connection from the `tmp-unauth-mesh` pod to go through on port 8080 to `ledger-api`, but Istio's `AuthorizationPolicy` successfully intercepted the traffic at L7 and returned `403 Forbidden` because the request did not originate from the authorized `reporting` ServiceAccount. NetworkPolicy alone cannot differentiate between different workloads or ServiceAccounts sharing the same namespace/network labels without L7 inspection.
3. **Why Both Layers Matter for the PCI-Scoped Ledger**: Having both provides defence in depth mandatory for PCI environments. L4 NetworkPolicy implements hard network isolation by preventing IP reachability and containing compromises to sub-networks, while L7 AuthorizationPolicy provides fine-grained identity-based access control, securing the data plane against spoofing and unauthorized communications even if network-level rules are overly broad or bypassed.

## Network Security Policies

A Kubernetes NetworkPolicy was implemented to enforce security at the IP and port levels. 

By default, the minikube network driver does not enforce these rules. The cluster was deleted and restarted with Calico CNI enabled. A default deny policy was applied, and explicit allow policies were then added. It was verified that removing these policies causes connection timeouts. The packets are dropped by Calico.

## Bonus Features and Scope Mapping

Three bonus features were implemented for this task.

1. **Ingress Gateway with TLS:** A self signed certificate was generated for testing, loaded as a secret, and an Istio Gateway and VirtualService were configured. This exposes the ledger api service to external clients securely.
2. **Canary Releases:** Weighted routing rules were configured to split internal traffic 90/10 between version 1 and version 2 of the ledger api, and a loop of 40 requests was run to verify the traffic split works.
3. **PCI CDE Scope Mapping & Requirements Verification**: Our implemented cluster controls are mapped directly to PCI DSS requirements to establish and contain the Cardholder Data Environment (CDE) within the `payments` namespace:
    - **Requirement 1 (Install and maintain network security controls to restrict traffic)**: Satisfied by the `default-deny-all` L3/L4 NetworkPolicy blocking all unlisted ingress/egress traffic, and explicit `allow-ledger-api` and `allow-reporting` NetworkPolicies limiting communication paths.
    - **Requirement 4 (Protect cardholder data during transmission with strong cryptography)**: Satisfied by the `default` `PeerAuthentication` enforcing `STRICT` mTLS for all mesh services in the `payments` namespace, and external traffic TLS termination via the `ledger-api-gateway` using the `ledger-api-tls` secret.
    - **Requirement 7 (Restrict access to system components and cardholder data by business need to know)**: Satisfied by the `deny-all` and `allow-reporting-to-ledger` `AuthorizationPolicy` resources, which explicitly restrict L7 access to `ledger-api` to only the authorized `reporting` ServiceAccount identity.
    - **Requirement 8 (Identify users and authenticate access to system components via workload identities)**: Satisfied by Istio's automatic provisioning and rotation of cryptographic workload identities (SPIFFE principals tied to individual ServiceAccounts) validated on every L7 request.
    - **Known Limitation**: The test pod `tmp-unauth-mesh` used to verify `AuthorizationPolicy` denial behaviors currently runs persistently inside the `payments` namespace. In a production deployment, this testing artifact must be deleted or segregated outside the CDE boundary to prevent unnecessary attack surface expansion.

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
