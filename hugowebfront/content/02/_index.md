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


In this chapter you will perform below tasks:

* Install ***eksctl*** and ***kubectl***
* IAM permissions to create EKS Cluster
* Deploy EKS Cluster