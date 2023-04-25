- ## Task Create cFOS for egress security in EKS cluster 

- ## Description

This chapter will guide you through setting up cFOS on an EKS cluster with AWS VPC CNI and macvlan CNI. The application pod will use an additional network to communicate with cFOS. Multus CNI is required to create and manage the additional network.

In this chapter, we will demonstrate how to set up cFOS to use an additional network to route traffic from two applications to the internet. We use Multus CNI to manage the additional network for traffic between cFOS and the application pod. Macvlan CNI is utilized as the actual CNI for the secondary network. In this setup, the application pod's IP address is visible to cFOS. There is no SNAT enabled on the net1 interface, so cFOS will need to add each pod IP address to the address group and use it as the source address in the firewall policy. We then use a client pod that continually updates the real pod IP address from the Kubernetes pod to the cFOS address group. We also demonstrate how cFOS can detect malicious URLs from the application pod to the internet, even when the traffic is HTTPS-based.

In the final portion, we demonstrate how to use Kubernetes egress network policy to apply firewall policy to cFOS. We use Gatekeeper to monitor the network policy. If the network policy has a label that matches what cFOS needs, the network policy request will be sent to cFOS via cFOS RESTful API to create a firewall policy configuration on cFOS.


- ## Network Diagram

```
+---------------+   eth0    +--------------+  eth0 (SNAT)           
| Application   +---------->|    cFOS      |--------------  internet 
| Pod           | (VPC CNI) |              |  
+               +           +              +          
|               |   net1    |  DaemonSet   | 
|               +---------->|              |
|               | (macvlan) |              |
+---------------+           +--------------+ 

Cluster POD to POD Traffic: eth0 (Application Pod) <--> eth0 (cFOS Pod)
Internet Traffic: Application Pod ---> net1 (cFOS Pod) ---> eth0 (sNAT enabled) ---> Internet 

The eth0 interfaces are managed by Multus with delegation to `AWS VPC CNI`, and the net1 interfaces are managed by Multus with delegation to `macvlan CNI`


```
both the Application POD and cFOS POD have two interfaces: eth0 and net1. The eth0 interfaces are managed by Multus with delegation to `AWS VPC CNI`, and the net1 interfaces are managed by Multus with delegation to `macvlan CNI`. The application POD communicates with the cFOS POD using the net1 interface. The traffic from the Application POD to the internet is routed through the cFOS POD, with SNAT enabled on the cFOS eth0 interface.

 

- ## Preparation

please complete https://fortinetsecdevops.github.io/tec-workshop-cFOS/01.html before continue

you shall have created **dockerpullsecret.yaml** and **cfos_license.yaml** file.

- ### install eksctl and kubectl on your client machine

eksctl is a command-line tool for creating and managing Amazon EKS clusters. To create an EKS cluster using eksctl, follow these steps:

Install eksctl:
Download and install eksctl following the instructions for your operating system on the official eksctl https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html

for ubuntu linux , paste below to your client machine to install eksctl 

```
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
```

install kubectl 
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

- ### required aws iam user for create EKS clustr  

You will use eksctl to create EKS cluster, When you use eksctl to create an Amazon EKS cluster, it requires an IAM user with sufficient permissions. The IAM user should have the following minimum permissions:

AmazonEKSFullAccess: This managed policy provides the necessary permissions to manage EKS clusters.

AmazonEKSClusterPolicy: This managed policy allows creating and managing the resources required for an EKS cluster, such as VPCs, subnets, and security groups.

AmazonEC2FullAccess: This managed policy provides permissions to manage EC2 instances and other related resources, such as key pairs, Elastic IPs, and snapshots.

IAMFullAccess: This managed policy allows eksctl to create and manage IAM roles for your Kubernetes workloads and the Kubernetes control plane.

AmazonVPCFullAccess: This managed policy allows eksctl to create and manage the VPC resources required for the EKS cluster, such as VPCs, subnets, route tables, and NAT gateways.

AWSCloudFormationFullAccess: This managed policy provides eksctl with permissions to create, update, and delete CloudFormation stacks, which are used to manage the infrastructure resources for your EKS cluster.



- ### check your iam permission on client machine
The `aws iam simulate-principal-policy` command is used to simulate the set of IAM policies attached to a principal (user, group, or role) to test their permissions for specific API actions. This command can help you determine whether a specific principal has the necessary permissions to perform a set of actions.
for example. below command shall show you  "EvalDecsion": allowed" 

```
myarn=$(aws sts get-caller-identity --output text | awk '{print $2}')
aws iam simulate-principal-policy --policy-source-arn $myarn --action-names "eks:CreateCluster" "eks:DescribeCluster" "ec2:CreateVpc" "iam:CreateRole" "cloudformation:CreateStack" | grep Eval
```

- ### create ssh key for access eks work node 
paste cli command below in your client terminal to create ssh key if not exist 

```
[ -f ~/.ssh/id_rsa.pub ] || ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ''
```
- ## create EKS cluster 

we use eksctl and eks config file to create EKS cluster.  

below is a standard EKS config with all default configuration

*you will need generate your own ssh key , which you can use ssh-keygen and place it under ~/.ssh/id*
*the kubernetes serviceCIDR is 10.96.0.0/12*
*the VPC has subnet 10.0.0.0/16*
*the default region and az is on ap-east-1, you can change to other regions and az if you want*


the kubernetes version is 1.25
paste below script on your client terminal to create eks cluster 

```
cat << EOF | eksctl create cluster -f -
apiVersion: eksctl.io/v1alpha5
availabilityZones:
- ap-east-1b
- ap-east-1a
cloudWatch:
  clusterLogging: {}
iam:
  vpcResourceControllerPolicy: true
  withOIDC: false
kind: ClusterConfig
kubernetesNetworkConfig:
  ipFamily: IPv4
  serviceIPv4CIDR: 10.96.0.0/12
managedNodeGroups:
- amiFamily: AmazonLinux2
  desiredCapacity: 1
  disableIMDSv1: false
  disablePodIMDS: false
  iam:
    withAddonPolicies:
      albIngress: false
      appMesh: false
      appMeshPreview: false
      autoScaler: false
      awsLoadBalancerController: false
      certManager: false
      cloudWatch: false
      ebs: false
      efs: false
      externalDNS: false
      fsx: false
      imageBuilder: false
      xRay: false
  instanceSelector: {}
  instanceTypes:
  - t3.large
  labels:
    alpha.eksctl.io/cluster-name: EKSDemo
    alpha.eksctl.io/nodegroup-name: DemoNodeGroup
  maxSize: 2
  minSize: 1
  name: DemoNodeGroup
  privateNetworking: false
  releaseVersion: ""
  securityGroups:
    withLocal: null
    withShared: null
  ssh:
    allow: true
    publicKeyPath: ~/.ssh/id_rsa.pub
  tags:
    alpha.eksctl.io/nodegroup-name: DemoNodeGroup
    alpha.eksctl.io/nodegroup-type: managed
  volumeIOPS: 3000
  volumeSize: 80
  volumeThroughput: 125
  volumeType: gp3
metadata:
  name: EKSDemo
  region: ap-east-1
  version: "1.25"
privateCluster:
  enabled: false
  skipEndpointCreation: false
vpc:
  autoAllocateIPv6: false
  cidr: 10.0.0.0/16
  clusterEndpoints:
    privateAccess: false
    publicAccess: true
  manageSharedNodeSecurityGroupRules: true
  nat:
    gateway: Single
EOF
```

- ### check the EKS cluster that created 

you shall see below output from above command 

