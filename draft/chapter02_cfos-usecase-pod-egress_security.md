- ## what is cfos 

cFOS is a containerized version of FortiOS that meets the OCI standard, allowing it to run under Docker, containerd, and CRI-O runtimes.

cFOS offers Layer 7 security features such as Intrusion Prevention System (IPS), DNS filtering, web filtering, and SSL deep inspection. It also provides real-time security updates from FortiGuard, which help detect and prevent cyberattacks, block malicious traffic, and provide secure access to resources.

When deployed in Kubernetes (k8s), cFOS can protect IP traffic from pod egress to the internet and can also protect east-west traffic between different pod CIDR subnets. This is enabled by adding the Multus CNI. With Multus, cFOS can use one interface for control plane communication (such as accessing the Kubernetes API and exposing services to the external world) while using another interface dedicated to inspecting traffic from other pods. This setup separates control plane traffic from data plane traffic. The additional interface can be associated with high-performance NICs, such as those with SR-IOV enabled, for optimal performance and low latency. One of the use cases for cFOS is pod egress security. 

- ## Use case : POD egress security 

Pod egress security is essential for protecting networks and data from potential threats originating from outgoing traffic in Kubernetes clusters. Here are some reasons why pod egress security is crucial:

- Prevent data exfiltration: Without proper egress security controls, a malicious actor could potentially use an application running in a pod to exfiltrate sensitive data from the cluster.
- Control outgoing traffic: By restricting egress traffic from pods to specific IP addresses or domains, organizations can prevent unauthorized communication with external entities and control access to external resources.
- Comply with regulatory requirements: Many regulations require organizations to implement controls around outgoing traffic to ensure compliance with data privacy and security regulations. Implementing pod egress security controls can help organizations meet these requirements.
- Prevent malware infections: A pod compromised by malware could use egress traffic to communicate with external command and control servers, leading to further infections and data exfiltration. Egress security controls can help prevent these types of attacks. 

In summary, implementing pod egress security controls is a vital part of securing Kubernetes clusters and ensuring the integrity, confidentiality, and availability of organizational data. In this use case, applications can route traffic through a dedicated network created by Multus to the cFOS pod. The cFOS pod inspects packets for IPS attacks, URL filtering, DNS filtering, and performs deep packet inspection for SSL encrypted traffic.

 
