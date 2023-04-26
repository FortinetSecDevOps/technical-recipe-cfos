---
title: "Task 2 - Build Docker Image"
chapter: true
weight: 3
---

### Task 2 - Build Docker Image with cFOS firmware

Download the **cFOS** firmware from the Fortinet support website and save it to your client machine's home directory:

```
ls ~/FOS_X64_DOCKER-v7-build0232-FORTINET.tar.gz
/home/ubuntu/FOS_X64_DOCKER-v7-build0232-FORTINET.tar.gz
```

1. Create an image from the **cFOS** firmware.

> The **cFOS** firmware is a tar archive containing all layers and metadata needed to recreate the image. Use the `docker load` command to load the tar archive back into Docker, which recreates the image on your system.

```
docker load < FOS_X64_DOCKER-v7-build0232-FORTINET.tar.gz
```

> you can notice the image has name "fos:latest"

```
ubuntu@ip-192-168-70-59:~$ docker load < FOS_X64_DOCKER-v7-build0232-FORTINET.tar.gz
73470e1411f6: Loading layer [==================================================>]  144.4MB/144.4MB
Loaded image: fos:latest
```