---
title: "Task 1 - Install eksctl and kubectl"
chapter: true
weight: 2
---

### Task 1 - Install eksctl and kubectl

**eksctl** is a command-line tool for creating and managing Amazon EKS clusters.

1. Install eksctl

    Download and install eksctl by following the instructions depending on your operating system in the official [eksctl page](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html)

2. For ubuntu (linux)  versions, paste below content in your machine to install eksctl 

    ```
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
    eksctl version
    ```

3. Install kubectl 
    ```
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    ```