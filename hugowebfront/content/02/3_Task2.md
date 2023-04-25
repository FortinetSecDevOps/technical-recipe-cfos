---
title: "Task 2 - IAM permissions to create EKS Cluster"
chapter: true
weight: 3
---

### Task 2 - IAM permissions to create EKS Cluster

1. You will use eksctl to create EKS cluster, When you use eksctl to create an Amazon EKS cluster, it requires an IAM user with sufficient permissions. The IAM user should have the following minimum permissions:

    * ***AmazonEKSFullAccess***: This managed policy provides the necessary permissions to manage EKS clusters.
    * ***AmazonEKSClusterPolicy***: This managed policy allows creating and managing the resources required for an EKS cluster, such as VPCs, subnets, and security groups.
    * ***AmazonEC2FullAccess***: This managed policy provides permissions to manage EC2 instances and other related resources, such as key pairs, Elastic IPs, and snapshots.
    * ***IAMFullAccess***: This managed policy allows eksctl to create and manage IAM roles for your Kubernetes workloads and the Kubernetes control plane.
    * ***AmazonVPCFullAccess***: This managed policy allows eksctl to create and manage the VPC resources required for the EKS cluster, such as VPCs, subnets, route tables, and NAT gateways.
    * ***AWSCloudFormationFullAccess***: This managed policy provides eksctl with permissions to create, update, and delete CloudFormation stacks, which are used to manage the infrastructure resources for your EKS cluster.

1. Validate IAM permissions

    The `aws iam simulate-principal-policy` command is used to simulate the set of IAM policies attached to a principal (user, group, or role) to test their permissions for specific API actions. This command can help you determine whether a specific principal has the necessary permissions to perform a set of actions.
    for example. below command shall show you  "EvalDecsion": allowed" 

    ```
    myarn=$(aws sts get-caller-identity --output text | awk '{print $2}')
    aws iam simulate-principal-policy --policy-source-arn $myarn --action-names "eks:CreateCluster" "eks:DescribeCluster" "ec2:CreateVpc" "iam:CreateRole" "cloudformation:CreateStack" | grep Eval
    ```