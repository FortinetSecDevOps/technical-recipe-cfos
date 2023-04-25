---
title: "Task 4 - create a clientpod to manage the networkpolicy and update pod ip address to cFOS"
chapter: true
weight: 5
---

### Task 4 - create a clientpod to manage the networkpolicy and update pod ip address to cFOS

we create a pod with name clientpod to create firewall policy for cFOS and it will also keep POD IP address in sync between cFOS and kubernetes.
as POD ip address is not fixed. the IP address will change due to scale , restart etc . we will keep the the POP ip address in sync with cFOS addressgroup.
basically, this clientpod will  

create firewall policy for two deployment which has annotations to use cfosdefaultcni5 netwok

update application pod ip address to cfos addressgroup.

privode pod address update for the firewall policy that created by gatekeeper, if the policy already created by gatekeeper then, it will only update the POD ip address to cFOS addreegroup.

this pod use image which is build use docker build . you can use Dockerfile to build image and modify the script

this pod also monitor the node number change, if work node increased or decreased ,it will restart cfos DaemonSet.


copy and paste below script to your terminal window to create clientpod. this clientpod is mainly use kubectl client to obtain the POD ip address with label and namespace, then use curl to update the cFOS addressgroup to keep the ip address in cFOS to sync with application POD in kubernetes. I have already build the image for this clientpod and put it on dockerhub. so we can directly create POD with that image. 

```
cat << EOF | kubectl create -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-reader
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list", "get", "watch"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["list","get","watch","create"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list", "get", "watch"]
- apiGroups: ["apps"]
  resources: ["daemonsets"]
  verbs: ["get", "list", "watch", "patch", "update"]
- apiGroups: ["constraints.gatekeeper.sh"]
  resources: ["k8segressnetworkpolicytocfosutmpolicy"]
  verbs: ["list","get","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pod-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pod-reader
subjects:
- kind: ServiceAccount
  name: pod-reader
  namespace: default
---
apiVersion: v1
kind: Pod
metadata:
  name: clientpod
spec:
  serviceAccountName: pod-reader
  containers:
  - name: kubectl-container
    image: interbeing/kubectl-cfos:latest
EOF
```