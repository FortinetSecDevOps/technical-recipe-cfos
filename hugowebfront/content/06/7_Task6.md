---
title: "Task 6 - create clientpod to update the addressgroup"
chapter: true
weight: 7
---

### Task 6 - create clientpod to update the addressgroup 

the clientpod also support update POD ip address for the policy created by gatekeeper. 
the yaml file watchandupdatcfospodip.yaml is under git repo 202301/demo/eks/policy.

```
kubectl create -f watchandupdatcfospodip.yaml
```

you can use `kubectl logs -f po/clientpod` to check the log of clientpod.
