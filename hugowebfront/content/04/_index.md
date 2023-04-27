---
title: "Chapter 4 - Deploy cFOS"
chapter: true
weight: 4
---

## Fortinet cFOS Workshop

### Chapter 4 - Deploy cFOS

This chapter will guide you through on how to deploy cFOS. 

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
* Cluster POD to POD Traffic: eth0 (Application Pod) <--> eth0 (cFOS Pod)
* Internet Traffic Flow: 
    * Application Pod --> net1 (cFOS Pod) --> eth0 (sNAT enabled) --> Internet
* The eth0 interfaces are managed by Multus with delegation to `AWS VPC CNI`, and the net1 interfaces are managed by Multus with delegation to `macvlan CNI`
{{< /notice >}}

In this chapter you will perform below tasks:


* Pull **cFOS** image
* Create ConfigMap
* Create role for **cFOS**
* Create **cFOS** DaemonSet
* Validate **cFOS** DaemonSet
* Verify **cFOS** logs
* Verify IP address and Routing Table
* Get **cFOS** POD description
* Verify **cFOS** configuration