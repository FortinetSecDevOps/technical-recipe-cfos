---
title: "Task 6 - check cFOS container log"
chapter: true
weight: 7
---

### Task 6 - check cFOS container log

below you will see that cFOS container have sucessfully load the license from configmap and system is ready

copy and paste below command to check cFOS license 

```
kubectl logs -f $(kubectl get pod -l app=fos -o jsonpath='{.items[0].metadata.name}')
```

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