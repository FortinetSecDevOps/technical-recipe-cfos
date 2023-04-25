---
title: "Task 8 - Script for entire DEMO"
chapter: true
weight: 9
---

### Task 8 - Script for entire DEMO

1. with cfos license yaml file and docker pull secret yaml file, you can use a demo script to setup entire demo.
copy these 2 yaml file to the place you run demo_awslinux_macvlan.sh. 

        ```
        git clone https://github.com/yagosys/202301.git && cd demo/eks && demo_awslinux_macvlan.sh
        ```

        the gatekeeper opa demo script 

        ```
        cd demo/eks/policy && demoopa.sh
        ```

1. How to build clientpod

* the image for clientpod can be build by yourself, you can  build it with Dockerfile or podman etc., if you want to enhance it for your own needs.

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

        the script.sh doing the actual job. 
        
        the file can be found at 202301/demo/eks/policy/