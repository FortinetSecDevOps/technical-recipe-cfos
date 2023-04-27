---
title: "Task 5 - Validate cFOS DaemonSet"
chapter: true
weight: 6
---

### Task 5 - Validate cFOS DaemonSet deployment


> Below command will get details of the cFOS DaemonSet deployment

```
kubectl rollout status ds fos-deployment && kubectl get ds fos-deployment && kubectl get pod
```

> output will be similar as below
    
```
daemon set "fos-deployment" successfully rolled out
NAME             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
fos-deployment   1         1         1       1            1           <none>          54s
NAME                                     READY   STATUS    RESTARTS   AGE
fos-deployment-j8f74                     1/1     Running   0          54s
multitool01-deployment-88ff6b48c-fdght   1/1     Running   0          11m
multitool01-deployment-88ff6b48c-h9t5t   1/1     Running   0          11m
multitool01-deployment-88ff6b48c-xgwt8   1/1     Running   0          11m
multitool01-deployment-88ff6b48c-xt69j   1/1     Running   0          11m
```
