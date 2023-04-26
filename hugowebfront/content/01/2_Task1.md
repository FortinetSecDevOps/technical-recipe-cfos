---
title: "Task 1 - Setup Client Machine"
chapter: true
weight: 2
---

### Task 1 - Setup Client Machine to deploy Kubernetes and cFOS

A client machine is needed to deploy Terraform and SSH into the Kubernetes VM.

> Client Machine can be anything that can use terraform and aws cli. You will use this client machine to deploy Kubernetes on AWS cloud.

1. Install Docker and Docker client
1. Install Terraform client
1. Install AWS CLI with AWS credentials configured
1. Create an SSH key pair
    * on macOS, use the key format ed25519

{{< notice note >}}The commands below are used on Ubuntu 22.04 Linux system.{{< /notice >}}

If you are using a clean Ubuntu Linux system, you can install Docker, AWS CLI v2, and Terraform by using below commands. 

> `eksctl` is required while using EKS, but not when deploying self-managed Kubernetes.

1. Install Docker:

    ```
    sudo snap install docker &&
    sudo addgroup --system docker &&
    sudo adduser $USER docker && 
    newgrp docker 
    ```
    
    ```
    sudo snap disable docker &&
    sudo snap enable docker
    ```

    You should be able to run `docker info` without needing to use `sudo`:

    ```
    ubuntu@ip-192-168-90-72:~$ docker info  | grep Server
    Server:
    Server Version: 20.10.17
    ```

1. Install latest version of terraform 

    ```
    sudo snap install terraform --classic
    ```

 1. Install AWS CLI with AWS credentials configured

    ```
    sudo apt install unzip && 
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && 
    unzip awscliv2.zip && 
    sudo ./aws/install 
    ```
    
    Use `aws configure` to set up AWS credentials:

    ```
    aws configure
    ```

    Once configured, `aws sts get-caller-identity` should display UserId, Account, and ARN:

    ```
    aws sts get-caller-identity
    ```

1. Create an SSH key pair; 
   * on macOS, use the key format ed25519

    > Generate an ed25519 keypair; the Terraform script will use this keypair to create a keypair on AWS for SSH EC2 instances:

    ```
    if [ ! -f "$HOME/.ssh/id_ed25519cfoslab" ]; then
    ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519cfoslab
    fi
    ```