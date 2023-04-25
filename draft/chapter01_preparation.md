## Fortinet cFOS Workshop

### Prerequisites

* AWS IAM User 

### Chapter 1 - Setting up environment

 
In this chapter, you will perform the following steps:

* Prepare a client machine to deploy Kubernetes and cFOS
* Build a Docker image with cFOS firmware
* Tag and push the image to a repository
* Create a Kubernetes secret to pull the image from a private Docker repository
* Create a ConfigMap with cFOS license

## Prepare a client machine to deploy Kubernetes and cFOS

Client Machine can be anything that can use terraform and aws cli. You will use this client machine to deploy Kubernetes on AWS cloud.

### Task 1 - Prepare a client machine to deploy Kubernetes and cFOS

* A client machine is needed to deploy Terraform and SSH into the Kubernetes VM.

* Ensure the following components are ready:

    - Install Docker and Docker client
    - Install Terraform client
    - Install AWS CLI with AWS credentials configured
    - Create an SSH key pair; on macOS, use the key format ed25519

> **_NOTE:_** The procedure below demonstrates how to install these components on an Ubuntu 22.04 Linux system.

If you are using a clean Ubuntu Linux system, you can install Docker, AWS CLI v2, and Terraform by use following script. The `eksctl` is only required when using EKS instead of deploy your own self-managed Kubernetes.

Install Docker:

```
    sudo snap install docker &&
    sudo addgroup --system docker &&
    sudo adduser $USER docker && 
    newgrp docker 
```
then 
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

install aws v2 cli 
```
  sudo apt install unzip && 
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && 
  unzip awscliv2.zip && 
  sudo ./aws/install 

```


install latest terraform 

```
sudo snap install terraform --classic
```
Generate an ed25519 keypair; the Terraform script will use this keypair to create a keypair on AWS for SSH EC2 instances:


```
if [ ! -f "$HOME/.ssh/id_ed25519cfoslab" ]; then
   ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519cfoslab
fi
```

Use `aws configure` to set up AWS credentials:

```
aws configure
```

Once configured, `aws sts get-caller-identity` should display your UserId, Account, and ARN:

```
aws sts get-caller-identity
```

### Task 2 - Build a Docker image with cFOS firmware

Download the cFOS firmware from the Fortinet support website and save it to your client machine's home directory:



```
ls ~/FOS_X64_DOCKER-v7-build0232-FORTINET.tar.gz
/home/ubuntu/FOS_X64_DOCKER-v7-build0232-FORTINET.tar.gz

```


* Create an image from the cFOS firmware.

> The cFOS firmware is a tar archive containing all layers and metadata needed to recreate the image. Use the `docker load` command to load the tar archive back into Docker, which recreates the image on your system.


```
docker load < FOS_X64_DOCKER-v7-build0232-FORTINET.tar.gz
```

you shall see the image has name "fos:latest"
```
ubuntu@ip-192-168-70-59:~$ docker load < FOS_X64_DOCKER-v7-build0232-FORTINET.tar.gz
73470e1411f6: Loading layer [==================================================>]  144.4MB/144.4MB
Loaded image: fos:latest
```


### Task 3 - Tag and push image to a repository

* To use image in Kubernetes, we need to upload it to a repository. Tag the image before upload to repository.

> Below is an example on how to tag it with docker.io account and repository (fos). The version used is X64v7build0231. alternatively, you can also use AWS ECR 

Docker Hub example
```
docker login 
```
you shall see login Succeeded with a warning tell you where the config.json is located.

```
 ubuntu@ip-192-168-70-59:~$ docker login
Login with your Docker ID to push and pull images from Docker Hub. If you don't have a Docker ID, head over to https://hub.docker.com to create one.
Username: interbeing
Password:
WARNING! Your password will be stored unencrypted in /home/ubuntu/snap/docker/2746/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```


then use `docker tag` to your your image for push to docker hub

```
docker tag fos:latest interbeing/fos:X64v7build0231
```

* Push image to a repository

```
docker push interbeing/fos:X64v7build0231

```
you shall see output

```
ubuntu@ip-192-168-90-72:~$ docker push interbeing/fos:X64v7build0231
The push refers to repository [docker.io/interbeing/fos]
73470e1411f6: Pushed
X64v7build0232test: digest: sha256:96b734cf66dcf81fc5f9158e66676ee09edb7f3b0f309c442b48ece475b42e6c size: 529
ubuntu@ip-192-168-90-72:~$

```


Alternatively, you can use AWS ECR instead of docker hub. here is AWS ECR example

below script will create a repository in AWS ECR with name "fos", and in region "ap-east-1". 
copy and paste below script to create repository and push image to it with tag
```
repositoryname="fos"
region="ap-east-1"
cfosimagename="v7231x86"
awsaccountid=$(aws sts get-caller-identity | jq -r  .Account)
aws ecr create-repository --repository-name  $repositoryname
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $awsaccountid.dkr.ecr.$region.amazonaws.com
docker tag fos:latest $awsaccountid.dkr.ecr.$region.amazonaws.com/$repositoryname:$cfosimagename
docker push $awsaccountid.dkr.ecr.$region.amazonaws.com/$repositoryname:$cfosimagename
echo image on ecr with tag  $awsaccountid.dkr.ecr.$region.amazonaws.com/$repositoryname:$cfosimagename

```

