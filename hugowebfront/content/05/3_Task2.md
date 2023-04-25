---
title: "Task 2 - check the deployment result"
chapter: true
weight: 3
---

### Task 2 - check the deployment result

```
kubectl rollout status deployment multitool01-deployment
```

you shall see 

```
✗ kubectl rollout status deployment multitool01-deployment
Waiting for deployment "multitool01-deployment" rollout to finish: 0 of 4 updated replicas are available...
Waiting for deployment "multitool01-deployment" rollout to finish: 1 of 4 updated replicas are available...
Waiting for deployment "multitool01-deployment" rollout to finish: 2 of 4 updated replicas are available...
Waiting for deployment "multitool01-deployment" rollout to finish: 3 of 4 updated replicas are available...
deployment "multitool01-deployment" successfully rolled out
```

check the pod status 

```
kubectl get pod -l app=multitool01
```

you shall see 

```
NAME                                     READY   STATUS    RESTARTS   AGE
multitool01-deployment-88ff6b48c-d2drz   1/1     Running   0          33s
multitool01-deployment-88ff6b48c-klx2z   1/1     Running   0          33s
multitool01-deployment-88ff6b48c-pzssg   1/1     Running   0          33s
multitool01-deployment-88ff6b48c-t97t6   1/1     Running   0          33s
```