---
title: "Task 8 - Get cFOS POD description"
chapter: true
weight: 9
---

### Task 8 - Get cFOS POD description

* Default ServiceAccount is used which was granted with a permission to read ***ConfigMap*** and ***Secret*** in earlier chapter.

* Annotations ***k8s.v1.cni.cncf.io/networks*** is used to assign IP.

* Looking at the events log, the interface ***eth0*** and ***net1*** are from ***Multus*** which means it is the default ***CNI*** for EKS.

* ***Multus*** delegates to ***aws-cni*** for ***eth0*** interface and to ***macvlan cni*** for ***net1*** interface.

> Below command will get description of the cFOS POD

```
cfospodname=$(kubectl get pod -l app=fos -o jsonpath='{.items[0].metadata.name}')
kubectl describe po/$cfospodname
```

> output will be similar as below

```
Name:             fos-deployment-x8vzj
Namespace:        default
Priority:         0
Service Account:  default
Node:             ip-10-0-29-226.ap-east-1.compute.internal/10.0.29.226
Start Time:       Fri, 31 Mar 2023 13:36:55 +0800
Labels:           app=fos
                  controller-revision-hash=6555fcd587
                  pod-template-generation=1
Annotations:      k8s.v1.cni.cncf.io/network-status:
                    [{
                        "name": "aws-cni",
                        "interface": "dummydb68da92e6e",
                        "ips": [
                            "10.0.19.107"
                        ],
                        "mac": "0",
                        "default": true,
                        "dns": {}
                    },{
                        "name": "default/cfosdefaultcni5",
                        "interface": "net1",
                        "ips": [
                            "10.1.200.252"
                        ],
                        "mac": "8e:2c:2a:6b:90:49",
                        "dns": {}
                    }]
                  k8s.v1.cni.cncf.io/networks: [ { "name": "cfosdefaultcni5",  "ips": [ "10.1.200.252/32" ], "mac": "CA:FE:C0:FF:00:02" } ]
                  k8s.v1.cni.cncf.io/networks-status:
                    [{
                        "name": "aws-cni",
                        "interface": "dummydb68da92e6e",
                        "ips": [
                            "10.0.19.107"
                        ],
                        "mac": "0",
                        "default": true,
                        "dns": {}
                    },{
                        "name": "default/cfosdefaultcni5",
                        "interface": "net1",
                        "ips": [
                            "10.1.200.252"
                        ],
                        "mac": "8e:2c:2a:6b:90:49",
                        "dns": {}
                    }]
Status:           Running
IP:               10.0.19.107
IPs:
  IP:           10.0.19.107
Controlled By:  DaemonSet/fos-deployment
Containers:
  fos:
    Container ID:   containerd://b12c9e732116597d37e70ee61cbc6fc3ec390597280eecb97ed29a482bdef083
    Image:          interbeing/fos:v7231x86
    Image ID:       docker.io/interbeing/fos@sha256:96b734cf66dcf81fc5f9158e66676ee09edb7f3b0f309c442b48ece475b42e6c
    Ports:          500/UDP, 4500/UDP
    Host Ports:     0/UDP, 0/UDP
    State:          Running
      Started:      Fri, 31 Mar 2023 13:37:02 +0800
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /data from data-volume (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-xxs26 (ro)
Conditions:
  Type              Status
  Initialized       True
  Ready             True
  ContainersReady   True
  PodScheduled      True
Volumes:
  data-volume:
    Type:          HostPath (bare host directory volume)
    Path:          /cfosdata
    HostPathType:  DirectoryOrCreate
  kube-api-access-xxs26:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/disk-pressure:NoSchedule op=Exists
                             node.kubernetes.io/memory-pressure:NoSchedule op=Exists
                             node.kubernetes.io/not-ready:NoExecute op=Exists
                             node.kubernetes.io/pid-pressure:NoSchedule op=Exists
                             node.kubernetes.io/unreachable:NoExecute op=Exists
                             node.kubernetes.io/unschedulable:NoSchedule op=Exists
Events:
  Type    Reason          Age   From               Message
  ----    ------          ----  ----               -------
  Normal  Scheduled       14m   default-scheduler  Successfully assigned default/fos-deployment-x8vzj to ip-10-0-29-226.ap-east-1.compute.internal
  Normal  AddedInterface  14m   multus             Add eth0 [10.0.19.107/32] from aws-cni
  Normal  AddedInterface  14m   multus             Add net1 [10.1.200.252/24] from default/cfosdefaultcni5
  Normal  Pulling         14m   kubelet            Pulling image "interbeing/fos:v7231x86"
  Normal  Pulled          14m   kubelet            Successfully pulled image "interbeing/fos:v7231x86" in 5.773955482s (5.77396476s including waiting)
  Normal  Created         14m   kubelet            Created container fos
  Normal  Started         14m   kubelet            Started container fos
```