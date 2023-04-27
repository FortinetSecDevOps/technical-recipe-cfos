---
title: "Task 1 - Pull cFOS image"
chapter: true
weight: 2
---

### Task 1 - Pull cFOS image from docker repository

1. Install docker secret to pull **cFOS** image from docker repository

   > **_NOTE:_** Use the docker secret file created earlier in Chapter-1 -> Task-4

   ```
   kubectl create -f dockerpullsecret.yaml
   ```

1. If you have not created dockerpullsecret, you can also create this directly inside the Kubernetes with below command

   ```
   kubectl create secret docker-registry dockerinterbeing --docker-server https://index.docker.io/v1/ --docker-username=<YOURDOCKERUSERNAME> --docker-password=<YOURDOCKERPASSWORD> --docker-email=<YOURDOCKEMAIL>
   ```

   > output will be similar as below

   ```
   ➜  eks git:(main) ✗ kubectl create -f dockerpullsecret.yaml
   secret/dockerinterbeing created
   ➜  eks git:(main) ✗ kubectl get secret
   NAME               TYPE                             DATA   AGE
   dockerinterbeing   kubernetes.io/dockerconfigjson   1      8s
   ➜  eks git:(main) ✗
   ```