```
2023-03-31 11:14:02 [ℹ]  eksctl version 0.134.0
2023-03-31 11:14:02 [ℹ]  using region ap-east-1
2023-03-31 11:14:02 [ℹ]  subnets for ap-east-1b - public:10.0.0.0/19 private:10.0.64.0/19
2023-03-31 11:14:02 [ℹ]  subnets for ap-east-1a - public:10.0.32.0/19 private:10.0.96.0/19
2023-03-31 11:14:02 [ℹ]  nodegroup "DemoNodeGroup" will use "" [AmazonLinux2/1.25]
2023-03-31 11:14:02 [ℹ]  using SSH public key "/Users/i/.ssh/id_rsa.pub" as "eksctl-EKSDemo-nodegroup-DemoNodeGroup-51:77:a9:85:2c:84:79:cb:d9:f7:85:34:4c:20:5f:00"
2023-03-31 11:14:03 [ℹ]  using Kubernetes version 1.25
2023-03-31 11:14:03 [ℹ]  creating EKS cluster "EKSDemo" in "ap-east-1" region with managed nodes
2023-03-31 11:14:03 [ℹ]  1 nodegroup (DemoNodeGroup) was included (based on the include/exclude rules)
2023-03-31 11:14:03 [ℹ]  will create a CloudFormation stack for cluster itself and 0 nodegroup stack(s)
2023-03-31 11:14:03 [ℹ]  will create a CloudFormation stack for cluster itself and 1 managed nodegroup stack(s)
2023-03-31 11:14:03 [ℹ]  if you encounter any issues, check CloudFormation console or try 'eksctl utils describe-stacks --region=ap-east-1 --cluster=EKSDemo'
2023-03-31 11:14:03 [ℹ]  Kubernetes API endpoint access will use default of {publicAccess=true, privateAccess=false} for cluster "EKSDemo" in "ap-east-1"
2023-03-31 11:14:03 [ℹ]  CloudWatch logging will not be enabled for cluster "EKSDemo" in "ap-east-1"
2023-03-31 11:14:03 [ℹ]  you can enable it with 'eksctl utils update-cluster-logging --enable-types={SPECIFY-YOUR-LOG-TYPES-HERE (e.g. all)} --region=ap-east-1 --cluster=EKSDemo'
2023-03-31 11:14:03 [ℹ]
2 sequential tasks: { create cluster control plane "EKSDemo",
    2 sequential sub-tasks: {
        wait for control plane to become ready,
        create managed nodegroup "DemoNodeGroup",
    }
}
2023-03-31 11:14:03 [ℹ]  building cluster stack "eksctl-EKSDemo-cluster"
2023-03-31 11:14:04 [ℹ]  deploying stack "eksctl-EKSDemo-cluster"
2023-03-31 11:14:34 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-cluster"
2023-03-31 11:15:04 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-cluster"
2023-03-31 11:16:04 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-cluster"
2023-03-31 11:17:04 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-cluster"
2023-03-31 11:18:05 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-cluster"
2023-03-31 11:19:05 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-cluster"
2023-03-31 11:20:05 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-cluster"
2023-03-31 11:21:06 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-cluster"
2023-03-31 11:22:06 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-cluster"
2023-03-31 11:23:06 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-cluster"
2023-03-31 11:24:07 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-cluster"
2023-03-31 11:26:09 [ℹ]  building managed nodegroup stack "eksctl-EKSDemo-nodegroup-DemoNodeGroup"
2023-03-31 11:26:10 [ℹ]  deploying stack "eksctl-EKSDemo-nodegroup-DemoNodeGroup"
2023-03-31 11:26:10 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-nodegroup-DemoNodeGroup"
2023-03-31 11:26:40 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-nodegroup-DemoNodeGroup"
2023-03-31 11:27:27 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-nodegroup-DemoNodeGroup"
2023-03-31 11:28:52 [ℹ]  waiting for CloudFormation stack "eksctl-EKSDemo-nodegroup-DemoNodeGroup"
2023-03-31 11:28:53 [ℹ]  waiting for the control plane to become ready
2023-03-31 11:28:53 [✔]  saved kubeconfig as "/Users/i/.kube/config"
2023-03-31 11:28:53 [ℹ]  no tasks
2023-03-31 11:28:53 [✔]  all EKS cluster resources for "EKSDemo" have been created
2023-03-31 11:28:53 [ℹ]  nodegroup "DemoNodeGroup" has 1 node(s)
2023-03-31 11:28:53 [ℹ]  node "ip-10-0-29-226.ap-east-1.compute.internal" is ready
2023-03-31 11:28:53 [ℹ]  waiting for at least 1 node(s) to become ready in "DemoNodeGroup"
2023-03-31 11:28:53 [ℹ]  nodegroup "DemoNodeGroup" has 1 node(s)
2023-03-31 11:28:53 [ℹ]  node "ip-10-0-29-226.ap-east-1.compute.internal" is ready
2023-03-31 11:28:54 [ℹ]  kubectl command should work with "/Users/i/.kube/config", try 'kubectl get nodes'
2023-03-31 11:28:54 [✔]  EKS cluster "EKSDemo" in "ap-east-1" region is ready
```


- ### access the eks cluster from your client machine 
once EKS cluster is ready, a kubeconfig will be modified or created on your client machine which enable you to access the remote cluster. 

*you can  use `eksctl utils write-kubeconfig`  to re-config the kubeconfig file to access eks if you mess-up the configuration*

you shall see a kubernetes cluster with 1 node in ready state, "Ready" status indicate that CNI component is also ready. you can use command 
The aws-node DaemonSet manages the AWS VPC CNI plugin for Kubernetes, which is responsible for assigning AWS VPC IP addresses to Kubernetes pods. To view the environment variables and configuration for the aws-node CNI, you can inspect the aws-node DaemonSet.

```
podname=$(kubectl get pods -n kube-system -l k8s-app=aws-node -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')
kubectl -n kube-system get pod $podname -o jsonpath='{.spec.containers[0].env}' | jq .
```
the output will looks like below

```
[
  {
    "name": "ADDITIONAL_ENI_TAGS",
    "value": "{}"
  },
  {
    "name": "AWS_VPC_CNI_NODE_PORT_SUPPORT",
    "value": "true"
  },
  {
    "name": "AWS_VPC_ENI_MTU",
    "value": "9001"
  },
  {
    "name": "AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG",
    "value": "false"
  },
  {
    "name": "AWS_VPC_K8S_CNI_EXTERNALSNAT",
    "value": "false"
  },
  {
    "name": "AWS_VPC_K8S_CNI_LOGLEVEL",
    "value": "DEBUG"
  },
  {
    "name": "AWS_VPC_K8S_CNI_LOG_FILE",
    "value": "/host/var/log/aws-routed-eni/ipamd.log"
  },
  {
    "name": "AWS_VPC_K8S_CNI_RANDOMIZESNAT",
    "value": "prng"
  },
  {
    "name": "AWS_VPC_K8S_CNI_VETHPREFIX",
    "value": "eni"
  },
  {
    "name": "AWS_VPC_K8S_PLUGIN_LOG_FILE",
    "value": "/var/log/aws-routed-eni/plugin.log"
  },
  {
    "name": "AWS_VPC_K8S_PLUGIN_LOG_LEVEL",
    "value": "DEBUG"
  },
  {
    "name": "DISABLE_INTROSPECTION",
    "value": "false"
  },
  {
    "name": "DISABLE_METRICS",
    "value": "false"
  },
  {
    "name": "DISABLE_NETWORK_RESOURCE_PROVISIONING",
    "value": "false"
  },
  {
    "name": "ENABLE_IPv4",
    "value": "true"
  },
  {
    "name": "ENABLE_IPv6",
    "value": "false"
  },
  {
    "name": "ENABLE_POD_ENI",
    "value": "false"
  },
  {
    "name": "ENABLE_PREFIX_DELEGATION",
    "value": "false"
  },
  {
    "name": "WARM_ENI_TARGET",
    "value": "1"
  },
  {
    "name": "WARM_PREFIX_TARGET",
    "value": "1"
  },
  {
    "name": "MY_NODE_NAME",
    "valueFrom": {
      "fieldRef": {
        "apiVersion": "v1",
        "fieldPath": "spec.nodeName"
      }
    }
  }
]
```

by default, there is no pod resource created in default namespace. 
```
kubectl get node -o wide  && kubectl get pod 
```
you shall see output 
```
✗ kubectl get node -o wide
NAME                                       STATUS   ROLES    AGE    VERSION               INTERNAL-IP   EXTERNAL-IP    OS-IMAGE         KERNEL-VERSION                  CONTAINER-RUNTIME
ip-10-0-14-93.ap-east-1.compute.internal   Ready    <none>   163m   v1.25.7-eks-a59e1f0   10.0.14.93    18.167.17.26   Amazon Linux 2   5.10.173-154.642.amzn2.x86_64   containerd://1.6.6
✗ kubectl get pod
No resources found in default namespace.
```

- ## install multus

Amazon EKS supports Multus, a Container Network Interface (CNI) plugin that enables you to attach multiple network interfaces to your Kubernetes pods. This can be useful for workloads requiring additional network isolation or advanced networking features. In this demo. application pod will use additional network to communicate with cFOS. so we will need install multus with additional CNI. 

To use Multus on Amazon EKS, you'll need to install and configure it manually. Here's a high-level overview of the steps:

Create a VPC and configure the required subnets for your EKS cluster.

Deploy an EKS cluster using eksctl or any other method you prefer.

