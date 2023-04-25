---
title: "Task 1 - delete existing firewall policy and clientpod"
chapter: true
weight: 2
---

### Task 1 - delete existing firewall policy and clientpod

use eksctl to reduce the node to 1.  we will use restful API DNS name to config firewall policy on cFOS. unless all nodes use shared data storage like NFS. otherwise we have to reduce the number of nodes to 1. to make sure the restful API call sucess. 

```
eksctl scale nodegroup DemoNodeGroup --cluster EKSDemo -N 1 -M 2 --region ap-east-1 && kubectl get node
```

delete the clientpod

```
kubectl delete po/clientpod
```

delete cFOS firewall policy on cFOS manually , so you do not have any firewall policy on cFOS