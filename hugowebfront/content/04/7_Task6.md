---
title: "Task 6 - Verify cFOS Logs"
chapter: true
weight: 7
---

### Task 6 - Verify cFOS Container logs

* From the below commands, you will notice the **cFOS** container has sucessfully loaded the license from ConfigMap and system is ready.


> Below command will check **cFOS** license

```
kubectl logs -f $(kubectl get pod -l app=fos -o jsonpath='{.items[0].metadata.name}')
```

> output will be similar as below

```
System is starting...

Firmware version is 7.2.0.0231
Preparing environment...
INFO: 2023/03/31 05:37:02 importing license...
INFO: 2023/03/31 05:37:02 license is imported successfuly!
WARNING: System is running in restricted mode due to lack of valid license!
Starting services...
System is ready.

2023-03-31_05:37:03.20787 ok: run: /run/fcn_service/certd: (pid 301) 0s, normally down
2023-03-31_05:37:08.25153 INFO: 2023/03/31 05:37:08 received a new fos configmap
2023-03-31_05:37:08.25158 INFO: 2023/03/31 05:37:08 configmap name: fos-license, labels: map[app:fos category:license]
2023-03-31_05:37:08.25158 INFO: 2023/03/31 05:37:08 got a fos license
```