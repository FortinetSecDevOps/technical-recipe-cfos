---
title: "Task 2 - Create ConfigMap"
chapter: true
weight: 3
---

### Task 2 - Create a ConfigMap with cFOS license


* **cFOS** require a license to be functional. The license can be configured either by **cFOS** cli or with Kubernetes ConfigMap.
* **cFOS** will use Kubernetes API to read the ConfigMap once **cFOS** start.
* Once **cFOS** container boot up, it will read the ConfigMap to obtain the license.
* **cFOS** license ConfigMap has below format

> **_NOTE:_**  Use the yaml file created in Chapter-1 -> Task-5

```
   kubectl create -f cfos_license.yaml && kubectl get cm fos-license 
```

> output will be similar as below

```
   ➜  ✗ kubectl create -f fos_license.yaml && kubectl get cm fos-license
   configmap/fos-license created
   NAME          DATA   AGE
   fos-license   1      0s
```