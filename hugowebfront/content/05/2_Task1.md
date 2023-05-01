---
title: "Task 1 - Deploy application"
chapter: true
weight: 2
---

### Task 1 - Deploy demo application 

* replicas=4 means, it will create 4 POD(s) on this work node

* annotations ***k8s.v1.cni.cncf.io/networks*** to tell CRD to attach the POD to network ***cfosdefaultcni5*** with ***net1*** interface.

* POD will get ***default-route 10.1.200.252*** which is the IP of **cFOS** on ***net1 interface***.

* The ***net1 interface*** will use network ***cfosdefaultcni5*** to communicate with **cFOS** ***net1***.

* POD will need a route for ***10.0.0.0/16*** subnet with nexthop to ***169.254.1.1***, as the traffic do not want to go to **cFOS**.
  * If the route is removed, POD to POD communication will be sent to **cFOS**.

> Below command will create application deployment with ***label app=multitool01*** to the POD


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