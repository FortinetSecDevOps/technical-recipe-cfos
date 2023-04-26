---
title: "Task 2 - Check Multus CNI"
chapter: true
weight: 3
---

### Task 2 - Check if Multus CNI is the default CNI

   > **_NOTE:_** EKS cluster by default use **aws vpc cni** as the deafult cni. Once Multus is installed, Multus will become the first CNI and delegate to AWS VPC CNI.
   You will notice that cni name is ***multus-cni-network*** with delegate to ***aws-cni*** from work node. cni config file is located at `/etc/cni/net.d/00-multus.conf`

1. Check if Multus CNI is the default cni for EKS on work node

   ```
   ➜  010-eks git:(main) ✗ kubectl get node -o wide
   NAME                                       STATUS   ROLES    AGE    VERSION               INTERNAL-IP   EXTERNAL-IP    OS-IMAGE         KERNEL-VERSION                  CONTAINER-RUNTIME
   ip-10-0-14-93.ap-east-1.compute.internal   Ready    <none>   141m   v1.25.7-eks-a59e1f0   10.0.14.93    18.167.17.26   Amazon Linux 2   5.10.173-154.642.amzn2.x86_64   containerd://1.6.6
   ➜  010-eks git:(main) ✗ ssh ec2-user@18.167.17.26
   Last login: Mon Apr  3 01:59:32 2023 from 115.197.132.80

         __|  __|_  )
         _|  (     /   Amazon Linux 2 AMI
         ___|\___|___|

   https://aws.amazon.com/amazon-linux-2/
   [ec2-user@ip-10-0-14-93 ~]$ sudo su
   [root@ip-10-0-14-93 ec2-user]# cat /etc/cni/net.d/00-multus.conf | jq .
   {
   "cniVersion": "0.3.1",
   "name": "multus-cni-network",
   "type": "multus",
   "capabilities": {
      "portMappings": true
   },
   "kubeconfig": "/etc/cni/net.d/multus.d/multus.kubeconfig",
   "delegates": [
      {
         "cniVersion": "0.4.0",
         "name": "aws-cni",
         "disableCheck": true,
         "plugins": [
         {
            "name": "aws-cni",
            "type": "aws-cni",
            "vethPrefix": "eni",
            "mtu": "9001",
            "podSGEnforcingMode": "strict",
            "pluginLogFile": "/var/log/aws-routed-eni/plugin.log",
            "pluginLogLevel": "DEBUG"
         },
         {
            "name": "egress-v4-cni",
            "type": "egress-v4-cni",
            "mtu": 9001,
            "enabled": "false",
            "randomizeSNAT": "prng",
            "nodeIP": "10.0.14.93",
            "ipam": {
               "type": "host-local",
               "ranges": [
               [
                  {
                     "subnet": "169.254.172.0/22"
                  }
               ]
               ],
               "routes": [
               {
                  "dst": "0.0.0.0/0"
               }
               ],
               "dataDir": "/run/cni/v6pd/egress-v4-ipam"
            },
            "pluginLogFile": "/var/log/aws-routed-eni/egress-v4-plugin.log",
            "pluginLogLevel": "DEBUG"
         },
         {
            "type": "portmap",
            "capabilities": {
               "portMappings": true
            },
            "snat": true
         }
         ]
      }
   ]
   }
   [root@ip-10-0-14-93 ec2-user]#

   ```