you shall see below output. if "fos" repository already exist, then the "fos" will not be recreated with an error messages "RepositoryAlreadyExistsException". otherwise .the "fos" repository will be created. 

you shall also see the repository secret will be saved under your home directory "/home/$HOME/.docker/config.json". you will need use this to create imagepullsecret in task 4.

```
An error occurred (RepositoryAlreadyExistsException) when calling the CreateRepository operation: The repository with name 'fos' already exists in the registry with id '732600308177'
WARNING! Your password will be stored unencrypted in /home/i/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
The push refers to repository [732600308177.dkr.ecr.ap-east-1.amazonaws.com/fos]
73470e1411f6: Layer already exists 
v7231x86: digest: sha256:96b734cf66dcf81fc5f9158e66676ee09edb7f3b0f309c442b48ece475b42e6c size: 529
image on ecr with tag 732600308177.dkr.ecr.ap-east-1.amazonaws.com/fos:v7231x86
```


> To use it in Kubernetes. One needs to create a pull secret to pull it from image repository.


### Task 4 - Create a kubernetes secret, for kubernetes to pull image from private docker repository

* Click on the link to get details how to pull image from [private registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/).


* you will need a config.json file to create the secret. if you do not have config.json . you can use docker login to  get that.
* Below is a quick sample of how to create a pull secret on docker private repository on a linux platform

    - login into your docker account with docker login 

        ```
        docker login

        ```

from docker login output, you can see that the config.json file is located at "/home/ubuntu/snap/docker/2746/.docker/config.json"

```
ubuntu@ip-192-168-70-59:~$ docker login
Login with your Docker ID to push and pull images from Docker Hub. If you don't have a Docker ID, head over to https://hub.docker.com to create one.
Username: interbeing
Password:
WARNING! Your password will be stored unencrypted in /home/ubuntu/snap/docker/2746/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded

```

 - locate the config.json file 
  you can found above docker suggest that the config.json file is under "/home/ubuntu/snap/docker/2746/.docker/config.json"

> **_NOTE:_** two bash script provided in the github repo  https://github.com/yagosys/202301.git  with name generatecfoslicensefromvmlicense.sh  generatedockersecret.sh to create license file and dockerpullsecret. 

you can also use below script to generate a yaml file that include the pulling secret.  replace the /home/ubuntu/snap/docker/2746/.docker/config.json with your actual path of config.json file.
 
```
#!/bin/bash
#configjsonfile="$HOME/.docker/config.json"
configjsonfile="/home/ubuntu/snap/docker/2746/.docker/config.json"
case "$(uname -s)" in
    Linux*)  base64_flag="-w0";;
    Darwin*) base64_flag="";;
    *)       echo "Unknown operating system"; exit 1;;
esac


ENCODED_CONFIG_DATA=$(cat $configjsonfile | base64 $base64_flag)

cat <<EOF >  dockerpullsecret.yaml
{
  "apiVersion": "v1",
  "kind": "Secret",
  "metadata": {
    "name": "dockerinterbeing"
  },
  "type": "kubernetes.io/dockerconfigjson",
  "data": {
    ".dockerconfigjson": "${ENCODED_CONFIG_DATA}"
  }
}
EOF

```

you will get a file dockerpullsecret.yaml which include the pull secret. 





### Task 5 - Create a configmap with cfos license

> **_NOTE:_** cFOS license is required to run/deploy cFOS.

* cFOS license can either be used inside a configmap or can be imported into cfos using the cfos cli. 
> Use configmap allow you to load license before install cfos.

* Below is the format of configmap with license
> **_NOTE:_** Do not forgot the "|" after the license: field.  
> **_NOTE:_** the license text that between the lines "    -----BEGIN FGT VM LICENSE----- " and "     -----END FGT VM LICENSE-----" must not include any hard return.
> **_NOTE:_** when you copy and paste licens . please remove hard return first**
> **_NOTE:_** two bash script provided in the github repo  https://github.com/yagosys/202301.git  with name generatecfoslicensefromvmlicense.sh  generatedockersecret.sh to create license file and dockerpullsecret. 
 

You can also use the script below to create a license file. Replace the VM license filename with your own license file name. The example below assumes you have already obtained a FortiGate VM license with the file name FGVMULTM23000010.lic. In the directory containing FGVMULTM23000010.lic, paste the script below to generate the license ConfigMap file.

This script will generate a cfos_license.yaml file with the necessary ConfigMap format for the cFOS license.
```
licensestring=$(sed '1d;$d' FGVMULTM23000010.lic | tr -d '\n')
cat <<EOF >cfos_license.yaml
apiVersion: v1
kind: ConfigMap
metadata:
    name: fos-license
    labels:
        app: fos
        category: license
data:
    license: |
     -----BEGIN FGT VM LICENSE-----
     $licensestring
     -----END FGT VM LICENSE-----
EOF
```



