---
title: "Chapter 6 - Kubernetes Network Policy"
chapter: true
weight: 6
---

## Fortinet cFOS Workshop

### Chapter 6 - Kubernetes Network Policy

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


> **_NOTE:_** The idea is use ***gatekeeper*** with ***opa policy*** is to review the ***networkpolicy***. If the ***networkpolicy*** meet the ***constraintTemplate***, the ***contraintTemplate*** will use **cFOS** restful API to create a firewall policy on **cFOS**. 

In this chapter you will perform below tasks:

* Delete firewall policy and clientpod
* Install gatekeeperv3
* Deploy constraintTemplate
* Deploy constraint for cFOS network policy
* Create egress network policy
* Create clientpod to update addressgroup
* Clean Up