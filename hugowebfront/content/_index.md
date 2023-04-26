---
title: "Fortinet cFOS Workshop"
chapter: true
weight: 1
---

## Fortinet cFOS Workshop

In this workshop you will learn what **cFOS** is and how it can be used to secure containers

### About TEC Workshops

TEC Workshops provide the learner with the opportunity to put into practice newly developed skills in an easy to launch environment that can be used for customer engagements. At a minimum a TEC Workshop will include the following:

* A use case description
* An integrated lab and demo environment

  * Informational call-outs for key points to discuss or highlight to a customer
  * Questions that could be asked while giving the TEC Workshop as a demo
  * Points of value that relate the business value to the technical feature
* A reference architecture(s)

Optional components may be included for certain use cases

The TEC Workshop will not be a completely, self-contained learning experience for a single product. A TEC Workshop will cover features and often multiple products where they relate to the use case of interest.  

Deployments will be automated for those tasks that are not salient to the learning or demonstration activity in the use case. For example, for a TEC Workshop focused on Indicators of Compromise, the system may deploy a FortiGate and FortiAnalyzer with configurations for these systems. However, the leaner will have to configure the Event Handlers for IOC setup.  

## cFOS TEC Workshop

**Introduction:**

**cFOS** is a containerized version of FortiOS that meets the OCI(Open Container Initiative) standard, allowing it to run under Docker, container(s), and CRI-O runtimes.

**cFOS** offers Layer 7 security features such as Intrusion Prevention System (IPS), DNS filtering, web filtering and SSL deep inspection. It also provides real-time security updates from FortiGuard, which help detect and prevent cyberattacks, block malicious traffic and provide secure access to resources.

When deployed in Kubernetes (k8s), **cFOS** can protect 
  * IP traffic from pod egress to the internet.
  * east-west traffic between different pod CIDR subnets. 

This is achieved by multiple ways like adding the Multus CNI. 

* With Multus, **cFOS** can use one interface for control plane communication (such as accessing the Kubernetes API and exposing services to the external world) while using another interface dedicated to inspecting traffic from other pods. This setup separates control plane traffic from data plane traffic. The additional interface can be associated with high-performance NICs, such as those with SR-IOV enabled, for optimal performance and low latency. 

{{< notice info >}}One of the use case for **cFOS** is pod egress security.{{< /notice >}}

## TEC Workshop Objectives

Pod egress security is essential for protecting networks and data from potential threats originating from outgoing traffic in Kubernetes clusters. 

Here are some reasons why pod egress security is crucial:

* **Prevent data exfiltration:** Without proper egress security controls, a malicious actor could potentially use an application running in a pod to exfiltrate sensitive data from the cluster.
* **Control outgoing traffic:** By restricting egress traffic from pods to specific IP addresses or domains, organizations can prevent unauthorized communication with external entities and control access to external resources.
* **Comply with regulatory requirements:** Many regulations require organizations to implement controls around outgoing traffic to ensure compliance with data privacy and security regulations. Implementing pod egress security controls can help organizations meet these requirements.
* **Prevent malware infections:** A pod compromised by malware could use egress traffic to communicate with external command and control servers, leading to further infections and data exfiltration. Egress security controls can help prevent these types of attacks. 

In summary, implementing pod egress security controls is a vital part of securing Kubernetes clusters and ensuring the integrity, confidentiality, and availability of organizational data. In this use case, applications can route traffic through a dedicated network created by Multus to the **cFOS** pod. The **cFOS** pod inspects packets for IPS attacks, URL filtering, DNS filtering, and performs deep packet inspection for SSL encrypted traffic.

***

{{< notice warning >}}
The examples and sample code provided in this workshop are intended to be consumed as instructional content. These will help you understand how various Fortinet services can be architected to build a solution while demonstrating best practices along the way. These examples are not intended for use in production environments without full understanding of how they operate.
{{< /notice >}}