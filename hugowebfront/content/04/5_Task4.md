---
title: "Task 4 - Create cFOS daemonSet"
chapter: true
weight: 5
---

### Task 4 - create cFOS daemonSet

* we will create cfos as daemonSet, so each node will have single cfos POD
* cfos will be attached to net-attach-def CRD which created in previous step
* cfos configured a clusterIP service for restapi port
* cfos use annotation to attach to crd. the "k8s.v1.cni.cncf.io/networks" means for secondary network, the default interface inside cfos will be net1 by default
* cfos will have fixed ip "10.1.200.252/32" which is the range of crd cni configuration
* cfos can also have a fixed mac address
* the linux capabilities NET_ADMIN, SYS_AMDIN, NET_RAW are required for use ping, sniff and syslog
* the cfos image will be pulled from docker hub with pull secret
* the  cfos container mount /data to a directory in host work node, the /data save license, and configuration file etc.,
* you need to change the line "image: interbeing/fos:v7231x86 to your actual image respository

copy and paste below code to your terminal window to create cfos DaemonSet

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