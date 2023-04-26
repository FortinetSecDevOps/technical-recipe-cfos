---
title: "Chapter 3 - Install & Setup Multus"
chapter: true
weight: 3
---

## Fortinet cFOS Workshop

### Chapter 3 - Install & Setup Multus

This chapter will guide you through Installing & Setup Multus. 

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

Amazon EKS supports Multus, a Container Network Interface (CNI) plugin that enables you to attach multiple network interfaces to your Kubernetes pods. This can be useful for workloads requiring additional network isolation or advanced networking features. In the subsequent demo, application pod will use additional network to communicate with **cFOS**. So we will need install multus with additional CNI. 

> **_NOTE:_** To use Multus on Amazon EKS, you'll need to install and configure it manually. 

In this chapter you will perform below tasks:

* Install and Validate Multus
* Check Multus CNI
* Create Multus CRD