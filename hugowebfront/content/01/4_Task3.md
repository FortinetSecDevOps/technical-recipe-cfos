---
title: "Task 3 - Tag & push the Image"
chapter: true
weight: 4
---

### Task 3 - Tag and push the image to a repository

{{< notice note >}}To use image in Kubernetes, we need to upload it to a repository. Tag the image before uploading to repository.{{< /notice >}}

> Below is an example on how to tag it with docker.io account and repository (fos). The version used is X64v7build0231. alternatively, you can also use AWS ECR.

1. Docker Login

    ```
    docker login 
    ```

1. Will see login succeeded but with a warning, providing information about ***config.json*** location.

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

1. Use `docker tag` to tag the image before pushing to docker hub

    ```
    docker tag fos:latest interbeing/fos:X64v7build0231
    ```

1. Push image to a repository

    ```
    docker push interbeing/fos:X64v7build0231
    ```

    > output will be similar as below

    ```
    ubuntu@ip-192-168-90-72:~$ docker push interbeing/fos:X64v7build0231
    The push refers to repository [docker.io/interbeing/fos]
    73470e1411f6: Pushed
    X64v7build0232test: digest: sha256:96b734cf66dcf81fc5f9158e66676ee09edb7f3b0f309c442b48ece475b42e6c size: 529
    ubuntu@ip-192-168-90-72:~$
    ```

1. Alternatively, you can use AWS ECR instead of docker hub. Below is an example for AWS ECR.

    > below script will create a repository in AWS ECR with name "fos", and in region "ap-east-1". Copy-Paste below script to create repository and push image with tag

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

    > output will be similar as below

    > **_NOTE:_** If "fos" repository already exist, then the repository will not be recreated/updated and will throw an error message "RepositoryAlreadyExistsException".

    {{< notice info >}}You will notice the repository secret will be saved under home directory "/home/$HOME/.docker/config.json". One would need this to create **imagepullsecret** in another task.{{< /notice >}}

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

> **_NOTE:_** To use it in Kubernetes. One needs to create a pull secret to pull it from image repository.

