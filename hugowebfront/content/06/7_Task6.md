---
title: "Task 6 - Create clientpod to update addressgroup"
chapter: true
weight: 7
---

### Task 6 - Create clientpod to update addressgroup

Clientpod can also update the IP Address of the POD for the policy created by gatekeeper. 

One can use the yaml file watchandupdatcfospodip.yaml located in GIT Repo 202301/demo/eks/policy.

```
kubectl create -f watchandupdatcfospodip.yaml
```

> **_NOTE:_** Can use `kubectl logs -f po/clientpod` to check the logs of clientpod
