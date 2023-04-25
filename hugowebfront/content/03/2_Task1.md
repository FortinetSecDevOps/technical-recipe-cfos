---
title: "Task 1 - Installing Multus"
chapter: true
weight: 1
---

### Task 1 - Installing Multus

Amazon EKS supports Multus, a Container Network Interface (CNI) plugin that enables you to attach multiple network interfaces to your Kubernetes pods. This can be useful for workloads requiring additional network isolation or advanced networking features. In this demo, application pod will use additional network to communicate with cFOS. so we will need install multus with additional CNI. 

> **_NOTE:_** To use Multus on Amazon EKS, you'll need to install and configure it manually. 

1. Here's a high-level overview of the steps:

    * Create a VPC and configure the required subnets for your EKS cluster.

    * Deploy an EKS cluster using **eksctl** or any other method you prefer.
    
    * Install the Multus CNI plugin on your EKS cluster. You can find the installation instructions in the official [Multus GitHub repository](https://github.com/k8snetworkplumbingwg/multus-cni#quickstart)

      {{< notice info >}}In this demo, we will use ***macvlan*** as secondary CNI for EKS. ***macvlan CNI*** is installed by default on EKS.{{< /notice >}}
   
   * Configure your CNI plugins.
      * Multus works as a **meta-plugin** that calls other CNI plugins. You'll need to have at least one additional CNI plugin installed and configured. Popular choices include Flannel, Calico, and Weave. You can find a list of [CNI plugins](https://github.com/containernetworking/plugins)

1. Clone GitHub Repo

   The repository include multus installation yaml file. It is the standard multus yaml file with 3.9.3 stable release image.

   ```
   git clone https://github.com/yagosys/202301.git 
   ```

1. install multus using yaml file 

   ```
   kubectl create -f 202301/deployment/k8s/multus-daemonset-stable.yml
   ```

1. Validate multus installation 

   ```
   podname=$(kubectl get pod -l app=multus -n kube-system -o jsonpath='{.items[0].metadata.name}')
   kubectl logs -f po/$podname  -n kube-system
   ```
   you shall see if multus installation is sucessful. 

   ```
   Defaulted container "kube-multus" out of: kube-multus, install-multus-binary (init)
   kubeconfig is created in /host/etc/cni/net.d/multus.d/multus.kubeconfig
   kubeconfig file is created.
   master capabilities is get from conflist
   multus config file is created.
   ```

   wait until multus ready 

   ```
   kubectl rollout status ds/kube-multus-ds -n kube-system && kubectl get pod -n kube-system -l app=multus
   ```
   you shall see
   ```
   daemon set "kube-multus-ds" successfully rolled out
   NAME                   READY   STATUS    RESTARTS   AGE
   kube-multus-ds-lbj5d   1/1     Running   0          2m11s
   ```

1. check the multus cni now become the default cni for EKS on work node

   the EKS cluster by default use aws vpc cni as the deafult cni, once multus installed. multus will become the first CNI and delegate to AWS VPC CNI.
   you will see that cni name is "multus-cni-network" with delegate to "aws-cni" from work node cni config file /etc/cni/net.d/00-multus.conf


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

1. Create  multus crd on EKS for application and cfos to attach 

   We need create additional network for application pod to communicate with cFOS. we use multus CRD to create this. 

   *the API for this CRD is k8s.cni.cncf.io/v1* 
   *this is a CRD which has kind "NetworkAttachmentDefinition*
   *the CRD has name cfosdefaultcni5*.
   *inside CRD, it include the json formatted cni configuration, it is the actual cni configuration, the macvlan binary will parse this json*
   *the cni use macvlan*
   *the cni mode is bridge*
   *"master interface for this maclan is eth0, so EKS will not create additional ENI as we only use this network for communication between applicaton POD to cFOS POD*
   *the ipam is host-local*

   copy and paste below code to your terminal window

   ```
   cat << EOF | kubectl create -f -
   apiVersion: "k8s.cni.cncf.io/v1"
   kind: NetworkAttachmentDefinition
   metadata:
   name: cfosdefaultcni5
   spec:
   config: '{
         "cniVersion": "0.3.0",
         "type": "macvlan",
         "master": "eth0",
         "mode": "bridge",
         "ipam": {
         "type": "host-local",
         "subnet": "10.1.200.0/24",
         "rangeStart": "10.1.200.20",
         "rangeEnd": "10.1.200.253",
         "gateway": "10.1.200.1"
         }
      }'
   EOF
   ```

1. check the crd installation

   ```
   ✗ kubectl get net-attach-def cfosdefaultcni5 -o yaml
   apiVersion: k8s.cni.cncf.io/v1
   kind: NetworkAttachmentDefinition
   metadata:
   creationTimestamp: "2023-03-31T03:53:31Z"
   generation: 1
   name: cfosdefaultcni5
   namespace: default
   resourceVersion: "5700"
   uid: 2e8127d2-4dd5-4c8d-b1c4-c43a7f78ecbd
   spec:
   config: '{ "cniVersion": "0.3.0", "type": "macvlan", "master": "eth0", "mode": "bridge",
      "ipam": { "type": "host-local", "subnet": "10.1.200.0/24", "rangeStart": "10.1.200.20",
      "rangeEnd": "10.1.200.253", "gateway": "10.1.200.1" } }'
   ```