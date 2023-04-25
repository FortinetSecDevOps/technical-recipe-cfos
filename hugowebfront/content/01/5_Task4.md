---
title: "Task 4 - Create a Kubernetes secret to pull the image from a private Docker repository"
chapter: true
weight: 5
---

### Task 4 - Create a Kubernetes secret to pull the image from a private Docker repository

> **_NOTE:_** Click on the link to get details how to pull image from [private registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/).


1. you will need a config.json file to create the secret. if you do not have config.json . you can use docker login to  get that.
    > Below is a quick sample of how to create a pull secret on docker private repository on a linux platform

    * login into your docker account with docker login 

        ```
        docker login
        ```

1. from docker login output, you can see that the config.json file is located at "/home/ubuntu/snap/docker/2746/.docker/config.json"

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

1. locate config.json file 
    > as per the above output config.json file is located under "/home/ubuntu/snap/docker/2746/.docker/config.json"

1. Pull Secret

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

1. you will get a file dockerpullsecret.yaml which include the pull secret. 


