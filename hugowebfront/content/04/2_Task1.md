---
title: "Task 1 - Pull cFOS image from docker repository"
chapter: true
weight: 2
---

### Task 1 - Pull cFOS image from docker repository

1. install docker secret to pull cfos image from docker repository

   > **_NOTE:_** use the docker secret file created earlier in Chapter - 1 

   ```
   kubectl create -f dockerpullsecret.yaml
   ```

   if you have not created dockerpullsecret yet. you can also create this directly inside the kubernetes with command

   ```
   kubectl create secret docker-registry dockerinterbeing --docker-server https://index.docker.io/v1/ --docker-username=<YOURDOCKERUSERNAME> --docker-password=<YOURDOCKERPASSWORD> --docker-email=<YOURDOCKEMAIL>
   ```

   output should be similar as below

   ```
   ➜  eks git:(main) ✗ kubectl create -f dockerpullsecret.yaml
   secret/dockerinterbeing created
   ➜  eks git:(main) ✗ kubectl get secret
   NAME               TYPE                             DATA   AGE
   dockerinterbeing   kubernetes.io/dockerconfigjson   1      8s
   ➜  eks git:(main) ✗
   ```
