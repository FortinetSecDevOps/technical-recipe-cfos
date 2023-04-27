---
title: "Task 4 - Create cFOS DaemonSet"
chapter: true
weight: 5
---

### Task 4 - Create cFOS DaemonSet

* We will create **cFOS** as DaemonSet, so each node will have single **cFOS** POD.

* **cFOS** will be attached to ***net-attach-def CRD*** which was created earlier.

* **cFOS** is configured as a ***ClusterIP service*** for ***restapi port***.

* **cFOS** will use annotation to attach to CRD. 

* `k8s.v1.cni.cncf.io/networks` means ***secondary network***.

* Default interface inside **cFOS** is ***net1***.

* **cFOS** will have fixed IP ***10.1.200.252/32*** which is the range of CRD cni configuration.

* **cFOS** can also have a fixed mac address.

* Linux capabilities like NET_ADMIN, SYS_AMDIN, NET_RAW are required for ping, sniff and syslog.

* **cFOS** image will be pulled from Docker Hub with pull secret.

* **cFOS** container will mount ***/data*** to a directory in host work node where license file and configuration file etc. are saved in it.

> **_NOTE:_** Make sure to change the line ***image: interbeing/fos:v7231x86*** to your actual image respository.

> By using below code in your client terminal window, will create **cFOS** DaemonSet

```
cat << EOF | kubectl create -f - 
apiVersion: v1
kind: Service
metadata:
  labels:
    app: fos
  name: fos-deployment
  namespace: default
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: fos
  type: ClusterIP
---

apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fos-deployment
  labels:
      app: fos
spec:
  selector:
    matchLabels:
        app: fos
  template:
    metadata:
      labels:
        app: fos
      annotations:
        k8s.v1.cni.cncf.io/networks: '[ { "name": "cfosdefaultcni5",  "ips": [ "10.1.200.252/32" ], "mac": "CA:FE:C0:FF:00:02" } ]'
    spec:
      containers:
      - name: fos
        image: interbeing/fos:v7231x86
        securityContext:
          capabilities:
              add: ["NET_ADMIN","SYS_ADMIN","NET_RAW"]
        ports:
        - name: isakmp
          containerPort: 500
          protocol: UDP
        - name: ipsec-nat-t
          containerPort: 4500
          protocol: UDP
        volumeMounts:
        - mountPath: /data
          name: data-volume
      imagePullSecrets:
      - name: dockerinterbeing
      volumes:
      - name: data-volume
        hostPath:
          path: /cfosdata
          type: DirectoryOrCreate
EOF
```  