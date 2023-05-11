---
title: "Task 1 - Install Multus"
chapter: true
weight: 1
---

### Task 1 - Install and Validate Multus

Amazon EKS supports Multus, a Container Network Interface (CNI) plugin that enables you to attach multiple network interfaces to your Kubernetes pods. This can be useful for workloads requiring additional network isolation or advanced networking features. In this demo, application pod will use additional network to communicate with **cFOS**. So we will need install multus with additional CNI. 

> **_NOTE:_** To use Multus on Amazon EKS, you'll need to install and configure it manually. 

1. Here's a high-level overview of the steps:

    * Create a VPC and configure the required subnets for your EKS cluster

    * Deploy an EKS cluster using **eksctl** or any other method you prefer
    
    * Install the Multus CNI plugin on your EKS cluster. You can find the installation instructions in the official [Multus GitHub repository](https://github.com/k8snetworkplumbingwg/multus-cni#quickstart)

      {{< notice info >}}In this demo, we will use ***macvlan*** as secondary CNI for EKS. ***macvlan CNI*** is installed by default on EKS.{{< /notice >}}
   
   * Configure CNI plugins
      * Multus works as a **meta-plugin** that calls other CNI plugins. You'll need to have at least one additional CNI plugin installed and configured. Popular choices include Flannel, Calico, and Weave. You can find a list of [CNI plugins](https://github.com/containernetworking/plugins)

1. Clone GitHub Repo

   The repository include multus installation yaml file. It is the standard multus yaml file with 3.9.3 stable release image.

   ```
   git clone https://github.com/FortinetSecDevOps/technical-recipe-cfos.git
   ```

1. install multus using yaml file 

   ```
   kubectl create -f technical-recipe-cfos/deployment_files/k8s/multus-daemonset-stable.yml
   ```

1. Validate multus installation 

   ```
   podname=$(kubectl get pod -l app=multus -n kube-system -o jsonpath='{.items[0].metadata.name}')
   kubectl logs -f po/$podname  -n kube-system
   ```
   > you shall see if multus installation is sucessful. 

   ```
   Defaulted container "kube-multus" out of: kube-multus, install-multus-binary (init)
   kubeconfig is created in /host/etc/cni/net.d/multus.d/multus.kubeconfig
   kubeconfig file is created.
   master capabilities is get from conflist
   multus config file is created.
   ```

   > wait until multus is ready 

   ```
   kubectl rollout status ds/kube-multus-ds -n kube-system && kubectl get pod -n kube-system -l app=multus
   ```

   > output will be similar as below
   
   ```
   daemon set "kube-multus-ds" successfully rolled out
   NAME                   READY   STATUS    RESTARTS   AGE
   kube-multus-ds-lbj5d   1/1     Running   0          2m11s
   ```