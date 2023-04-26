---
title: "Task 3 - Deploy EKS Cluster"
chapter: true
weight: 4
---

### Task 3 - Deploy EKS Cluster

1. Create ssh key to access eks work node

    Below command will create ssh key if doesn't exist 

    ```
    [ -f ~/.ssh/id_rsa.pub ] || ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ''
    ```

1. Deploy/Create EKS Cluster 

    ***eksctl*** and ***eks config file*** are used to create EKS cluster.  

    Below is a standard EKS config with all default configuration

    * Generate a ssh key. e.g. you can use `ssh-keygen` and place it under ~/.ssh/id
    * Kubernetes **service CIDR** is **10.96.0.0/12**
    * VPC has subnet **10.0.0.0/16**
    * Default region and az is **ap-east-1**, you can change to other regions and az if you want
    * Kubernetes version is 1.25

    > **_NOTE:_** Run/execute below script on your client terminal to create eks cluster 

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

1. Validate EKS cluster 

   > output will be similar as below

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

1. Accessing eks cluster

    Once EKS cluster is ready, **kubeconfig** will be modified or created on your client machine which will enable you to access the remote cluster. 

    > **_NOTE:_** You can use `eksctl utils write-kubeconfig` to re-config the **kubeconfig** file to access eks if you mess-up the configuration.

    * Once deployed, you will see a Kubernetes Cluster with 1 node in ready state, ***Ready*** status indicating that CNI component is also ready. 
    * **aws-node DaemonSet** manages the AWS VPC CNI plugin for Kubernetes, which is responsible for assigning AWS VPC IP addresses to Kubernetes pods.
    
    To view the environment variables and configuration for the aws-node CNI, you can inspect the **aws-node DaemonSet**.

    ```
    podname=$(kubectl get pods -n kube-system -l k8s-app=aws-node -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')
    kubectl -n kube-system get pod $podname -o jsonpath='{.spec.containers[0].env}' | jq .
    ```

   > output will be similar as below

    ```
    [
        {
            "name":"ADDITIONAL_ENI_TAGS",
            "value":"{}"
        },
        {
            "name":"AWS_VPC_CNI_NODE_PORT_SUPPORT",
            "value":"true"
        },
        {
            "name":"AWS_VPC_ENI_MTU",
            "value":"9001"
        },
        {
            "name":"AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG",
            "value":"false"
        },
        {
            "name":"AWS_VPC_K8S_CNI_EXTERNALSNAT",
            "value":"false"
        },
        {
            "name":"AWS_VPC_K8S_CNI_LOGLEVEL",
            "value":"DEBUG"
        },
        {
            "name":"AWS_VPC_K8S_CNI_LOG_FILE",
            "value":"/host/var/log/aws-routed-eni/ipamd.log"
        },
        {
            "name":"AWS_VPC_K8S_CNI_RANDOMIZESNAT",
            "value":"prng"
        },
        {
            "name":"AWS_VPC_K8S_CNI_VETHPREFIX",
            "value":"eni"
        },
        {
            "name":"AWS_VPC_K8S_PLUGIN_LOG_FILE",
            "value":"/var/log/aws-routed-eni/plugin.log"
        },
        {
            "name":"AWS_VPC_K8S_PLUGIN_LOG_LEVEL",
            "value":"DEBUG"
        },
        {
            "name":"DISABLE_INTROSPECTION",
            "value":"false"
        },
        {
            "name":"DISABLE_METRICS",
            "value":"false"
        },
        {
            "name":"DISABLE_NETWORK_RESOURCE_PROVISIONING",
            "value":"false"
        },
        {
            "name":"ENABLE_IPv4",
            "value":"true"
        },
        {
            "name":"ENABLE_IPv6",
            "value":"false"
        },
        {
            "name":"ENABLE_POD_ENI",
            "value":"false"
        },
        {
            "name":"ENABLE_PREFIX_DELEGATION",
            "value":"false"
        },
        {
            "name":"WARM_ENI_TARGET",
            "value":"1"
        },
        {
            "name":"WARM_PREFIX_TARGET",
            "value":"1"
        },
        {
            "name":"MY_NODE_NAME",
            "valueFrom":{
                "fieldRef":{
                    "apiVersion":"v1",
                    "fieldPath":"spec.nodeName"
                }
            }
        }
    ]
    ```

    > **_NOTE:_** By default, there is no pod resource(s) created in default namespace. 

    ```
    kubectl get node -o wide  && kubectl get pod 
    ```
    
   > output will be similar as below
    
    ```
    ✗ kubectl get node -o wide
    NAME                                       STATUS   ROLES    AGE    VERSION               INTERNAL-IP   EXTERNAL-IP    OS-IMAGE         KERNEL-VERSION                  CONTAINER-RUNTIME
    ip-10-0-14-93.ap-east-1.compute.internal   Ready    <none>   163m   v1.25.7-eks-a59e1f0   10.0.14.93    18.167.17.26   Amazon Linux 2   5.10.173-154.642.amzn2.x86_64   containerd://1.6.6
    ✗ kubectl get pod
    No resources found in default namespace.
    ```