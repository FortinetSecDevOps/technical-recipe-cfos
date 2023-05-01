---
title: "Chapter 5 - Deploy Demo application"
chapter: true
weight: 5
---

## Fortinet cFOS Workshop

### Chapter 5 - Deploy Demo application

## Network Diagram
```stl
+---------------+   eth0    +--------------+  eth0 (SNAT)           
| Application   +---------->|    cFOS      |--------------  internet 
| Pod           | (VPC CNI) |              |  
+               +           +              +          
|               |   net1    |  DaemonSet   | 
|               +---------->|              |
|               | (macvlan) |              |
+---------------+           +--------------+ 
```
{{< notice info >}}
* Cluster POD to POD Traffic: eth0 (Application Pod) <--> eth0 (cFOS Pod).
* Internet Traffic: Application Pod ---> net1 (cFOS Pod) ---> eth0 (sNAT enabled) ---> Internet.
* The eth0 interfaces are managed by Multus with delegation to `AWS VPC CNI`, and the net1 interfaces are managed by Multus with delegation to `macvlan CNI`.
{{< /notice >}}

Amazon EKS supports Multus, a Container Network Interface (CNI) plugin that enables you to attach multiple network interfaces to your Kubernetes pods. This can be useful for workloads requiring additional network isolation or advanced networking features. In this demo, application pod will use additional network to communicate with cFOS. so we will need install multus with additional CNI. 

In this chapter you will perform below tasks:

* Deploy application
* Validate deployment
* Create other deployment
* Create Client POD
* Access internet via **cFOS**
* **cFOS** firewall addressgroup
* **cFOS** firewall policy
* Verify **cFOS** state
* Validate Web Filter feature
* Scale the app Deployment
* Verify **cFOS** firewall addressgroup
* Use **eksctl** to scale nodes
* Check new cFOS DaemonSet on new work node
* Scale-out application
* Verify POD accessibility