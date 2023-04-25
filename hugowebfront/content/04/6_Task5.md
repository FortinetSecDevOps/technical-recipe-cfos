---
title: "Task 5 - check the cFOS daemonSet deployment"
chapter: true
weight: 6
---

### Task 5 - check the cFOS daemonSet deployment

1. check the cFOS daemonSet deployment

    ```
    kubectl rollout status ds fos-deployment && kubectl get ds fos-deployment && kubectl get pod
    ```

    output should be similar as below
    
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
