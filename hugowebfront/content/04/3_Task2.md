---
title: "Task 2 - create a configmap with cfos license"
chapter: true
weight: 3
---

### Task 2 - create a configmap with cFOS license


1. create a configmap with cFOS license

   * cfos require a license to be functional. The license can be configured use cfos cli or use kubernetes configmap
   * cfos will use kubenetes API to read the configmap once cfos start
   * once cFOS container boot up, it will read the configmap to obtain the license
   * cfos license configmap has below format

   > **_NOTE:_**  use the yaml file you created in chapter 1 

   ```
   kubectl create -f cfos_license.yaml && kubectl get cm fos-license 
   ```

   output should be similar as below 

   ```
   ➜  ✗ kubectl create -f fos_license.yaml && kubectl get cm fos-license
   configmap/fos-license created
   NAME          DATA   AGE
   fos-license   1      0s
   ```