Install the Multus CNI plugin on your EKS cluster. You can find the installation instructions in the official Multus GitHub repository: https://github.com/k8snetworkplumbingwg/multus-cni#quickstart
In this demo, we will use macvlan as secondary CNI for EKS. the macvlan CNI has installed by default on EKS.so we do not need reinstall macvlan.

Configure your CNI plugins. Multus works as a "meta-plugin" that calls other CNI plugins. You'll need to have at least one additional CNI plugin installed and configured. Popular choices include Flannel, Calico, and Weave. You can find a list of CNI plugins here: https://github.com/containernetworking/plugins


- ### clone the code from github 

the repository include multus installation yaml file. it is the standard multus yaml file with 3.9.3 stable release image.
```
git clone https://github.com/yagosys/202301.git 
```


- ### install multus from yaml file 

```
 kubectl create -f 202301/deployment/k8s/multus-daemonset-stable.yml
 ```

- ## check the multus installation 

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


- ## chech the multus cni now become the default cni for EKS on work node
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
- ## Create  multus crd on EKS for application and cfos to attach 

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
- ### check the crd installation

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

- ### install docker secret to pull cfos image from docker repository


use the docker secret file you created in chapter 1 
```
kubectl create -f dockerpullsecret.yaml

```

if you have not created dockerpullsecret yet. you can also create this directly inside the kubernetes with command

```
kubectl create secret docker-registry dockerinterbeing --docker-server https://index.docker.io/v1/ --docker-username=<YOURDOCKERUSERNAME> --docker-password=<YOURDOCKERPASSWORD> --docker-email=<YOURDOCKEMAIL>
```
check the result 
```
➜  eks git:(main) ✗ kubectl create -f dockerpullsecret.yaml
secret/dockerinterbeing created
➜  eks git:(main) ✗ kubectl get secret
NAME               TYPE                             DATA   AGE
dockerinterbeing   kubernetes.io/dockerconfigjson   1      8s
➜  eks git:(main) ✗


```
- ###  create a configmap with cfos license
*cfos require a license to be functional. the license can be configured use cfos cli or use kubernetes configmap*
*cfos will use kubenetes API to read the configmap once cfos start*
*once cFOS container boot up, it will read the configmap to obtain the license*
*cfos license configmap has below format*

use the yaml file you created in chapter 1 
```
kubectl create -f cfos_license.yaml && kubectl get cm fos-license 
```
you shall see output 

```
➜  ✗ kubectl create -f fos_license.yaml && kubectl get cm fos-license
configmap/fos-license created
NAME          DATA   AGE
fos-license   1      0s
```

- ### create role for cfos 

*cfos pod  will need permission to communicate with kubernetes API to read the configmap and also need able to read secret to pull docker image 
so we need assign role with permission to cfos POD based on least priviledge principle*
*below we create ClusterRole to read configmaps and secrets and bind them to default serviceaccount* 
*when we create cfos POD with default serviceaccount, the pod will have permission to read configmap and secret*

copy and paste below code to your client terminal window to create role for cFOS

```
cat << EOF | kubectl create -f - 
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  namespace: default
  name: configmap-reader
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "watch", "list"]

---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-configmaps
  namespace: default
subjects:
- kind: ServiceAccount
  name: default
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: configmap-reader
  apiGroup: ""

---

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
   namespace: default
   name: secrets-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]

---

apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-secrets
  namespace: default
subjects:
- kind: ServiceAccount
  name: default
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: secrets-reader
  apiGroup: ""
EOF
```

you shall see  output like below

```
clusterrole.rbac.authorization.k8s.io/configmap-reader created
rolebinding.rbac.authorization.k8s.io/read-configmaps created
clusterrole.rbac.authorization.k8s.io/secrets-reader created
rolebinding.rbac.authorization.k8s.io/read-secrets created
```

- ### create cfos daemonSet

*we will create cfos as daemonSet, so each node will have single cfos POD*
*cfos will be attached to net-attach-def CRD which created in previous step*
*cfos configured a clusterIP service for restapi port*
*cfos use annotation to attach to crd. the "k8s.v1.cni.cncf.io/networks" means for secondary network, the default interface inside cfos will be net1 by default*
*cfos will have fixed ip "10.1.200.252/32" which is the range of crd cni configuration*
*cfos can also have a fixed mac address*
*the linux capabilities NET_ADMIN, SYS_AMDIN, NET_RAW are required for use ping, sniff and syslog*
*the cfos image will be pulled from docker hub with pull secret*
*the  cfos container mount /data to a directory in host work node, the /data save license, and configuration file etc.,*
*you need to change the line "image: interbeing/fos:v7231x86 to your actual image respository*

copy and paste below code to your terminal window to create cfos DaemonSet
```
cat << EOF | kubectl create -f - 
apiVersion: v1
kind: Service
metadata:
  labels:
    app: fos
  name: fos-deployment
  namespace: default
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: fos
  type: ClusterIP
---

apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fos-deployment
  labels:
      app: fos
spec:
  selector:
    matchLabels:
        app: fos
  template:
    metadata:
      labels:
        app: fos
      annotations:
        k8s.v1.cni.cncf.io/networks: '[ { "name": "cfosdefaultcni5",  "ips": [ "10.1.200.252/32" ], "mac": "CA:FE:C0:FF:00:02" } ]'
    spec:
      containers:
      - name: fos
        image: interbeing/fos:v7231x86
        securityContext:
          capabilities:
              add: ["NET_ADMIN","SYS_ADMIN","NET_RAW"]
        ports:
        - name: isakmp
          containerPort: 500
          protocol: UDP
        - name: ipsec-nat-t
          containerPort: 4500
          protocol: UDP
        volumeMounts:
        - mountPath: /data
          name: data-volume
      imagePullSecrets:
      - name: dockerinterbeing
      volumes:
      - name: data-volume
        hostPath:
          path: /cfosdata
          type: DirectoryOrCreate
EOF
```  
- ### chech the cfos daemonSet deployment


```
kubectl rollout status ds fos-deployment && kubectl get ds fos-deployment && kubectl get pod
```
you shall see 
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

- ### check cfos container log

below you will see that cfos container have sucessfully load the license from configmap and system is ready

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

- ### check the ip address and routing table of cfos container 
below you will see cfos container has eth0 and net1 interface

net1 interface is created by macvlan cni

eth0 interface is created by aws vpc cni

*cfos container have default route point to 169.254.1.1 which has fixed mac address from veth pair interface on the host side (enixxx interface on host)*

paste below command to check cfos ip address 

```
cfospodname=$(kubectl get pod -l app=fos -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it po/$cfospodname -- ip a
```

the output shall like below. you will expect see different ip address on eth0. but the net1 ip address shall be 10.1.200.252. 

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
3: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP group default
    link/ether 7e:55:44:3d:62:fa brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.19.107/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::7c55:44ff:fe3d:62fa/64 scope link
       valid_lft forever preferred_lft forever
4: net1@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP group default
    link/ether 8e:2c:2a:6b:90:49 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.1.200.252/24 brd 10.1.200.255 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::8c2c:2aff:fe6b:9049/64 scope link
       valid_lft forever preferred_lft forever

