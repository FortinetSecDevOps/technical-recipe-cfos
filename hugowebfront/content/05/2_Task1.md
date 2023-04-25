---
title: "Task 1 - create demo application deployment"
chapter: true
weight: 2
---

### Task 1 - create demo application deployment 

the replicas=4 mean it will create 4 POD on this work node

annotations k8s.v1.cni.cncf.io/networks to tell CRD to attach the pod to network cfosdefaultcni5 with net1 interface

the POD will get default-route 10.1.200.252 which is the ip of cfos on net1 interface

the net1 interface use network cfosdefaultcni5 to communicate with cfos net1

* the POD need to install a route for 10.0.0.0/16 subnet with nexthop to 169.254.1.1, as these traffic do not want goes to cfos, if remove this route, pod to pod communication will be send to cFOS as well


copy and paste below script on your client terminal to create application deployment, we label the pod will label app=multitool01

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