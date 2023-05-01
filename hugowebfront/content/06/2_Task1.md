---
title: "Task 1 - Delete firewall policy and clientpod"
chapter: true
weight: 2
---

### Task 1 - delete existing firewall policy and clientpod

1. Use ***eksctl*** to reduce the node to 1.  

1. We will use REST API's, DNS name to config firewall policy on **cFOS**. 

1. Unless all nodes use shared data storage like NFS, otherwise we have to reduce the number of nodes to 1. 

> **_NOTE:_** Make sure the response of the REST API's is Success (200 Status). 

```
eksctl scale nodegroup DemoNodeGroup --cluster EKSDemo -N 1 -M 2 --region ap-east-1 && kubectl get node
```

> Delete the clientpod

```
kubectl delete po/clientpod
```

> **_NOTE:_** Delete **cFOS** firewall policy on manually. Make sure there is no firewall policy on **cFOS**.