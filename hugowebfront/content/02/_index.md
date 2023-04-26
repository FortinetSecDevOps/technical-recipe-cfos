---
title: "Chapter 2 - Setting up EKS Cluster"
chapter: true
weight: 2
---

## Fortinet cFOS Workshop

### Chapter 2 - Setting up EKS Cluster

This chapter will guide you through setup EKS cluster. 

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

In this chapter you will perform below tasks:

* Install ***eksctl*** and ***kubectl***
* IAM permissions to create EKS Cluster
* Deploy EKS Cluster