```
paste below command to check ip routing table 

```
cfospodname=$(kubectl get pod -l app=fos -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it po/$cfospodname -- ip route
```

the output will be 
```
default via 169.254.1.1 dev eth0
10.1.200.0/24 dev net1 proto kernel scope link src 10.1.200.252
169.254.1.1 dev eth0 scope link
```

- ### check cfos POD description
*the serviceAccount is default which granted read configmap and secret in previous step*
*the annotations usr k8s.v1.cni.cncf.io/networks to tell CRD to assign IP for it*
*in the events log, the interface eth0 and net1 are from multus which means multus is the default CNI for eks*
*multus delegate to aws-cni for eth0 interface, multus delegate to macvlan cni for net1 interface*

```
cfospodname=$(kubectl get pod -l app=fos -o jsonpath='{.items[0].metadata.name}')
kubectl describe po/$cfospodname
```

the output shall looks like below 
```
Name:             fos-deployment-x8vzj
Namespace:        default
Priority:         0
Service Account:  default
Node:             ip-10-0-29-226.ap-east-1.compute.internal/10.0.29.226
Start Time:       Fri, 31 Mar 2023 13:36:55 +0800
Labels:           app=fos
                  controller-revision-hash=6555fcd587
                  pod-template-generation=1
Annotations:      k8s.v1.cni.cncf.io/network-status:
                    [{
                        "name": "aws-cni",
                        "interface": "dummydb68da92e6e",
                        "ips": [
                            "10.0.19.107"
                        ],
                        "mac": "0",
                        "default": true,
                        "dns": {}
                    },{
                        "name": "default/cfosdefaultcni5",
                        "interface": "net1",
                        "ips": [
                            "10.1.200.252"
                        ],
                        "mac": "8e:2c:2a:6b:90:49",
                        "dns": {}
                    }]
                  k8s.v1.cni.cncf.io/networks: [ { "name": "cfosdefaultcni5",  "ips": [ "10.1.200.252/32" ], "mac": "CA:FE:C0:FF:00:02" } ]
                  k8s.v1.cni.cncf.io/networks-status:
                    [{
                        "name": "aws-cni",
                        "interface": "dummydb68da92e6e",
                        "ips": [
                            "10.0.19.107"
                        ],
                        "mac": "0",
                        "default": true,
                        "dns": {}
                    },{
                        "name": "default/cfosdefaultcni5",
                        "interface": "net1",
                        "ips": [
                            "10.1.200.252"
                        ],
                        "mac": "8e:2c:2a:6b:90:49",
                        "dns": {}
                    }]
Status:           Running
IP:               10.0.19.107
IPs:
  IP:           10.0.19.107
Controlled By:  DaemonSet/fos-deployment
Containers:
  fos:
    Container ID:   containerd://b12c9e732116597d37e70ee61cbc6fc3ec390597280eecb97ed29a482bdef083
    Image:          interbeing/fos:v7231x86
    Image ID:       docker.io/interbeing/fos@sha256:96b734cf66dcf81fc5f9158e66676ee09edb7f3b0f309c442b48ece475b42e6c
    Ports:          500/UDP, 4500/UDP
    Host Ports:     0/UDP, 0/UDP
    State:          Running
      Started:      Fri, 31 Mar 2023 13:37:02 +0800
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /data from data-volume (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-xxs26 (ro)
Conditions:
  Type              Status
  Initialized       True
  Ready             True
  ContainersReady   True
  PodScheduled      True
Volumes:
  data-volume:
    Type:          HostPath (bare host directory volume)
    Path:          /cfosdata
    HostPathType:  DirectoryOrCreate
  kube-api-access-xxs26:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/disk-pressure:NoSchedule op=Exists
                             node.kubernetes.io/memory-pressure:NoSchedule op=Exists
                             node.kubernetes.io/not-ready:NoExecute op=Exists
                             node.kubernetes.io/pid-pressure:NoSchedule op=Exists
                             node.kubernetes.io/unreachable:NoExecute op=Exists
                             node.kubernetes.io/unschedulable:NoSchedule op=Exists
Events:
  Type    Reason          Age   From               Message
  ----    ------          ----  ----               -------
  Normal  Scheduled       14m   default-scheduler  Successfully assigned default/fos-deployment-x8vzj to ip-10-0-29-226.ap-east-1.compute.internal
  Normal  AddedInterface  14m   multus             Add eth0 [10.0.19.107/32] from aws-cni
  Normal  AddedInterface  14m   multus             Add net1 [10.1.200.252/24] from default/cfosdefaultcni5
  Normal  Pulling         14m   kubelet            Pulling image "interbeing/fos:v7231x86"
  Normal  Pulled          14m   kubelet            Successfully pulled image "interbeing/fos:v7231x86" in 5.773955482s (5.77396476s including waiting)
  Normal  Created         14m   kubelet            Created container fos
  Normal  Started         14m   kubelet            Started container fos
```



- ### check cfos configuration use cfos cli
*at this moment, cfos has no configuration but a license*
*use fcnsh enter cfos shell*
*use sysctl sh go back to sh*

```
cfospodname=$(kubectl get pod -l app=fos -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it po/$cfospodname -- sh
``` 
you will be dropped into the shell. then type  `fcnsh` to enter cFOS shell
```
fcnsh
```
you will see  cFOS cli interface, where you can use fortiOS cli 

```
FOS Container # show firewall policy
config firewall policy
end

FOS Container # show firewall addrgrp
config firewall addrgrp
end
FOS Container # sysctl sh
#
``` 

you can use `sysctl sh` command back to cFOS container linux shell

```
FOS Container # sysctl sh
# exit
```

- ### create demo application deployment 

the replicas=4 mean it will create 4 POD on this work node

annotations k8s.v1.cni.cncf.io/networks to tell CRD to attach the pod to network cfosdefaultcni5 with net1 interface

the POD will get default-route 10.1.200.252 which is the ip of cfos on net1 interface

the net1 interface use network cfosdefaultcni5 to communicate with cfos net1

*the POD need to install a route for 10.0.0.0/16 subnet with nexthop to 169.254.1.1, as these traffic do not want goes to cfos, if remove this route, pod to pod communication will be send to cFOS as well*


copy and paste below script on your client terminal to create application deployment, we label the pod will label app=multitool01

```
cat << EOF | kubectl create -f -  
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multitool01-deployment
  labels:
      app: multitool01
spec:
  replicas: 4
  selector:
    matchLabels:
        app: multitool01
  template:
    metadata:
      labels:
        app: multitool01
      annotations:
        k8s.v1.cni.cncf.io/networks: '[ { "name": "cfosdefaultcni5",  "default-route": ["10.1.200.252"]  } ]'
    spec:
      containers:
        - name: multitool01
          image: praqma/network-multitool
          imagePullPolicy: Always
          args:
            - /bin/sh
            - -c
            - ip route add 10.0.0.0/16  via 169.254.1.1; /usr/sbin/nginx -g "daemon off;"
          securityContext:
            privileged: true
EOF
```
- ### check the deployment result 

```
kubectl rollout status deployment multitool01-deployment
```
you shall see 
```
✗ kubectl rollout status deployment multitool01-deployment
Waiting for deployment "multitool01-deployment" rollout to finish: 0 of 4 updated replicas are available...
Waiting for deployment "multitool01-deployment" rollout to finish: 1 of 4 updated replicas are available...
Waiting for deployment "multitool01-deployment" rollout to finish: 2 of 4 updated replicas are available...
Waiting for deployment "multitool01-deployment" rollout to finish: 3 of 4 updated replicas are available...
deployment "multitool01-deployment" successfully rolled out
```
check the pod status 
```
kubectl get pod -l app=multitool01
```
you shall see 
```
NAME                                     READY   STATUS    RESTARTS   AGE
multitool01-deployment-88ff6b48c-d2drz   1/1     Running   0          33s
multitool01-deployment-88ff6b48c-klx2z   1/1     Running   0          33s
multitool01-deployment-88ff6b48c-pzssg   1/1     Running   0          33s
multitool01-deployment-88ff6b48c-t97t6   1/1     Running   0          33s
```

- ### create another deployment with different label
we want demo to support multiple application based on the different label. so we create one more deployment with different label.
paste below script to create another deployment, we assign label to pod app=newtest 
in this deployment, we use initContainers to insert a route for this POD.  this route is telling for POD to POD traffic from eth0. not goes to cFOS. but continue to use aws VPC CNI created cluster network. 

```
cat << EOF | kubectl create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: testtest-deployment
  labels:
      app: newtest
spec:
  replicas: 2
  selector:
    matchLabels:
        app: newtest
  template:
    metadata:
      labels:
        app: newtest
      annotations:
        k8s.v1.cni.cncf.io/networks: '[ { "name": "cfosdefaultcni5",  "default-route": ["10.1.200.252"]  } ]'
    spec:
      initContainers:
      - name: init-wait
        image: alpine
        command: ["sh", "-c", "ip route add 10.0.0.0/16 via 169.254.1.1"]
        securityContext:
          capabilities:
            add: ["NET_ADMIN"]
      containers:
        - name: newtest
          image: praqma/network-multitool
          imagePullPolicy: Always
          securityContext:
            privileged: true
EOF

```
use `kubectl get pod -l app=newtest` to check the pod `

```
➜  ✗ kubectl  get pod -l app=newtest
NAME                                   READY   STATUS    RESTARTS   AGE
testtest-deployment-5768f678d7-76krs   1/1     Running   0          28s
testtest-deployment-5768f678d7-ng92z   1/1     Running   0          28s
```

- ### create a clientpod to manage the networkpolicy and update pod ip address to cfos 

we create a pod with name clientpod to create firewall policy for cFOS and it will also keep POD IP address in sync between cFOS and kubernetes.
as POD ip address is not fixed. the IP address will change due to scale , restart etc . we will keep the the POP ip address in sync with cFOS addressgroup.
basically, this clientpod will  

create firewall policy for two deployment which has annotations to use cfosdefaultcni5 netwok

update application pod ip address to cfos addressgroup.

privode pod address update for the firewall policy that created by gatekeeper, if the policy already created by gatekeeper then, it will only update the POD ip address to cFOS addreegroup.

this pod use image which is build use docker build . you can use Dockerfile to build image and modify the script

this pod also monitor the node number change, if work node increased or decreased ,it will restart cfos DaemonSet.


copy and paste below script to your terminal window to create clientpod. this clientpod is mainly use kubectl client to obtain the POD ip address with label and namespace, then use curl to update the cFOS addressgroup to keep the ip address in cFOS to sync with application POD in kubernetes. I have already build the image for this clientpod and put it on dockerhub. so we can directly create POD with that image. 

```
cat << EOF | kubectl create -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-reader
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list", "get", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["list","get","watch","create"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list", "get", "watch"]
- apiGroups: ["apps"]
  resources: ["daemonsets"]
  verbs: ["get", "list", "watch", "patch", "update"]
- apiGroups: ["constraints.gatekeeper.sh"]
  resources: ["k8segressnetworkpolicytocfosutmpolicy"]
  verbs: ["list","get","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pod-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pod-reader
subjects:
- kind: ServiceAccount
  name: pod-reader
  namespace: default
---
apiVersion: v1
kind: Pod
metadata:
  name: clientpod
spec:
  serviceAccountName: pod-reader
  containers:
  - name: kubectl-container
    image: interbeing/kubectl-cfos:latest
EOF
```
- ### check both deployment now shall able to access internet via cfos 

```
kubectl get pod | grep multi | grep -v termin  | awk '{print $1}'  | while read line; do kubectl exec -t po/$line -- ping -c1 1.1.1.1 ; done
```
you will see that each pod will able to ping 1.1.1.1 

```
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=51 time=1.09 ms

--- 1.1.1.1 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 1.092/1.092/1.092/0.000 ms
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=51 time=1.04 ms

--- 1.1.1.1 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 1.035/1.035/1.035/0.000 ms
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=51 time=0.959 ms

--- 1.1.1.1 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.959/0.959/0.959/0.000 ms
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=51 time=1.16 ms

--- 1.1.1.1 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 1.156/1.156/1.156/0.000 ms

```
for other pod with label app=newtest , it also able to ping 1.1.1.1
```
kubectl get pod | grep testtest | grep -v termin  | awk '{print $1}'  | while read line; do kubectl exec -t po/$line -- ping -c1 1.1.1.1 ; done
```
ping result
```
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=51 time=0.987 ms

--- 1.1.1.1 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.987/0.987/0.987/0.000 ms
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=51 time=1.05 ms

--- 1.1.1.1 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 1.054/1.054/1.054/0.000 ms

```

- ## check cfos firewall addressgroup
*the firewall addrgrp has each POD IP in the group*

```
cfospod=$(kubectl get pod | grep fos | awk '{print $1}')
kubectl exec -it po/$cfospod -- fcnsh
```
use `show firewall addrgrp` will show that the address group include all POD ip address

```
FOS Container # show firewall addrgrp
config firewall addrgrp
    edit "defaultappmultitool"
        set member 10.1.200.21 10.1.200.22 10.1.200.253 10.1.200.20
    next
    edit "defaultappnewtest"
        set member 10.1.200.24 10.1.200.23
    next
end
```

- ## check cfos firewall policy
```
FOS Container # show firewall policy
config firewall policy
    edit "101"
        set utm-status enable
        set name "corptraffic101"
        set srcintf any
        set dstintf eth0
        set srcaddr defaultappmultitool
        set dstaddr all
        set service ALL
        set ssl-ssh-profile "deep-inspection"
        set av-profile "default"
        set webfilter-profile "default"
        set ips-sensor "default"
        set nat enable
        set logtraffic all
    next
    edit "102"
        set utm-status enable
        set name "corptraffic102"
        set srcintf any
        set dstintf eth0
        set srcaddr defaultappnewtest
        set dstaddr all
        set service ALL
        set ssl-ssh-profile "deep-inspection"
        set av-profile "default"
        set webfilter-profile "default"
        set ips-sensor "default"
        set nat enable
        set logtraffic all
    next
end

```
- ### verify whether cFOS is in health state 

the cFOS might running to into some SSL related issue which is tobefixed, if that happen, use below script to fix it 
```
#!/bin/bash

# Get list of node names
node_list=$(kubectl get nodes -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

function deletepod {
for nodeName in $node_list; do
	echo $1
     while true ; do
        kubectl rollout status deployment multitool01-deployment
        cfospod=`kubectl get pods -l app=fos --field-selector spec.nodeName=$nodeName |    cut -d ' ' -f 1 | tail -n -1`
        multpod=`kubectl get pods -l app=$1 --field-selector spec.nodeName=$nodeName |   cut -d ' ' -f 1 | tail -n -1`
        result=$(kubectl exec -it po/$multpod -- curl -k  https://1.1.1.1 2>&1 | grep -o 'decryption failed or bad record mac')
        if [ "$result" = "decryption failed or bad record mac" ]
        then
        echo "cfos is not ready, delete cfos pod"
        kubectl delete po/$cfospod
        else
                echo " on $nodeName cfos is ready"
                break

        fi
     done
done
}

deletepod "multitool01"
deletepod "newtest"

```
- ### demo cfos l7 security feature -Web Filter feature 
use below script to access eicar to simulate access malicous website from two deployment 
```
 kubectl get pod | grep multi | grep -v termin | awk '{print $1}'  | while read line; do kubectl exec -t po/$line --  curl -k -I  https://www.eicar.org/download/eicar.com.txt  ; done
 kubectl get pod -l app=newtest | grep "Running" | awk '{print $1}' | while read line; do kubectl exec -t po/$line --  curl -k -I  https://www.eicar.org/download/eicar.com.txt  ; done
```
you will see that cFOS will block it  with 403 Forrbidden

```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:01 --:--:--     0HTTP/1.1 403 Forbidden
X-Frame-Options: SAMEORIGIN
X-XSS-Protection: 1; mode=block
X-Content-Type-Options: nosniff
Content-Security-Policy: frame-ancestors 'self'
Content-Type: text/html; charset="utf-8"
Content-Length: 5211
Connection: Close
```
- ### check the webfilter log on cFOS
```
kubectl get pod | grep fos | awk '{print $1}'  | while read line; do kubectl exec -t po/$line -- tail  /data/var/log/log/webf.0  ; done
```
you shall see 
```
➜  eks git:(main) ✗ kubectl get pod | grep fos | awk '{print $1}'  | while read line; do kubectl exec -t po/$line -- tail  /data/var/log/log/webf.0  ; done
date=2023-04-03 time=07:33:53 eventtime=1680507233 tz="+0000" logid="0316013056" type="utm" subtype="webfilter" eventtype="ftgd_blk" level="warning" policyid=101 sessionid=13 srcip=10.1.200.22 srcport=34874 srcintf="net1" dstip=89.238.73.97 dstport=443 dstintf="eth0" proto=6 service="HTTPS" hostname="www.eicar.org" profile="default" action="blocked" reqtype="direct" url="https://www.eicar.org/download/eicar.com.txt" sentbyte=100 rcvdbyte=0 direction="outgoing" msg="URL belongs to a denied category in policy" method="domain" cat=26 catdesc="Malicious Websites"
date=2023-04-03 time=07:33:54 eventtime=1680507234 tz="+0000" logid="0316013056" type="utm" subtype="webfilter" eventtype="ftgd_blk" level="warning" policyid=101 sessionid=20 srcip=10.1.200.21 srcport=34996 srcintf="net1" dstip=89.238.73.97 dstport=443 dstintf="eth0" proto=6 service="HTTPS" hostname="www.eicar.org" profile="default" action="blocked" reqtype="direct" url="https://www.eicar.org/download/eicar.com.txt" sentbyte=100 rcvdbyte=0 direction="outgoing" msg="URL belongs to a denied category in policy" method="domain" cat=26 catdesc="Malicious Websites"
date=2023-04-03 time=07:33:55 eventtime=1680507235 tz="+0000" logid="0316013056" type="utm" subtype="webfilter" eventtype="ftgd_blk" level="warning" policyid=102 sessionid=27 srcip=10.1.200.24 srcport=36178 srcintf="net1" dstip=89.238.73.97 dstport=443 dstintf="eth0" proto=6 service="HTTPS" hostname="www.eicar.org" profile="default" action="blocked" reqtype="direct" url="https://www.eicar.org/download/eicar.com.txt" sentbyte=100 rcvdbyte=0 direction="outgoing" msg="URL belongs to a denied category in policy" method="domain" cat=26 catdesc="Malicious Websites"
date=2023-04-03 time=07:33:57 eventtime=1680507237 tz="+0000" logid="0316013056" type="utm" subtype="webfilter" eventtype="ftgd_blk" level="warning" policyid=102 sessionid=22 srcip=10.1.200.23 srcport=43088 srcintf="net1" dstip=89.238.73.97 dstport=443 dstintf="eth0" proto=6 service="HTTPS" hostname="www.eicar.org" profile="default" action="blocked" reqtype="direct" url="https://www.eicar.org/download/eicar.com.txt" sentbyte=100 rcvdbyte=0 direction="outgoing" msg="URL belongs to a denied category in policy" method="domain" cat=26 catdesc="Malicious Websites"
date=2023-04-03 time=07:35:43 eventtime=1680507343 tz="+0000" logid="0316013056" type="utm" subtype="webfilter" eventtype="ftgd_blk" level="warning" policyid=101 sessionid=31 srcip=10.1.200.253 srcport=34944 srcintf="net1" dstip=89.238.73.97 dstport=443 dstintf="eth0" proto=6 service="HTTPS" hostname="www.eicar.org" profile="default" action="blocked" reqtype="direct" url="https://www.eicar.org/download/eicar.com.txt" sentbyte=100 rcvdbyte=0 direction="outgoing" msg="URL belongs to a denied category in policy" method="domain" cat=26 catdesc="Malicious Websites"
date=2023-04-03 time=07:35:44 eventtime=1680507344 tz="+0000" logid="0316013056" type="utm" subtype="webfilter" eventtype="ftgd_blk" level="warning" policyid=101 sessionid=38 srcip=10.1.200.20 srcport=57046 srcintf="net1" dstip=89.238.73.97 dstport=443 dstintf="eth0" proto=6 service="HTTPS" hostname="www.eicar.org" profile="default" action="blocked" reqtype="direct" url="https://www.eicar.org/download/eicar.com.txt" sentbyte=100 rcvdbyte=0 direction="outgoing" msg="URL belongs to a denied category in policy" method="domain" cat=26 catdesc="Malicious Websites"
date=2023-04-03 time=07:35:45 eventtime=1680507345 tz="+0000" logid="0316013056" type="utm" subtype="webfilter" eventtype="ftgd_blk" level="warning" policyid=101 sessionid=40 srcip=10.1.200.22 srcport=44146 srcintf="net1" dstip=89.238.73.97 dstport=443 dstintf="eth0" proto=6 service="HTTPS" hostname="www.eicar.org" profile="default" action="blocked" reqtype="direct" url="https://www.eicar.org/download/eicar.com.txt" sentbyte=100 rcvdbyte=0 direction="outgoing" msg="URL belongs to a denied category in policy" method="domain" cat=26 catdesc="Malicious Websites"
date=2023-04-03 time=07:35:47 eventtime=1680507347 tz="+0000" logid="0316013056" type="utm" subtype="webfilter" eventtype="ftgd_blk" level="warning" policyid=101 sessionid=47 srcip=10.1.200.21 srcport=46250 srcintf="net1" dstip=89.238.73.97 dstport=443 dstintf="eth0" proto=6 service="HTTPS" hostname="www.eicar.org" profile="default" action="blocked" reqtype="direct" url="https://www.eicar.org/download/eicar.com.txt" sentbyte=100 rcvdbyte=0 direction="outgoing" msg="URL belongs to a denied category in policy" method="domain" cat=26 catdesc="Malicious Websites"
date=2023-04-03 time=07:35:48 eventtime=1680507348 tz="+0000" logid="0316013056" type="utm" subtype="webfilter" eventtype="ftgd_blk" level="warning" policyid=102 sessionid=54 srcip=10.1.200.24 srcport=43528 srcintf="net1" dstip=89.238.73.97 dstport=443 dstintf="eth0" proto=6 service="HTTPS" hostname="www.eicar.org" profile="default" action="blocked" reqtype="direct" url="https://www.eicar.org/download/eicar.com.txt" sentbyte=100 rcvdbyte=0 direction="outgoing" msg="URL belongs to a denied category in policy" method="domain" cat=26 catdesc="Malicious Websites"
date=2023-04-03 time=07:35:49 eventtime=1680507349 tz="+0000" logid="0316013056" type="utm" subtype="webfilter" eventtype="ftgd_blk" level="warning" policyid=102 sessionid=41 srcip=10.1.200.23 srcport=36760 srcintf="net1" dstip=89.238.73.97 dstport=443 dstintf="eth0" proto=6 service="HTTPS" hostname="www.eicar.org" profile="default" action="blocked" reqtype="direct" url="https://www.eicar.org/download/eicar.com.txt" sentbyte=100 rcvdbyte=0 direction="outgoing" msg="URL belongs to a denied category in policy" method="domain" cat=26 catdesc="Malicious Websites"
```

- ### scale the app deployment 
let's scale replicas from 2 to 4 for testtest-deployment which has pod label app=newtest, the firewall addrgroup name is created by clientpod 
by combine the namespace and label which is defaultappnewtest. 
```
kubectl scale deployment testtest-deployment --replicas=4 &&
kubectl get pod -l app=newtest
```
you shall see output 
```
deployment.apps/testtest-deployment scaled
NAME                                   READY   STATUS    RESTARTS   AGE
testtest-deployment-5768f678d7-4b4wf   1/1     Running   0          110s
testtest-deployment-5768f678d7-8m52w   1/1     Running   0          12m
testtest-deployment-5768f678d7-nxlvq   1/1     Running   0          110s
testtest-deployment-5768f678d7-vdmv5   1/1     Running   0          12m
```
you can use below cli command to check the ip address for each pod on net1 interface 

```
kubectl get pod | grep testtest | awk '{print $1}'  | while read line; do kubectl  exec po/$line -- ip -4 --br a show dev net1; done
```
the output will be 

```
net1@if2         UP             10.1.200.25/24
net1@if2         UP             10.1.200.24/24
net1@if2         UP             10.1.200.23/24
net1@if2         UP             10.1.200.26/24
```

- ### check cfos firewall addressgroup has also updated 
*the addressgroup defaultappnewtest now have 4 member pod ip*

```
cfospod=$(kubectl get pod | grep fos | awk '{print $1}')
kubectl exec -it po/$cfospod -- fcnsh
```
use `show firewall addrgrp` to check the address members 
```
FOS Container # show firewall addrgrp
config firewall addrgrp
    edit "defaultappmultitool"
        set member 10.1.200.21 10.1.200.22 10.1.200.253 10.1.200.20
    next
    edit "defaultappnewtest"
        set member 10.1.200.25 10.1.200.24 10.1.200.26 10.1.200.23
    next
end
```


- ### use eksctl to scale nodes
we scale the node to 2 nodes. aws will use autoscalling group to luanch new work node and join kubernetes cluster. it will take sometime. 


```
eksctl scale nodegroup DemoNodeGroup --cluster EKSDemo -N 2 -M 2 --region ap-east-1 && kubectl get node

```
you will see output 

```
➜  ✗ eksctl scale nodegroup DemoNodeGroup --cluster EKSDemo -N 2 -M 2 --region ap-east-1 && kubectl get node
2023-03-31 14:51:51 [ℹ]  scaling nodegroup "DemoNodeGroup" in cluster EKSDemo
2023-03-31 14:51:53 [ℹ]  waiting for scaling of nodegroup "DemoNodeGroup" to complete
2023-03-31 14:52:23 [ℹ]  nodegroup successfully scaled
➜  ✗ kubectl get node
NAME                                        STATUS   ROLES    AGE     VERSION
ip-10-0-29-226.ap-east-1.compute.internal   Ready    <none>   3h25m   v1.25.7-eks-a59e1f0
ip-10-0-39-35.ap-east-1.compute.internal    Ready    <none>   31s     v1.25.7-eks-a59e1f0

```

- ### check new cfos DaemonSet on new work node

```
kubectl rollout status ds/fos-deployment && kubectl get pod -l app=fos -o wide
```
you will see another cfos POD will be created on new work node 

```
kubectl rollout status ds/fos-deployment && kubectl get pod -l app=fos -o wide
daemon set "fos-deployment" successfully rolled out
NAME                   READY   STATUS    RESTARTS   AGE     IP           NODE                         NOMINATED NODE   READINESS GATES
fos-deployment-62pfv   1/1     Running   0          8m51s   10.0.58.80   ip-10-0-29-226.ec2.internal   <none>           <none>
fos-deployment-hhw9z   1/1     Running   0          8m19s   10.0.3.3     ip-10-0-39-35.ec2.internal   <none>           <none>

```

- ### scale out application to use new node 

```
kubectl scale deployment multitool01-deployment --replicas=8 && kubectl get pod -l app=multitool01 
```

we can scale out the deployment so some of the new pod will be scahedule to new work node. the output will like below eventualy 

```
deployment.apps/multitool01-deployment scaled

✗ kubectl get pod -l app=multitool01
NAME                                     READY   STATUS    RESTARTS   AGE
multitool01-deployment-88ff6b48c-d2drz   1/1     Running   0          51m
multitool01-deployment-88ff6b48c-ggr46   1/1     Running   0          22s
multitool01-deployment-88ff6b48c-klx2z   1/1     Running   0          51m
multitool01-deployment-88ff6b48c-p8w46   1/1     Running   0          22s
multitool01-deployment-88ff6b48c-pzssg   1/1     Running   0          51m
multitool01-deployment-88ff6b48c-r5thd   1/1     Running   0          22s
multitool01-deployment-88ff6b48c-t7zqp   1/1     Running   0          22s
multitool01-deployment-88ff6b48c-t97t6   1/1     Running   0          51m
✗ kubectl get pod -l app=multitool01 -o wide
NAME                                     READY   STATUS    RESTARTS   AGE   IP            NODE                                        NOMINATED NODE   READINESS GATES
multitool01-deployment-88ff6b48c-d2drz   1/1     Running   0          51m   10.0.9.6      ip-10-0-29-226.ap-east-1.compute.internal   <none>           <none>
multitool01-deployment-88ff6b48c-ggr46   1/1     Running   0          26s   10.0.46.50    ip-10-0-39-35.ap-east-1.compute.internal    <none>           <none>
multitool01-deployment-88ff6b48c-klx2z   1/1     Running   0          51m   10.0.30.9     ip-10-0-29-226.ap-east-1.compute.internal   <none>           <none>
multitool01-deployment-88ff6b48c-p8w46   1/1     Running   0          26s   10.0.35.118   ip-10-0-39-35.ap-east-1.compute.internal    <none>           <none>
multitool01-deployment-88ff6b48c-pzssg   1/1     Running   0          51m   10.0.22.96    ip-10-0-29-226.ap-east-1.compute.internal   <none>           <none>
multitool01-deployment-88ff6b48c-r5thd   1/1     Running   0          26s   10.0.46.178   ip-10-0-39-35.ap-east-1.compute.internal    <none>           <none>
multitool01-deployment-88ff6b48c-t7zqp   1/1     Running   0          26s   10.0.63.68    ip-10-0-39-35.ap-east-1.compute.internal    <none>           <none>
multitool01-deployment-88ff6b48c-t97t6   1/1     Running   0          51m   10.0.31.97    ip-10-0-29-226.ap-east-1.compute.internal   <none>           <none>
```

- ### test whether all these POD can access internet via cFOS 
```
kubectl get pod | grep multi | grep -v termin  | awk '{print $1}'  | while read line; do kubectl exec -t po/$line -- ping -c1 1.1.1.1 ; done
kubectl get pod | grep testtest | grep -v termin  | awk '{print $1}'  | while read line; do kubectl exec -t po/$line -- ping -c1 1.1.1.1 ; done
```

- ## use kubernetes network policy to create firewallpolicy on cFOS

the idea is use gatekeeper with opa policy to review the networkpolicy , if the networkpolicy meet the constraintTemplate. the contraintTemplate will use cFOS restful API to create a firewall policy on cFOS. 

- ### delete existing firewall policy and clientpod 

use eksctl to reduce the node to 1.  we will use restful API DNS name to config firewall policy on cFOS. unless all nodes use shared data storage like NFS. otherwise we have to reduce the number of nodes to 1. to make sure the restful API call sucess. 

```
eksctl scale nodegroup DemoNodeGroup --cluster EKSDemo -N 1 -M 2 --region ap-east-1 && kubectl get node
```

delete the clientpod

```
kubectl delete po/clientpod
```

delete cFOS firewall policy on cFOS manually , so you do not have any firewall policy on cFOS


- ### install gatekeeperv3

```
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
```
you shall see 
```
namespace/gatekeeper-system created
resourcequota/gatekeeper-critical-pods created
customresourcedefinition.apiextensions.k8s.io/assign.mutations.gatekeeper.sh created
customresourcedefinition.apiextensions.k8s.io/assignmetadata.mutations.gatekeeper.sh created
customresourcedefinition.apiextensions.k8s.io/configs.config.gatekeeper.sh created
customresourcedefinition.apiextensions.k8s.io/constraintpodstatuses.status.gatekeeper.sh created
customresourcedefinition.apiextensions.k8s.io/constrainttemplatepodstatuses.status.gatekeeper.sh created
customresourcedefinition.apiextensions.k8s.io/constrainttemplates.templates.gatekeeper.sh created
customresourcedefinition.apiextensions.k8s.io/expansiontemplate.expansion.gatekeeper.sh created
customresourcedefinition.apiextensions.k8s.io/modifyset.mutations.gatekeeper.sh created
customresourcedefinition.apiextensions.k8s.io/mutatorpodstatuses.status.gatekeeper.sh created
customresourcedefinition.apiextensions.k8s.io/providers.externaldata.gatekeeper.sh created
serviceaccount/gatekeeper-admin created
role.rbac.authorization.k8s.io/gatekeeper-manager-role created
clusterrole.rbac.authorization.k8s.io/gatekeeper-manager-role created
rolebinding.rbac.authorization.k8s.io/gatekeeper-manager-rolebinding created
clusterrolebinding.rbac.authorization.k8s.io/gatekeeper-manager-rolebinding created
secret/gatekeeper-webhook-server-cert created
service/gatekeeper-webhook-service created
deployment.apps/gatekeeper-audit created
deployment.apps/gatekeeper-controller-manager created
poddisruptionbudget.policy/gatekeeper-controller-manager created
mutatingwebhookconfiguration.admissionregistration.k8s.io/gatekeeper-mutating-webhook-configuration created
validatingwebhookconfiguration.admissionregistration.k8s.io/gatekeeper-validating-webhook-configuration created
```
wait until it ready
```
kubectl rollout status deployment/gatekeeper-audit -n gatekeeper-system && 
kubectl rollout status deployment/gatekeeper-controller-manager  -n gatekeeper-system
```

- ### deploy constraintTemplate

A ConstraintTemplate is a custom resource definition (CRD) used by the Gatekeeper project in Kubernetes. Gatekeeper is an open-source project that extends the Open Policy Agent (OPA) to provide policy enforcement and validation for Kubernetes clusters. 
We use this CRD to validate the networkpolicy from gatekeeper admission controller. the ConstraintTemplate include Targets section which use rego to validate the rule.
in our example. the target will call cFOS restful API to create firewall policy if condition met. otherwise, the network policy request will be send to kubernetes for creation. 

paste below to create ContraintTemplate

```
cat << EOF | kubectl create -f -
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8segressnetworkpolicytocfosutmpolicy
spec:
  crd:
    spec:
      names:
        kind: K8sEgressNetworkPolicyToCfosUtmPolicy
      validation:
        openAPIV3Schema:
          properties:
            message:
              type: string
            podcidr:
              type: string
            cfosegressfirewallpolicy:
              type: string 
            outgoingport:
              type: string
            utmstatus:
              type: string
            ipsprofile:
              type: string
            avprofile:
              type: string
            sslsshprofile:
              type: string 
            action:
              type: string
            srcintf:
              type: string
            firewalladdressapiurl:
              type: string
            firewallpolicyapiurl:
              type: string
            policyid :
              type: string 
            extraservice:
              type: string 

  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8segressnetworkpolicytocfosutmpolicy
        import future.keywords.if
        import future.keywords.in
        import future.keywords.contains
        
        
        services := {
        "HTTP": ["TCP:80"],
        "HTTPS": ["TCP:443"],
        "DNS": ["UDP:53"]
        }

        get_service(cfosservice) := msg1 {
          protocol := input.review.object.spec.egress[_].ports[_].protocol 
          port := sprintf("%v",[input.review.object.spec.egress[_].ports[_].port])
          key := concat(":", [ protocol, port ])
          some service; services[service][_] == key
          test := { service }
          cfosservice in test
          msg1 := cfosservice
         }

        myservice[{
           "name" : get_service("HTTPS")
          }] {
               1==1
         }
        myservice[{
           "name" : get_service("HTTP")
          }] {
               1==1
         }
        myservice[{
           "name" : get_service("DNS")
          }] {
               1==1
         }

         myservice[{"name":msg1}] {
         input.parameters.extraservice=="PING"
         msg1:="PING"
         }



          violation[{
            "msg" : msg 
          }] {
                          

                          
                          #the NetworkPolicy must has label under metadata which match the constraint
                          input.review.object.metadata.labels.app==input.parameters.label
                          
                          
                          #GET INPUT from reguar NetworkPolicy for cfos firewall policy
                          namespace := input.review.object.metadata.namespace
                          label := input.review.object.spec.podSelector.matchLabels.app
                             t := concat("",[namespace,"app"])
                          src_addr_group := concat("",[t,label])
                          dstipblock :=  input.review.object.spec.egress[_].to[_].ipBlock.cidr
                          policyname := input.review.object.metadata.name
                          
                          #GET INPUT from constraint template
                          policyid := input.parameters.policyid 
                          ipsprofile := input.parameters.ipsprofile
                          avprofile := input.parameters.avprofile
                          sslsshprofile := input.parameters.sslsshprofile
                          action  := input.parameters.action
                          srcintf := input.parameters.srcintf   
                          utmstatus := input.parameters.utmstatus
                          outgoingport := input.parameters.outgoingport
                          
                          
                          #firewalladdressapiurl := input.parameters.firewalladdressapiurl
                          firewallpolicyapiurl := input.parameters.firewallpolicyapiurl
                          firewalladdrgrpapiurl := input.parameters.firewalladdressgrpapiurl
        
                            #Begin Update cfos AddrGrp
                            #AddrGrp has an member with name "none"
                                      
                                      headers := {
                                      "Content-Type": "application/json",
                                      }
                            
                                      addrgrpbody := {
                                        "data":  {"name": src_addr_group, "member": [{"name": "none"}]}
                                      }
                            
                            
                                      addrGroupResp := http.send({
                                        "method": "POST",
                                        "url":  firewalladdrgrpapiurl,
                                        "headers": headers,
                                        "body": addrgrpbody
                                      })
                                      
                            #End Update cfos AddrGrp

                                      
                            #Begin of Firewall Policy update
                                      
                                      firewallPolicybody := {
                                        "data": 
                                          {"policyid":policyid, 
                                                  "name": policyname, 
                                                  "srcintf": [{"name": srcintf}], 
                                                  "dstintf": [{"name": outgoingport}], 
                                                  "srcaddr": [{"name": src_addr_group}],
                                                    #"service": [{"name":"ALL"}],
                                                  "service": myservice,
                                                  "nat":"enable",
                                                  "utm-status":utmstatus,
                                                  "action": "accept",
                                                  "logtraffic": "all",
                                                  "ssl-ssh-profile": sslsshprofile,
                                                  "ips-sensor": ipsprofile,
                                                  "webfilter-profile": "default",
                                                  "av-profile": avprofile,
                                                  "dstaddr": [{"name": "all"}]
                                          }
                                      }
                                      
                                      firewallPolicyResp := http.send({
                                        "method": "POST",
                                         "url":firewallpolicyapiurl, 
                                       "headers": headers,
                                         "body": firewallPolicybody
                                       })
                                      
                            #End of Firewall Policy Update       
 
                      msg :=sprintf(  "\n{%v %v  %v} ", [
                                                            addrGroupResp.status_code,
                                                            firewallPolicyResp.status_code,
                                                            myservice
                                                    ]
                                   )
              } 

EOF

```

you shall see
```
constrainttemplate.templates.gatekeeper.sh/k8segressnetworkpolicytocfosutmpolicy created
```

- ### deploy actual constraint for cFOS network policy

*the kind must match the one defined in the template*
*the enforcementAction:deny means if condition met, the gatekeeper will not send it to kubernetes API*
*match/kinds/NetworkPolicy mean only watch for NetworkPlicy API*
*in parameters, we use label cfosegressfirewallpolicy. then a networkpolicy has same label will be checked*

paste below to your client terminal 

```
cat << EOF | kubectl create -f -
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sEgressNetworkPolicyToCfosUtmPolicy
metadata:
  name: cfosnetworkpolicy
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: ["networking.k8s.io"]
        kinds: ["NetworkPolicy"]
  parameters:
    firewalladdressapiurl : "http://fos-deployment.default.svc.cluster.local/api/v2/cmdb/firewall/address"
    firewallpolicyapiurl : "http://fos-deployment.default.svc.cluster.local/api/v2/cmdb/firewall/policy"
    firewalladdressgrpapiurl: "http://fos-deployment.default.svc.cluster.local/api/v2/cmdb/firewall/addrgrp"
    policyid : "200"
    label: "cfosegressfirewallpolicy"
    outgoingport: "eth0"
    utmstatus: "enable"
    ipsprofile: "default"
    avprofile: "default"
    sslsshprofile: "deep-inspection"
    action: "permit"
    srcintf: "any"
    extraservice: "PING"
EOF
```
you shall see
```
k8segressnetworkpolicytocfosutmpolicy.constraints.gatekeeper.sh/cfosnetworkpolicy created
```
you can use `kubectl get k8segressnetworkpolicytocfosutmpolicy` to check 

```
➜  policy git:(main) ✗ kubectl get k8segressnetworkpolicytocfosutmpolicy
NAME                ENFORCEMENT-ACTION   TOTAL-VIOLATIONS
cfosnetworkpolicy   deny
```

- ### 
we create a normal egress network policy with label "cfosegressfirewallpolicy" to match contraint. 

```
cat << EOF | kubectl create -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: createdbygatekeeper
  labels:
    app: cfosegressfirewallpolicy
spec:
  podSelector:
    matchLabels:
      app: multitool
      namespace: default
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
EOF
```
you shall see output 
```
Error from server (Forbidden): error when creating "STDIN": admission webhook "validation.gatekeeper.sh" denied the request: [cfosnetworkpolicy]
{200 200  {{"name": "HTTP"}, {"name": "HTTPS"}, {"name": "PING"}}}
```

above means gatekeeper after evaluate the condition like label etc, it deny send the request to kubernetes API for create network policy, instead, it send the request to cFOS to create firewall policy. 

after that. login cFOS to check firewall policy,you shall see a policy created by cFOS

```
FOS Container # show firewall policy
config firewall policy
    edit "200"
        set utm-status enable
        set name "createdbygatekeeper"
        set srcintf any
        set dstintf eth0
        set srcaddr defaultappmultitool
        set dstaddr all
        set service HTTP HTTPS PING
        set ssl-ssh-profile "deep-inspection"
        set av-profile "default"
        set webfilter-profile "default"
        set ips-sensor "default"
        set nat enable
        set logtraffic all
    next
end
```


- ### create clientpod to update the addressgroup 

the clientpod also support update POD ip address for the policy created by gatekeeper. 
the yaml file watchandupdatcfospodip.yaml is under git repo 202301/demo/eks/policy.

```
kubectl create -f watchandupdatcfospodip.yaml
```

you can use `kubectl logs -f po/clientpod` to check the log of clientpod.




- ### clean up
use eksctl delete eks cluster

```
eksctl delete cluster EKSDemo
```

- ### demo script

with cfos license yaml file and docker pull secret yaml file, you can use a demo script to setup entire demo.
copy these 2 yaml file to the place you run demo_awslinux_macvlan.sh. 
```
git clone https://github.com/yagosys/202301.git && cd demo/eks && demo_awslinux_macvlan.sh
```

the gatekeeper opa demo script 

```
cd demo/eks/policy && demoopa.sh
```




- ### how to build clientpod 
the image for clientpod can be build by yourself, you can  build it with Dockerfile or podman etc., if you want to enhance it for your own needs.

```
cat << EOF > Dockerfile
FROM alpine:latest
RUN apk add --no-cache curl jq tar bash ca-certificates
ARG KUBECTL_VERSION="v1.25.0"
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

COPY script.sh /script.sh
RUN chmod +x /script.sh
ENTRYPOINT ["/script.sh"]
EOF
```

here we use docker build to build image, and push to image repository 
replace the repo with your own repo.

```
repo="interbeing/kubectl-cfos:latest"
docker build . -t $repo; docker push $repo
```

the script.sh doing the actual job. the file can be found at 202301/demo/eks/policy/

