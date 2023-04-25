- ## Task Create cFOS for egress security in self managed kubernetes with Flannel and bridge CNI  

- ## Description

This chapter will guide you through setting up cFOS on an EKS cluster with `FLANNEL CNI ` and `Brdige CNI`. The application pod will use an additional network to communicate with cFOS. Multus CNI is required to create and manage the additional network.

In this chapter, we will demonstrate how to set up cFOS to use an additional network to route traffic from two applications to the internet. We use Multus CNI to manage the additional network for traffic between cFOS and the application pod. `Bridge CNI` is utilized as the actual CNI for the secondary network. In this setup, the application pod's IP address is visible to cFOS.  We also demonstrate how cFOS can detect malicious URLs from the application pod to the internet, even when the traffic is HTTPS-based.



- ## Network Diagram

```
+---------------+   eth0    +--------------+  eth0 (SNAT)           
| Application   +---------->|    cFOS      |--------------  internet 
| Pod           |FLANNELCNI |              |  
+               +           +              +          
|               |   net1    |  DaemonSet   | 
|               +---------->|              |
|               |BridgeCNI  |              |
+---------------+           +--------------+ 

Cluster POD to POD Traffic: eth0 (Application Pod) <--> eth0 (cFOS Pod)
Internet Traffic: Application Pod ---> net1 (cFOS Pod) ---> eth0 (sNAT enabled) ---> Internet 

The eth0 interfaces are managed by Multus with delegation to `FLANNEL CNI`, and the net1 interfaces are managed by Multus with delegation to `Bridge CNI`

```


both the Application POD and cFOS POD have two interfaces: eth0 and net1. The eth0 interfaces are managed by Multus with delegation to `FLANNEL cni`, and the net1 interfaces are managed by Multus with delegation to `Bridge CNI` . The application POD communicates with the cFOS POD using the net1 interface. The traffic from the Application POD to the internet is routed through the cFOS POD, with SNAT enabled on the cFOS eth0 interface.

- ## preparation
please complete https://fortinetsecdevops.github.io/tec-workshop-cFOS/01.html before continue


- ## deploy kubernetes 
*this section we install k8s with basic component without any cni configuraiton*

we use terraform to deploy a self managed kubernetes on aws cloud. at least one kubernetes master and one work node is required. each will use one EC2 instance.


```
cd ~
git clone https://github.com/yagosys/202301.git && cd 202301/deployment/k8s
terraform init
```

- ## modify linux.auto.tfvars files

modify linux.auto.tfvars file to make sure the cfosLicense , key_location and dockerinterbeing point to the right location. 

```
region="us-east-1"
instance_type="t3.large"
worker_count=2
cni="do not install"
multuscni="false"
gatekeeper="false"
cfosLicense="~/cfos_license.yaml"
key_location="~/.ssh/id_ed25519cfoslab"
dockerinterbeing="~/dockerpullsecret.yaml"
```
- ## deploy k8s

```
terraform apply --auto-approve
```
the script start deploy the k8s ,you will see the progress from the console, if everything goes well. you will get a running k8s in few minutes. a k8s cluster with 3 nodes will be created. one node is for master node. other 2 nodes are for work nodes.




- ## check the deployment

after the deployment complete, the script will show

```
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:

instance_public_ip = "3.82.66.134"
workernode_instance_public_ip = [
  "54.198.42.119",
  "3.81.138.202",
]
```
afterwards, we can always use `terraform output` to get the ip address in case we need that


- ## copy client ssh key into kubernetes nodes
ssh into directly master node to use kubectl command for all tasks.
paste below command in your client machine to copy your local ssh key into master node.

```
ip=$(terraform output --raw instance_public_ip) &&
scp -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519cfoslab ~/.ssh/id_ed25519cfoslab ubuntu@$ip:.ssh/id_ed25519cfoslab
scp -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519cfoslab ~/.ssh/id_ed25519cfoslab.pub ubuntu@$ip:.ssh/id_ed25519cfoslab.pub
```

you shall see ouput
```
✗ ip=$(terraform output --raw instance_public_ip) &&
scp -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519cfoslab ~/.ssh/id_ed25519cfoslab ubuntu@$ip:.ssh/id_ed25519cfoslab
scp -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519cfoslab ~/.ssh/id_ed25519cfoslab.pub ubuntu@$ip:.ssh/id_ed25519cfoslab.pub
Warning: Permanently added '34.229.250.177' (ED25519) to the list of known hosts.
id_ed25519cfoslab                                                                                                                          100%  432     1.7KB/s   00:00
id_ed25519cfoslab.pub                                                                                                                      100%  114     0.4KB/s   00:00
```

- ## ssh into the master node

```
ip=$(terraform output --raw instance_public_ip) &&
ssh -i ~/.ssh/id_ed25519cfoslab ubuntu@$ip
```
you shall be dropped into the master node, from there, we do the all installation 
```
ubuntu@ip-10-0-1-100:~$
```

- ## ssh into the master node 

```
ip=$(terraform output --raw instance_public_ip) && 
ssh -i ~/.ssh/id_ed25519cfoslab ubuntu@$ip
```
you shall be dropped into the master node

```
ubuntu@ip-10-0-1-100:~$
```

- ## check the master node 
use 'kubectl get node' to check the ndoe status. the node status shall be  ready  
```
kubectl get node
```
you shall see

```
NAME            STATUS   ROLES           AGE     VERSION
ip-10-0-2-200   Ready    <none>          7m13s   v1.26.2
ip-10-0-2-201   Ready    <none>          7m18s   v1.26.2
ip1001100       Ready    control-plane   9m42s   v1.26.2
```

you will see the master node has no valid cni installed. and the pod that need CNI is pending in "ContainerCreating" status. 

```
ls /etc/cni/net.d
```
you will see there is only one loopback cni
```
ubuntu@ip-10-0-1-100:~$ ls /etc/cni/net.d
200-loopback.conf
```
the coredns is pending "ContainerCreating" due to no valid CNI. 
```
ubuntu@ip-10-0-1-100: kubectl get pod -A
NAMESPACE     NAME                                READY   STATUS              RESTARTS   AGE
kube-system   coredns-787d4945fb-t7ltk            0/1     ContainerCreating   0          23m
kube-system   coredns-787d4945fb-zqdf4            0/1     ContainerCreating   0          23m
kube-system   etcd-ip1001100                      1/1     Running             0          23m
kube-system   kube-apiserver-ip1001100            1/1     Running             0          23m
kube-system   kube-controller-manager-ip1001100   1/1     Running             0          23m
kube-system   kube-proxy-8vlt8                    1/1     Running             0          23m
kube-system   kube-proxy-dx6qt                    1/1     Running             0          21m
kube-system   kube-proxy-lk4wh                    1/1     Running             0          20m
kube-system   kube-scheduler-ip1001100            1/1     Running             0          23m
```


- ## install flannel cni


```
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

```
you shall see flannel daemonset is created 

```
namespace/kube-flannel created
serviceaccount/flannel created
clusterrole.rbac.authorization.k8s.io/flannel created
clusterrolebinding.rbac.authorization.k8s.io/flannel created
configmap/kube-flannel-cfg created
daemonset.apps/kube-flannel-ds created
```

- ### check flannel config 
*once installed flannel, flannel will create a default cni config under /etc/cni/net.d/10-flannel.conflist, it will become the default cni for k8s
this cni has name "cbr0" which in turn in will delegate to bridge cni for actual work.* 

```
ls /etc/cni/net.d
```
you will see a file **10-flannel.conflist** has been created 
10-flannel.conflist  200-loopback.conf  

check the content of this file

```
 cat /etc/cni/net.d/10-flannel.conflist | jq
```

```
ubuntu@ip-10-0-1-100:/etc/cni/net.d$ cat /etc/cni/net.d/10-flannel.conflist | jq
{
  "name": "cbr0",
  "cniVersion": "0.3.1",
  "plugins": [
    {
      "type": "flannel",
      "delegate": {
        "hairpinMode": true,
        "isDefaultGateway": true
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      }
    }
  ]
}
```

in this k8s, crio is the container running time
*crio will pickup this cni as the default cluster network* 

use command  `journalctl -u crio  | grep "Updated default CNI network name to "  | tail -n 1` to check the crio log which indicate that crio now using flannel as the default cni

you will see output 
```
Mar 15 12:17:36 ip-10-0-1-100 crio[1680]: time="2023-03-15 12:17:36.489025616Z" level=info msg="Updated default CNI network name to cbr0"
```

check the pod status again with command 

`kubectl get pod -A`

*you will found the previous pending coredns pod now got ip address* 

```
ubuntu@ip-10-0-1-100:/etc/cni/net.d$ kubectl get pod -A
NAMESPACE      NAME                                READY   STATUS    RESTARTS   AGE
kube-flannel   kube-flannel-ds-hdlcz               1/1     Running   0          6m53s
kube-flannel   kube-flannel-ds-mvqgd               1/1     Running   0          6m53s
kube-flannel   kube-flannel-ds-xndc8               1/1     Running   0          6m53s
kube-system    coredns-787d4945fb-t7ltk            1/1     Running   0          34m
kube-system    coredns-787d4945fb-zqdf4            1/1     Running   0          34m
kube-system    etcd-ip1001100                      1/1     Running   0          34m
kube-system    kube-apiserver-ip1001100            1/1     Running   0          34m
kube-system    kube-controller-manager-ip1001100   1/1     Running   0          34m
kube-system    kube-proxy-8vlt8                    1/1     Running   0          34m
kube-system    kube-proxy-dx6qt                    1/1     Running   0          32m
kube-system    kube-proxy-lk4wh                    1/1     Running   0          32m
kube-system    kube-scheduler-ip1001100            1/1     Running   0          34m
```

- ## install  multus with multus-conf-file set to auto 
*this section we need multus and by default multus will become first CNI of kubernetens, and delegate to the first valid cni previously configured which is flannel*


```
sudo crictl pull ghcr.io/k8snetworkplumbingwg/multus-cni:stable 
cd /home/ubuntu
git clone https://github.com/intel/multus-cni.git
cat /home/ubuntu/multus-cni/deployments/multus-daemonset.yml | kubectl apply -f -

```
you shall see 
```
ubuntu@ip-10-0-1-100:/etc/cni/net.d$ sudo crictl pull ghcr.io/k8snetworkplumbingwg/multus-cni:stable
cd /home/ubuntu
git clone https://github.com/intel/multus-cni.git
cat /home/ubuntu/multus-cni/deployments/multus-daemonset.yml | kubectl apply -f -
Image is up to date for ghcr.io/k8snetworkplumbingwg/multus-cni@sha256:b228057275949471dc5751fd9e06839200d94f00f198d75b9052576d7ea0fdc5
Cloning into 'multus-cni'...
remote: Enumerating objects: 39809, done.
remote: Counting objects: 100% (267/267), done.
remote: Compressing objects: 100% (185/185), done.
remote: Total 39809 (delta 87), reused 216 (delta 69), pack-reused 39542
Receiving objects: 100% (39809/39809), 49.69 MiB | 22.90 MiB/s, done.
Resolving deltas: 100% (18320/18320), done.
customresourcedefinition.apiextensions.k8s.io/network-attachment-definitions.k8s.cni.cncf.io created
clusterrole.rbac.authorization.k8s.io/multus created
clusterrolebinding.rbac.authorization.k8s.io/multus created
serviceaccount/multus created
configmap/multus-cni-config created
daemonset.apps/kube-multus-ds created
```

- ### check multus config 
use command 
```
kubectl rollout status ds kube-multus-ds -n kube-system
```
you shall see output 
```
ubuntu@ip-10-0-1-100:~$ kubectl rollout status ds kube-multus-ds -n kube-system
daemon set "kube-multus-ds" successfully rolled out
```
*we installed multus with default configuration which the multus-conf-file parameter set to "auto", this means multus ds will automatically monitor the cni config change and update it's delegation in 00-multus.conf file, below you will found multus put 00-multus.conf under /etc/cni/net.d, and then config it delegate to the previously flannel cni with name cbr0, whenever the flannel cni cbr0 changed, the 00-multus.conf will automatically updated to reflect the change*


*this 00-multus.conf will be created on each node as crio is runnig on each node* 

```
ls /etc/cni/net.d
```
you shall see

```
ubuntu@ip-10-0-1-100:~$ ls /etc/cni/net.d
00-multus.conf  10-flannel.conflist  200-loopback.conf  multus.d
```
```
sudo cat /etc/cni/net.d/00-multus.conf | jq . 
```

you shall see 
```
ubuntu@ip-10-0-1-100:/etc/cni/net.d$ sudo cat 00-multus.conf | jq .
{
  "cniVersion": "0.3.1",
  "name": "multus-cni-network",
  "type": "multus",
  "capabilities": {
    "portMappings": true
  },
  "kubeconfig": "/etc/cni/net.d/multus.d/multus.kubeconfig",
  "delegates": [
    {
      "name": "cbr0",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
  ]
}
```

you can found the crio now use multus as the default cni 

```
journalctl -u crio  | grep "Updated default CNI network name to "  | tail -n 1
```
the output will become

```
ubuntu@ip-10-0-1-100:~$ journalctl -u crio  | grep "Updated default CNI network name to "  | tail -n 1
Apr 03 10:07:00 ip-10-0-1-100 crio[1900]: time="2023-04-03 10:07:00.404617147Z" level=info msg="Updated default CNI network name to multus-cni-network"
```

- ## use configmap to deploy cfos configuration 

```
cat << EOF | kubectl apply -f -
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: cfosdata
spec:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 1.1Gi
  persistentVolumeReclaimPolicy: Delete
  hostPath:
    path: /home/ubuntu/data/pv0001
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cfosdata
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  namespace: default
  name: configmap-reader
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-configmaps
  namespace: default
subjects:
- kind: ServiceAccount
  name: default
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: configmap-reader
  apiGroup: ""
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
   namespace: default
   name: secrets-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-secrets
  namespace: default
subjects:
- kind: ServiceAccount
  name: default
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: secrets-reader
  apiGroup: ""
EOF
```
create configmap for cfos 
```
cat << EOF | kubectl apply -f - 
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: foscfgstaticdefaultroute
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config router static
       edit "1"
           set gateway 169.254.1.1
           set device "eth0"
       next
    end

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: foscfgfirewallpolicy
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config firewall policy
           edit "3"
               set utm-status enable
               set name "pod_to_internet_HTTPS_HTTP"
               set srcintf any
               set dstintf eth0
               set srcaddr all
               set dstaddr all
               set service HTTPS HTTP PING DNS
               set ssl-ssh-profile "deep-inspection"
               set ips-sensor "default"
               set webfilter-profile "default"
               set av-profile "default"
               set nat enable
               set logtraffic all
           next
       end
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: foscfgdns
  labels:
      app: fos
      category: config
data:
  type: partial
  config: |-
    config system dns
      set primary 10.96.0.10
      set secondary 10.0.0.2
    end

EOF

```
- ## use multus crd to create net-attach-def cfosdefaultcni5 as secondary Network for pod to attach 
*the kind is NetworkAttachmentDefinition, the short name is net-attach-def*

*you can use `kubectl explain net-attach-def` to get help*

*this crd is read by multus, the cni config is passed in json format in spec /config field*

*no tab key is allowed in json config (between {}). so make sure there is no tab key inside*

*the bridge cni will create a bridge with name cni5*

*the ipam type is host-local, you can also change to whereabouts if you want ip address unique across the cluster*

*two specific route is added, 10.96.0.0/12 is for cluster IP, 10.0.0.2/32 is for aws dns in VPC with cidr 10.0.0.0/8, this two subnet traffic will not goes to cfos. instead it will go directly exit from bridge gateway interface cni5*



```
cat << EOF | kubectl apply -f - 
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: cfosdefaultcni5
spec:
  config: |-
    {
      "cniVersion": "0.3.1",
      "name": "cfosdefaultcni5",
      "type": "bridge",
      "bridge": "cni5",
      "isGateway": true,
      "ipMasq": false,
      "hairpinMode": true,
      "ipam": {
          "type": "host-local",
          "routes": [
              { "dst": "10.96.0.0/12","gw": "10.1.128.1" },
              { "dst": "10.0.0.2/32", "gw": "10.1.128.1" }
          ],
          "ranges": [
              [{ "subnet": "10.1.128.0/24" }]
          ]
      }
    }
EOF

```

- ### check the cfosdefaultcni5 net-attach-def


```
$ kubectl get net-attach-def cfosdefaultcni5 
NAME              AGE
cfosdefaultcni5   92m
```




- ## deploy cfos daemonSet with default clusterNetwork and secondaryNetwork

*this section we deploy a cfos daemonset at each worker node use yaml file* 

*cfos use annotations to use additional network to cfosdefaultcni5 crd*

*cfos configured with static ip 10.1.128.252 on net1 interface*

*cfos expose 80 port which is restful interface via CLusterIP*

*cfos config linux capabilities ["NET_ADMIN","SYS_ADMIN","NET_RAW"] , NET_ADMIN and NET_RAW are required for use packet capture and ping*

*cfos configured with local storage on each node and mounted as /data folder*

*cfos do not config default route via default-calico or cfosdefaultcni5. instead , the default route is configured through cfos static route which install route not in main routing table but in table 231. table 231 has higher priority than main routing table*

*cfos congured as DaemonSet, so each node will have only one cfos POD, if more than 1 cfos POD is needed. config another DaemonSet for cFOS with different static IP*


```
cat << EOF | kubectl apply -f -
---
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
        k8s.v1.cni.cncf.io/networks: '[ { "name": "cfosdefaultcni5",  "ips": [ "10.1.128.252/32" ], "mac": "CA:FE:C0:FF:00:02" } ]'
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
        #nfs:
        #  server: 10.0.1.100
        #  path: /home/ubuntu/data
        #  readOnly: no
        persistentVolumeClaim:
          claimName: cfosdata
EOF
```
- ## check the deployment of cfos ds
```
kubectl rollout status ds fos-deployment
```

you shall see
```
daemon set "fos-deployment" successfully rolled out
```

```
ubuntu@ip-10-0-1-100:~$ kubectl describe ds fos-deployment
Name:           fos-deployment
Selector:       app=fos
Node-Selector:  <none>
Labels:         app=fos
Annotations:    deprecated.daemonset.template.generation: 2
Desired Number of Nodes Scheduled: 3
Current Number of Nodes Scheduled: 3
Number of Nodes Scheduled with Up-to-date Pods: 3
Number of Nodes Scheduled with Available Pods: 3
Number of Nodes Misscheduled: 0
Pods Status:  3 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:       app=fos
  Annotations:  k8s.v1.cni.cncf.io/networks: [ { "name": "cfosdefaultcni5",  "ips": [ "10.1.128.252/32" ], "mac": "CA:FE:C0:FF:00:02" } ]
                kubectl.kubernetes.io/restartedAt: 2023-03-15T12:47:46Z
  Containers:
   fos:
    Image:        interbeing/fos:v7231x86
    Ports:        500/UDP, 4500/UDP
    Host Ports:   0/UDP, 0/UDP
    Environment:  <none>
    Mounts:
      /data from data-volume (rw)
  Volumes:
   data-volume:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  cfosdata
    ReadOnly:   false
Events:
  Type    Reason            Age   From                  Message
  ----    ------            ----  ----                  -------
  Normal  SuccessfulCreate  27m   daemonset-controller  Created pod: fos-deployment-2gkqf
  Normal  SuccessfulCreate  27m   daemonset-controller  Created pod: fos-deployment-sm4dp
  Normal  SuccessfulCreate  27m   daemonset-controller  Created pod: fos-deployment-gzg4c
  Normal  SuccessfulDelete  26m   daemonset-controller  Deleted pod: fos-deployment-2gkqf
  Normal  SuccessfulCreate  25m   daemonset-controller  Created pod: fos-deployment-f65b8
  Normal  SuccessfulDelete  25m   daemonset-controller  Deleted pod: fos-deployment-gzg4c
  Normal  SuccessfulCreate  24m   daemonset-controller  Created pod: fos-deployment-wgv5p
  Normal  SuccessfulDelete  24m   daemonset-controller  Deleted pod: fos-deployment-sm4dp
  Normal  SuccessfulCreate  24m   daemonset-controller  Created pod: fos-deployment-9hb6f

```
```

  ubuntu@ip-10-0-1-100:~$ kubectl describe po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`
Name:             fos-deployment-9hb6f
Namespace:        default
Priority:         0
Service Account:  default
Node:             ip-10-0-2-200/10.0.2.200
Start Time:       Wed, 15 Mar 2023 12:49:21 +0000
Labels:           app=fos
                  controller-revision-hash=78d7c4b795
                  pod-template-generation=2
Annotations:      k8s.v1.cni.cncf.io/network-status:
                    [{
                        "name": "cbr0",
                        "interface": "eth0",
                        "ips": [
                            "10.244.2.4"
                        ],
                        "mac": "ce:85:c2:1c:d1:cb",
                        "default": true,
                        "dns": {}
                    },{
                        "name": "default/cfosdefaultcni5",
                        "interface": "net1",
                        "ips": [
                            "10.1.128.252"
                        ],
                        "mac": "ca:fe:c0:ff:00:02",
                        "dns": {}
                    }]
                  k8s.v1.cni.cncf.io/networks: [ { "name": "cfosdefaultcni5",  "ips": [ "10.1.128.252/32" ], "mac": "CA:FE:C0:FF:00:02" } ]
                  k8s.v1.cni.cncf.io/networks-status:
                    [{
                        "name": "cbr0",
                        "interface": "eth0",
                        "ips": [
                            "10.244.2.4"
                        ],
                        "mac": "ce:85:c2:1c:d1:cb",
                        "default": true,
                        "dns": {}
                    },{
                        "name": "default/cfosdefaultcni5",
                        "interface": "net1",
                        "ips": [
                            "10.1.128.252"
                        ],
                        "mac": "ca:fe:c0:ff:00:02",
                        "dns": {}
                    }]
                  kubectl.kubernetes.io/restartedAt: 2023-03-15T12:47:46Z
Status:           Running
IP:               10.244.2.4
IPs:
  IP:           10.244.2.4
Controlled By:  DaemonSet/fos-deployment
Containers:
  fos:
    Container ID:   cri-o://d0657155ed582c90c3922c93dcfc085bea31705fc662fcc3d95134bd079bcfec
    Image:          interbeing/fos:v7231x86
    Image ID:       docker.io/interbeing/fos@sha256:96b734cf66dcf81fc5f9158e66676ee09edb7f3b0f309c442b48ece475b42e6c
    Ports:          500/UDP, 4500/UDP
    Host Ports:     0/UDP, 0/UDP
    State:          Running
      Started:      Wed, 15 Mar 2023 12:49:22 +0000
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /data from data-volume (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-8cvwk (ro)
Conditions:
  Type              Status
  Initialized       True
  Ready             True
  ContainersReady   True
  PodScheduled      True
Volumes:
  data-volume:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  cfosdata
    ReadOnly:   false
  kube-api-access-8cvwk:
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
  Normal  Scheduled       28m   default-scheduler  Successfully assigned default/fos-deployment-9hb6f to ip-10-0-2-200
  Normal  AddedInterface  28m   multus             Add eth0 [10.244.2.4/24] from cbr0
  Normal  AddedInterface  28m   multus             Add net1 [10.1.128.252/24] from default/cfosdefaultcni5
  Normal  Pulled          28m   kubelet            Container image "interbeing/fos:v7231x86" already present on machine
  Normal  Created         28m   kubelet            Created container fos
  Normal  Started         28m   kubelet            Started container fos
  ```
*above you will found pod get ip address via multus from cbr0 (the flannel cni) and cfosdefaultcni5 (the bridge cni)*
```
  Normal  AddedInterface  28m   multus             Add eth0 [10.244.2.4/24] from cbr0
  Normal  AddedInterface  28m   multus             Add net1 [10.1.128.252/24] from default/cfosdefaultcni5
```


*check the cfos pod log on pod on node 10-0-2-200*

you will found the cfos is running 7.2.0.0231 version and System is ready, also a few configmap has been read into cfos include license etc.,

```
ubuntu@ip-10-0-1-100:~$ kubectl logs -f po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`

System is starting...

Firmware version is 7.2.0.0231
Preparing environment...
Starting services...
System is ready.

2023-03-15_12:49:23.65335 ok: run: /run/fcn_service/certd: (pid 261) 0s, normally down
2023-03-15_12:49:28.69703 INFO: 2023/03/15 12:49:28 received a new fos configmap
2023-03-15_12:49:28.69708 INFO: 2023/03/15 12:49:28 configmap name: fos-license, labels: map[app:fos category:license]
2023-03-15_12:49:28.69708 INFO: 2023/03/15 12:49:28 got a fos license
2023-03-15_12:49:28.69708 INFO: 2023/03/15 12:49:28 received a new fos configmap
2023-03-15_12:49:28.69708 INFO: 2023/03/15 12:49:28 configmap name: foscfgfirewallpolicy, labels: map[app:fos category:config]
2023-03-15_12:49:28.69708 INFO: 2023/03/15 12:49:28 got a fos config
2023-03-15_12:49:28.69722 INFO: 2023/03/15 12:49:28 received a new fos configmap
2023-03-15_12:49:28.69722 INFO: 2023/03/15 12:49:28 configmap name: foscfgdns, labels: map[app:fos category:config]
2023-03-15_12:49:28.69723 INFO: 2023/03/15 12:49:28 got a fos config
```

- ### shell into cfos container 
*the cfos has default route point to  10.244.2.1 which is the flannel vxlan tunnel interface address on node 10.0.2.200*
*the cfos has default route point to  10.244.1.1 which is the flannel vxlan tunnel interface address on node 10.0.2.201*
*the cfos has default route point to  10.244.0.1 which is the flannel vxlan tunnel interface address on node 10.0.1.100*

*each node has different podCIDR subnet, so the flannel vxlan interface ip address is also different*

```
ubuntu@ip-10-0-1-100:~$ kubectl exec -it po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip1001100 |     cut -d ' ' -f 1 | tail -n -1`  -- ip route
default via 10.244.0.1 dev eth0
10.0.0.2 via 10.1.128.1 dev net1
10.1.128.0/24 dev net1 proto kernel scope link src 10.1.128.2
10.96.0.0/12 via 10.1.128.1 dev net1
10.244.0.0/24 dev eth0 proto kernel scope link src 10.244.0.6
10.244.0.0/16 via 10.244.0.1 dev eth0
ubuntu@ip-10-0-1-100:~$ kubectl exec -it po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- ip route
default via 10.244.2.1 dev eth0
10.0.0.2 via 10.1.128.1 dev net1
10.1.128.0/24 dev net1 proto kernel scope link src 10.1.128.2
10.96.0.0/12 via 10.1.128.1 dev net1
10.244.0.0/16 via 10.244.2.1 dev eth0
10.244.2.0/24 dev eth0 proto kernel scope link src 10.244.2.4
ubuntu@ip-10-0-1-100:~$ kubectl exec -it po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-201 |     cut -d ' ' -f 1 | tail -n -1`  -- ip route
default via 10.244.1.1 dev eth0
10.0.0.2 via 10.1.128.1 dev net1
10.1.128.0/24 dev net1 proto kernel scope link src 10.1.128.2
10.96.0.0/12 via 10.1.128.1 dev net1
10.244.0.0/16 via 10.244.1.1 dev eth0
10.244.1.0/24 dev eth0 proto kernel scope link src 10.244.1.4
ubuntu@ip-10-0-1-100:~$
```



- ### create demo application deployment  
*this application pod use cluster default-network for eth0,  and also attached to secondary network "cfosdefaultcni5" via annoations for net1*

*pod will obtain default route from "cfosdefaultcni5" by use annotations with key-workd k8s.v1.cni.cncf.io/networks: '[ { "name": "cfosdefaultcni5",  "default-route": ["10.1.128.252"]  } ]'*

*we need use this pod to do tcpdump, ping  etc, so we assigned capabilities with "NET_ADMIN","SYS_ADMIN","NET_RAW"*

```
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multitool01-deployment
  labels:
      app: multitool01
spec:
  replicas: 3
  selector:
    matchLabels:
        app: multitool01
  template:
    metadata:
      labels:
        app: multitool01
      annotations:
        k8s.v1.cni.cncf.io/networks: '[ { "name": "cfosdefaultcni5",  "default-route": ["10.1.128.252"]  } ]'
    spec:
      containers:
        - name: multitool01
          #image: wbitt/network-test
          image: praqma/network-multitool
            #image: nginx:latest
          imagePullPolicy: Always
            #command: ["/bin/sh","-c"]
          args:
            - /bin/sh
            - -c
            - /usr/sbin/nginx -g "daemon off;"
          securityContext:
            capabilities:
              add: ["NET_ADMIN","SYS_ADMIN","NET_RAW"]
          #  privileged: true
EOF
```

- ## check the deployment 

the multitool01 pod will get the default route from crd net-attach-def cfosdefaultcni5. this default route will overide the one from cluster default network. so the default traffic will go to cfos. two other subnet 10.0.0.2/232 and 10.96.0.0/12 route is obtained from bridge cni cfosdefaultcni5 as well as it configured in crd cfosdefaultcni5. 

```
ubuntu@ip-10-0-1-100:~/202301$ kubectl exec -it po/`kubectl get pods -l app=multitool01 --field-selector spec.nodeName=ip1001100 |     cut -d ' ' -f 1 | tail -n -1`  -- ip route
default via 10.1.128.252 dev net1
10.0.0.2 via 10.1.128.1 dev net1
10.1.128.0/24 dev net1 proto kernel scope link src 10.1.128.253
10.96.0.0/12 via 10.1.128.1 dev net1
10.244.0.0/24 dev eth0 proto kernel scope link src 10.244.0.5
10.244.0.0/16 via 10.244.0.1 dev eth0

ubuntu@ip-10-0-1-100:~/202301$ kubectl exec -it po/`kubectl get pods -l app=multitool01 --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- ip route
default via 10.1.128.252 dev net1
10.0.0.2 via 10.1.128.1 dev net1
10.1.128.0/24 dev net1 proto kernel scope link src 10.1.128.2
10.96.0.0/12 via 10.1.128.1 dev net1
10.244.0.0/16 via 10.244.1.1 dev eth0
10.244.1.0/24 dev eth0 proto kernel scope link src 10.244.1.3

ubuntu@ip-10-0-1-100:~/202301$ kubectl exec -it po/`kubectl get pods -l app=multitool01 --field-selector spec.nodeName=ip-10-0-2-201 |     cut -d ' ' -f 1 | tail -n -1`  -- ip route
default via 10.1.128.252 dev net1
10.0.0.2 via 10.1.128.1 dev net1
10.1.128.0/24 dev net1 proto kernel scope link src 10.1.128.2
10.96.0.0/12 via 10.1.128.1 dev net1
10.244.0.0/16 via 10.244.2.1 dev eth0
10.244.2.0/24 dev eth0 proto kernel scope link src 10.244.2.3
ubuntu@ip-10-0-1-100:~/202301$
```
- ### check cfos deployment 
*check the deployment*

```
ubuntu@ip-10-0-1-100:~/202301$ kubectl rollout status ds/fos-deployment
daemon set "fos-deployment" successfully rolled out
```
*restart cfos ds*

```
kubectl rollout restart ds/fos-deployment && kubectl rollout status ds/fos-deployment
```
you shall see 
```
daemonset.apps/fos-deployment restarted
Waiting for daemon set "fos-deployment" rollout to finish: 1 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 1 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 2 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 2 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 2 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 2 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 2 of 3 updated pods are available...
daemon set "fos-deployment" successfully rolled out

```
*chech the cfos pod log on pod on node 10-0-2-200*

you will found the cfos is running 7.2.0.0231 version and System is ready, also a few configmap has been read into cfos include license etc.,

```
ubuntu@ip-10-0-1-100:~/202301$ kubectl logs -f po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`

System is starting...

Firmware version is 7.2.0.0231
Preparing environment...
Error: Nexthop has invalid gateway.
Starting services...
System is ready.

2023-03-15_23:31:38.03514 ok: run: /run/fcn_service/certd: (pid 261) 1s, normally down
2023-03-15_23:31:43.06185 INFO: 2023/03/15 23:31:43 received a new fos configmap
2023-03-15_23:31:43.06186 INFO: 2023/03/15 23:31:43 configmap name: foscfgfirewallpolicy, labels: map[app:fos category:config]
2023-03-15_23:31:43.06186 INFO: 2023/03/15 23:31:43 got a fos config
2023-03-15_23:31:43.06213 INFO: 2023/03/15 23:31:43 received a new fos configmap
2023-03-15_23:31:43.06214 INFO: 2023/03/15 23:31:43 configmap name: foscfgdns, labels: map[app:fos category:config]
2023-03-15_23:31:43.06214 INFO: 2023/03/15 23:31:43 got a fos config
2023-03-15_23:31:43.06584 INFO: 2023/03/15 23:31:43 received a new fos configmap
2023-03-15_23:31:43.06586 INFO: 2023/03/15 23:31:43 configmap name: fos-license, labels: map[app:fos category:license]
2023-03-15_23:31:43.06586 INFO: 2023/03/15 23:31:43 got a fos license
2023-03-15_23:31:43.06589 INFO: 2023/03/15 23:31:43 received a new fos configmap
2023-03-15_23:31:43.06589 INFO: 2023/03/15 23:31:43 configmap name: foscfgstaticdefaultroute, labels: map[app:fos category:config]
2023-03-15_23:31:43.06589 INFO: 2023/03/15 23:31:43 got a fos config
2023-03-16_00:02:51.36533 INFO: 2023/03/16 00:02:51 received a new fos configmap
2023-03-16_00:02:51.36534 INFO: 2023/03/16 00:02:51 configmap name: fos-license, labels: map[app:fos category:license]
2023-03-16_00:02:51.36534 INFO: 2023/03/16 00:02:51 got a fos license
2023-03-16_00:02:51.36538 INFO: 2023/03/16 00:02:51 received a new fos configmap
2023-03-16_00:02:51.36538 INFO: 2023/03/16 00:02:51 configmap name: foscfgstaticdefaultroute, labels: map[app:fos category:config]
2023-03-16_00:02:51.36538 INFO: 2023/03/16 00:02:51 got a fos config
2023-03-16_00:02:51.36557 INFO: 2023/03/16 00:02:51 received a new fos configmap
2023-03-16_00:02:51.36557 INFO: 2023/03/16 00:02:51 configmap name: foscfgdns, labels: map[app:fos category:config]
2023-03-16_00:02:51.36557 INFO: 2023/03/16 00:02:51 got a fos config
2023-03-16_00:02:51.36557 INFO: 2023/03/16 00:02:51 received a new fos configmap
2023-03-16_00:02:51.36558 INFO: 2023/03/16 00:02:51 configmap name: foscfgfirewallpolicy, labels: map[app:fos category:config]
2023-03-16_00:02:51.36558 INFO: 2023/03/16 00:02:51 got a fos config
```

- ### shell into cfos container 


```

ubuntu@ip-10-0-1-100:~/202301$ kubectl exec -it po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- sh
# ip route
default via 10.244.1.1 dev eth0
10.0.0.2 via 10.1.128.1 dev net1
10.1.128.0/24 dev net1 proto kernel scope link src 10.1.128.252
10.96.0.0/12 via 10.1.128.1 dev net1
10.244.0.0/16 via 10.244.1.1 dev eth0
10.244.1.0/24 dev eth0 proto kernel scope link src 10.244.1.4
```
cfos has default route from managenet network on both main routing table and cfos routing table which has id 231.

```
# ip route show table 231
default via 10.244.1.1 dev eth0
10.0.0.2 via 10.1.128.1 dev net1
10.1.128.0/24 dev net1 proto kernel scope link src 10.1.128.252
10.96.0.0/12 via 10.1.128.1 dev net1
10.244.0.0/16 via 10.244.1.1 dev eth0
10.244.1.0/24 dev eth0 proto kernel scope link src 10.244.1.4
# ip route get 1.1.1.1
1.1.1.1 via 10.244.1.1 dev eth0 table 231 src 10.244.1.4 uid 0
    cache
#
```

cfos can config static route use cfos cli/api/configmap 
 

```
# fcnsh
FOS Container (10) # show
config router static
    edit "10"
        set dst 1.2.3.4/32
        set gateway 10.244.1.1
        set device "eth0"
    next
end

FOS Container (10) # end

FOS Container # sysctl sh
# ip route get 1.2.3.4
1.2.3.4 via 10.244.1.1 dev eth0 table 231 src 10.244.1.4 uid 0
    cache
#
```

 

*check firewall policy configured on cfos*
```
FOS Container # config firewall policy

FOS Container (policy) # show
config firewall policy
    edit "3"
        set utm-status enable
        set name "pod_to_internet_HTTPS_HTTP"
        set srcintf any
        set dstintf eth0
        set srcaddr all
        set dstaddr all
        set service HTTPS HTTP PING DNS
        set ssl-ssh-profile "deep-inspection"
        set av-profile "default"
        set webfilter-profile "default"
        set ips-sensor "default"
        set nat enable
        set logtraffic all
    next
end
```
*check firewall policy by use cfos restful api*

*first let the cfos restful service is up and running in k8s, this is configured via ClusterIP.*


```
ubuntu@ip-10-0-1-100:~/202301$ kubectl get svc fos-deployment
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
fos-deployment   ClusterIP   10.100.57.107   <none>        80/TCP    19m

if you want use dns name to access fos-deployment svc , you need add dns 10.96.0.10 on your client.
10.96.0.10 is the kube-dns service ip address.

```
cat << EOF | sudo tee  /etc/resolv.conf
```
you shall see 
ubuntu@ip-10-0-1-100:~/202301$ cat << EOF | sudo tee  /etc/resolv.conf
nameserver 10.96.0.10
nameserver 127.0.0.53
options edns0 trust-ad
search cluster.local ec2.internal
EOF
```
then you can use fos-deployment.default.svc.cluster.local to access fos restful api. 

```
ubuntu@ip-10-0-1-100:~/202301$ curl http://fos-deployment.default.svc.cluster.local
welcome to the REST API server`

```

```
ubuntu@ip-10-0-1-100:~/202301/opa/demo_network_policy_1$ curl http://fos-deployment.default.svc.cluster.local/api/v2/cmdb/firewall/policy
{
  "status": "success",
  "http_status": 200,
  "path": "firewall",
  "name": "policy",
  "http_method": "GET",
  "results": [
    {
      "policyid": "3",
      "status": "enable",
      "utm-status": "enable",
      "name": "pod_to_internet_HTTPS_HTTP",
      "comments": "",
      "srcintf": [
        {
          "name": "any"
        }
      ],
      "dstintf": [
        {
          "name": "eth0"
        }
      ],
      "srcaddr": [
        {
          "name": "all"
        }
      ],
      "dstaddr": [
        {
          "name": "all"
        }
      ],
      "srcaddr6": [],
      "dstaddr6": [],
      "service": [
        {
          "name": "HTTPS"
        },
        {
          "name": "HTTP"
        },
        {
          "name": "PING"
        },
        {
          "name": "DNS"
        }
      ],
      "ssl-ssh-profile": "deep-inspection",
      "profile-type": "single",
      "profile-group": "",
      "profile-protocol-options": "default",
      "av-profile": "default",
      "webfilter-profile": "default",
      "dnsfilter-profile": "",
      "emailfilter-profile": "",
      "dlp-sensor": "",
      "file-filter-profile": "",
      "ips-sensor": "default",
      "application-list": "",
      "action": "accept",
      "nat": "enable",
      "custom-log-fields": [],
      "logtraffic": "all"
    }
  ],
  "serial": "FGVMULTM23000044",
  "version": "v7.2.0",
  "build": "231"
```



- ### check the application pod 

*application pod shall have default route point to cfos* 

*application pod shall have route to cluster via host cni0 bridge interface*


```
ubuntu@ip-10-0-1-100:~/202301$ kubectl exec -it po/`kubectl get pods -l app=multitool01 --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- sh
/ # 
/ # ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue state UP group default
    link/ether de:13:77:c6:06:48 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.244.1.3/24 brd 10.244.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::dc13:77ff:fec6:648/64 scope link
       valid_lft forever preferred_lft forever
3: net1@if8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether c2:9f:df:52:88:dd brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.1.128.2/24 brd 10.1.128.255 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::c09f:dfff:fe52:88dd/64 scope link
       valid_lft forever preferred_lft forever

/ # ip r

default via 10.1.128.252 dev net1
10.0.0.2 via 10.1.128.1 dev net1
10.1.128.0/24 dev net1 proto kernel scope link src 10.1.128.2
10.96.0.0/12 via 10.1.128.1 dev net1
10.244.0.0/16 via 10.244.1.1 dev eth0
10.244.1.0/24 dev eth0 proto kernel scope link src 10.244.1.3

/ # ping -c 1 1.1.1.1
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=51 time=1.51 ms

--- 1.1.1.1 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 1.505/1.505/1.505/0.000 ms


/ # curl -I -k https://1.1.1.1
HTTP/2 200
date: Thu, 16 Mar 2023 00:26:34 GMT
content-type: text/html
report-to: {"endpoints":[{"url":"https:\/\/a.nel.cloudflare.com\/report\/v3?s=PNXTqheu0tFbSqsnq1tBqjzYz%2Bbqded2YCtli5NuqR0Bd8eLjLwV1HIsOsyAuTnhiG1BzNY6q6P8qD0XFI0siBqb62P2B%2BoABiCWzk4o3K2fYqNQf4fqZ90%3D"}],"group":"cf-nel","max_age":604800}
nel: {"report_to":"cf-nel","max_age":604800}
last-modified: Thu, 04 Aug 2022 19:10:01 GMT
strict-transport-security: max-age=31536000
served-in-seconds: 0.002
cache-control: public, max-age=14400
cf-cache-status: HIT
age: 535
expires: Thu, 16 Mar 2023 04:26:34 GMT
set-cookie: __cf_bm=QoIspmS2HcBVjtA.A5UFrGivUSJoyMRwA_7UVri7Pw0-1678926394-0-AZboQ6II67iQwA7dBFm0NW05TP8cKCzE68cNt+YflPhp3w4DaAEsy7/zRVB7PKXUha46W4bJjieJWaxVRWbMB9U=; path=/; expires=Thu, 16-Mar-23 00:56:34 GMT; domain=.every1dns.com; HttpOnly; Secure; SameSite=None
server: cloudflare
cf-ray: 7a88dd8b090a0958-HKG
alt-svc: h3=":443"; ma=86400, h3-29=":443"; ma=86400
```

*we can also do sniff on cfos for traffic from pod to internet*

*continue ping on application pod*

```
ubuntu@ip-10-0-1-100:~/202301/opa/demo_network_policy_1$ kubectl exec -it po/`kubectl get pods -l app=multitool01 --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- ping 1.1.1.1
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=47 time=1.92 ms
64 bytes from 1.1.1.1: icmp_seq=2 ttl=47 time=1.80 ms
```
*check cfos sniff* 

```
ubuntu@ip-10-0-1-100:~/202301$ kubectl exec -it po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1` -- sh 
# fcnsh
FOS Container # diagnose sniffer packet any
interfaces=[any]
filters=[none]
count=unlimited
snaplen=1600

FOS Container # linktype = 113
0.874959 10.1.128.253 -> 1.1.1.1: icmp: echo request
0.875066 10.244.97.53 -> 1.1.1.1: icmp: echo request
0.876636 1.1.1.1 -> 10.244.97.53: icmp: echo reply
0.876707 1.1.1.1 -> 10.1.128.253: icmp: echo reply
1.876885 10.1.128.253 -> 1.1.1.1: icmp: echo request
1.877035 10.244.97.53 -> 1.1.1.1: icmp: echo request
1.878552 1.1.1.1 -> 10.244.97.53: icmp: echo reply
1.878634 1.1.1.1 -> 10.1.128.253: icmp: echo reply
1.940998 arp who-has 10.1.128.253 tell 10.1.128.252
1.941155 arp reply 10.1.128.253 is-at ba:5a:93:d8:61:44
2.878803 10.1.128.253 -> 1.1.1.1: icmp: echo request
2.878918 10.244.97.53 -> 1.1.1.1: icmp: echo request
2.880457 1.1.1.1 -> 10.244.97.53: icmp: echo reply
2.880509 1.1.1.1 -> 10.1.128.253: icmp: echo reply
3.880679 10.1.128.253 -> 1.1.1.1: icmp: echo request
3.880793 10.244.97.53 -> 1.1.1.1: icmp: echo request
3.882886 1.1.1.1 -> 10.244.97.53: icmp: echo reply
3.882974 1.1.1.1 -> 10.1.128.253: icmp: echo reply
```

*check cfos traffic log*

```
FOS Container # execute  log filter category traffic

FOS Container # execute log filter device disk

FOS Container # execute log display
date=2023-03-15 time=23:34:28 eventtime=1678923268 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.2 srcport=48344 dstip=1.1.1.1 dstport=443 sessionid=1342504490 proto=6 action="accept" policyid=3 service="HTTPS" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-03-16 time=00:26:41 eventtime=1678926401 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.2 identifier=79 dstip=1.1.1.1 sessionid=2942861595 proto=1 action="accept" policyid=3 service="ICMP" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-03-16 time=00:27:43 eventtime=1678926463 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.2 identifier=80 dstip=1.1.1.1 sessionid=163398192 proto=1 action="accept" policyid=3 service="ICMP" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0

3 logs returned.
```
*or directly cat the log file from container*

```
 
ubuntu@ip-10-0-1-100:~/202301$ kubectl exec -it po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  --  tail -f /var/log/log/traffic.0
date=2023-03-15 time=23:34:28 eventtime=1678923268 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.2 srcport=48344 dstip=1.1.1.1 dstport=443 sessionid=1342504490 proto=6 action="accept" policyid=3 service="HTTPS" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-03-16 time=00:26:41 eventtime=1678926401 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.2 identifier=79 dstip=1.1.1.1 sessionid=2942861595 proto=1 action="accept" policyid=3 service="ICMP" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-03-16 time=00:27:43 eventtime=1678926463 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.2 identifier=80 dstip=1.1.1.1 sessionid=163398192 proto=1 action="accept" policyid=3 service="ICMP" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-03-16 time=00:28:44 eventtime=1678926524 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.2 srcport=51826 dstip=1.1.1.1 dstport=443 sessionid=1434091569 proto=6 action="accept" policyid=3 service="HTTPS" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
```

- ## cfos utm feature 
*in this section, we config cfos to test web filter feature and ips feature use https traffic* 

- ### web filter feature 

```
ubuntu@ip-10-0-1-100:~/202301$ kubectl exec -it po/`kubectl get pods -l app=multitool01 --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  --  curl -k -I  https://www.eicar.org/download/eicar.com.txt
HTTP/1.1 403 Forbidden
X-Frame-Options: SAMEORIGIN
X-XSS-Protection: 1; mode=block
X-Content-Type-Options: nosniff
Content-Security-Policy: frame-ancestors 'self'
Content-Type: text/html; charset="utf-8"
Content-Length: 5211
Connection: Close
```
above you can see the access to malicious website has been blocked by cFOS, as the HTTP return code is "403 Forbidden".

- ###  Check log on cFOS
the pod that access malicious is on node ip-10-0-2.200. so we need use cFOS POD on same node to check the block log.

```
ubuntu@ip-10-0-1-100:~/202301$ kubectl exec -it po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- tail -f -n 1 /var/log/log/webf.0
date=2023-03-16 time=00:29:31 eventtime=1678926571 tz="+0000" logid="0316013056" type="utm" subtype="webfilter" eventtype="ftgd_blk" level="warning" policyid=3 sessionid=6 srcip=10.1.128.2 srcport=44832 srcintf="net1" dstip=89.238.73.97 dstport=443 dstintf="eth0" proto=6 service="HTTPS" hostname="www.eicar.org" profile="default" action="blocked" reqtype="direct" url="https://www.eicar.org/download/eicar.com.txt" sentbyte=100 rcvdbyte=0 direction="outgoing" msg="URL belongs to a denied category in policy" method="domain" cat=26 catdesc="Malicious Websites"

```
you can see that cFOS have logged the block with reason - "Maliciou Websites".

- ### ips inspect feature 

*we can use curl to generate attack traffic to target ip address, this traffic will be detected by cfos and block it* 
```
kubectl get pod | grep multi | grep -v termin | awk '{print $1}'  | while read line; do kubectl exec -t po/$line --  curl --max-time 5  -k -H "User-Agent: () { :; }; /bin/ls" https://1.1.1.1  ; done

  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:05 --:--:--     0
curl: (28) Operation timed out after 5000 milliseconds with 0 bytes received
command terminated with exit code 28
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:04 --:--:--     0
curl: (28) Operation timed out after 5000 milliseconds with 0 bytes received
command terminated with exit code 28
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:05 --:--:--     0
curl: (28) Operation timed out after 5001 milliseconds with 0 bytes received
command terminated with exit code 28

```
- ### check cfos ips block log 

```
kubectl get pod | grep fos | awk '{print $1}'  | while read line; do kubectl exec -t po/$line -- tail  /data/var/log/log/ips.0  ; done
```
you shall see 
```
 ubuntu@ip-10-0-1-100:~/202301$ kubectl get pod | grep fos | awk '{print $1}'  | while read line; do kubectl exec -t po/$line -- tail  /data/var/log/log/ips.0  ; done
date=2023-03-16 time=00:35:02 eventtime=1678926902 tz="+0000" logid="0419016384" type="utm" subtype="ips" eventtype="signature" level="alert" severity="critical" srcip=10.1.128.253 dstip=1.1.1.1 srcintf="net1" dstintf="eth0" sessionid=4 action="dropped" proto=6 service="HTTPS" policyid=3 attack="Bash.Function.Definitions.Remote.Code.Execution" srcport=41544 dstport=443 hostname="1.1.1.1" url="/" direction="outgoing" attackid=39294 profile="default" incidentserialno=161480705 msg="applications3: Bash.Function.Definitions.Remote.Code.Execution"
date=2023-03-16 time=00:34:57 eventtime=1678926897 tz="+0000" logid="0419016384" type="utm" subtype="ips" eventtype="signature" level="alert" severity="critical" srcip=10.1.128.2 dstip=1.1.1.1 srcintf="net1" dstintf="eth0" sessionid=9 action="dropped" proto=6 service="HTTPS" policyid=3 attack="Bash.Function.Definitions.Remote.Code.Execution" srcport=53376 dstport=443 hostname="1.1.1.1" url="/" direction="outgoing" attackid=39294 profile="default" incidentserialno=143654913 msg="applications3: Bash.Function.Definitions.Remote.Code.Execution"
date=2023-03-16 time=00:34:53 eventtime=1678926893 tz="+0000" logid="0419016384" type="utm" subtype="ips" eventtype="signature" level="alert" severity="critical" srcip=10.1.128.2 dstip=1.1.1.1 srcintf="net1" dstintf="eth0" sessionid=6 action="dropped" proto=6 service="HTTPS" policyid=3 attack="Bash.Function.Definitions.Remote.Code.Execution" srcport=57706 dstport=443 hostname="1.1.1.1" url="/" direction="outgoing" attackid=39294 profile="default" incidentserialno=54525953 msg="applications3: Bash.Function.Definitions.Remote.Code.Execution"
```
or use cfos console 

```
FOS Container # execute  log filter category 4

FOS Container # execute  log filter device disk


FOS Container # execute log display
date=2023-03-16 time=00:34:57 eventtime=1678926897 tz="+0000" logid="0419016384" type="utm" subtype="ips" eventtype="signature" level="alert" severity="critical" srcip=10.1.128.2 dstip=1.1.1.1 srcintf="net1" dstintf="eth0" sessionid=9 action="dropped" proto=6 service="HTTPS" policyid=3 attack="Bash.Function.Definitions.Remote.Code.Execution" srcport=53376 dstport=443 hostname="1.1.1.1" url="/" direction="outgoing" attackid=39294 profile="default" incidentserialno=143654913 msg="applications3: Bash.Function.Definitions.Remote.Code.Execution"


1 logs returned.
```

- ### clean up

logout from kubernetes master , back to your client terminal.

use `terraform destroy` to delete kubernetes cluster 

```
terraform destroy -auto-approve
```



- ## flannel network explained

```
 (src pod:10.244.1.3)-veth pair--[(cni0:10.244.1.1)-(flannel.1-10.244.1.0/32)-ens5-(10-0.2.200)]
                                                                            -vpc-subnet-[(10.0.2.0/24)
 (dst pod:10.244.2.3)-veth pair--[(cni0:10.244.2.1)-(flannel.1-10.244.2.0/32)-ens5-(10.0.2.201)]

 ```


- ### step 1. 10.244.1.3 ping 10.244.2.3, the next-hop is 10.244.1.1 
*src pod has eth0@if6 interface which connected with host interface with index 6*
*10.244.1.1 is the ip address of bridge cni0 interface which is on host, this ip is created by flannel delegate to bridge cni cbr according the flannel config 10-flannel.conflist under /etc/cni/net.d*



```
ubuntu@ip-10-0-2-200:~$ kubectl exec -it po/`kubectl get pods -l app=multitool01 --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue state UP group default
    link/ether de:13:77:c6:06:48 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.244.1.3/24 brd 10.244.1.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::dc13:77ff:fec6:648/64 scope link
       valid_lft forever preferred_lft forever
3: net1@if8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether c2:9f:df:52:88:dd brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.1.128.2/24 brd 10.1.128.255 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::c09f:dfff:fe52:88dd/64 scope link
       valid_lft forever preferred_lft forever
ubuntu@ip-10-0-2-200:~$

```

```
ubuntu@ip-10-0-2-200:~$ ip -d a | grep -e ^6: -A 3
6: vethf39c65e7@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue master cni0 state UP group default
    link/ether 66:08:0b:6c:79:42 brd ff:ff:ff:ff:ff:ff link-netns fa857895-d9fe-43e2-bd9e-cb0c494e7ff0 promiscuity 1 minmtu 68 maxmtu 65535
    veth
    bridge_slave state forwarding priority 32 cost 2 hairpin on guard off root_block off fastleave off learning on flood on port_id 0x8002 port_no 0x2 designated_port 32770 designated_cost 0 designated_bridge 8000.56:a7:7c:96:8e:7a designated_root 8000.56:a7:7c:96:8e:7a hold_timer    0.00 message_age_timer    0.00 forward_delay_timer    0.00 topology_change_ack 0 config_pending 0 proxy_arp off proxy_arp_wifi off mcast_router 1 mcast_fast_leave off mcast_flood on mcast_to_unicast off neigh_suppress off group_fwd_mask 0 group_fwd_mask_str 0x0 vlan_tunnel off isolated off numtxqueues 2 numrxqueues 2 gso_max_size 65536 gso_max_segs 65535
```
cni0 is a bridge interface with ip address 10.244.1.1 on host node, the ip address is different on each node. flannel assign this ip based on enviroment variable 
```
ubuntu@ip-10-0-2-200:~$ cat /run/flannel/subnet.env
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.1.1/24
FLANNEL_MTU=8951
FLANNEL_IPMASQ=true
```
```
ubuntu@ip-10-0-2-200:~$ ip a | grep 10.244.1.1 -B 2 -A 2
4: cni0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue state UP group default qlen 1000
    link/ether 56:a7:7c:96:8e:7a brd ff:ff:ff:ff:ff:ff
    inet 10.244.1.1/24 brd 10.244.1.255 scope global cni0
       valid_lft forever preferred_lft forever
    inet6 fe80::54a7:7cff:fe96:8e7a/64 scope link
ubuntu@ip-10-0-2-200:~$
```



```
# ip route get 10.244.2.3
10.244.2.3 via 10.244.1.1 dev eth0 table 231 src 10.244.1.3 uid 0
    cache
```

- ### step 2 arp request for 10.244.1.1 and got reply from cni0 interface on host node
```
/ # tcpdump -i eth0 arp -n -vvv
tcpdump: listening on eth0, link-type EN10MB (Ethernet), snapshot length 262144 bytes
23:53:43.274931 ARP, Ethernet (len 6), IPv4 (len 4), Request who-has 10.244.1.1 tell 10.244.1.3, length 28
23:53:43.274945 ARP, Ethernet (len 6), IPv4 (len 4), Request who-has 10.244.1.1 tell 10.244.1.3, length 28
23:53:43.274952 ARP, Ethernet (len 6), IPv4 (len 4), Reply 10.244.1.1 is-at 56:a7:7c:96:8e:7a, length 28
```

- ### step 3 src pod use this mac as dst mac send packet to host interface cni0 , host do route lookup for 10.244.2.3
*route lookup will find nexthop is tunnel interface flannel.1 which has ip 10.244.1.0/32*

```
ubuntu@ip-10-0-2-200:~$ ip route get 10.244.2.3
10.244.2.3 via 10.244.2.0 dev flannel.1 src 10.244.1.0 uid 1000
    cache

```
- ### step 4 packet arrive flannel.1 interface,then  encapsulation the traffic with vxlan and route  to other node
*no mac learning on flannel.1 is needed. a fdb entry for flannel.1 has permanent mac address configured*

*flannel.1 configured with vxlan id 1 and assocaited with interface ens5, the vxlan dst port is 8472*
```
ubuntu@ip-10-0-2-200:~$ ip -d a show dev flannel.1
3: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue state UNKNOWN group default
    link/ether ee:ed:39:ba:2e:bd brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 65535
    vxlan id 1 local 10.0.2.200 dev ens5 srcport 0 0 dstport 8472 nolearning ttl auto ageing 300 udpcsum noudp6zerocsumtx noudp6zerocsumrx numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535
    inet 10.244.1.0/32 scope global flannel.1
       valid_lft forever preferred_lft forever
    inet6 fe80::eced:39ff:feba:2ebd/64 scope link
       valid_lft forever preferred_lft forever
```
*when src pod ping dst pod. we can capture ping packet on this interface*

```
ubuntu@ip-10-0-2-200:~$ sudo tcpdump -i flannel.1 -vvv -n
tcpdump: listening on flannel.1, link-type EN10MB (Ethernet), snapshot length 262144 bytes
00:05:25.771018 IP (tos 0x0, ttl 63, id 56052, offset 0, flags [DF], proto ICMP (1), length 84)
    10.244.1.3 > 10.244.2.3: ICMP echo request, id 54, seq 12, length 64
00:05:25.771246 IP (tos 0x0, ttl 63, id 24692, offset 0, flags [none], proto ICMP (1), length 84)
    10.244.2.3 > 10.244.1.3: ICMP echo reply, id 54, seq 12, length 64

```

- ### step 5 ens5 route  traffic to node 10.0.2.201
*tcpdump on this interface will show vxlan*

```
ubuntu@ip-10-0-2-200:~$ sudo tcpdump -i ens5 -vvv -n 'udp 8472'
tcpdump: can't parse filter expression: syntax error
ubuntu@ip-10-0-2-200:~$ sudo tcpdump -i ens5 -vvv -n 'udp port 8472'
tcpdump: listening on ens5, link-type EN10MB (Ethernet), snapshot length 262144 bytes
00:10:11.979005 IP (tos 0x0, ttl 64, id 26988, offset 0, flags [none], proto UDP (17), length 134)
    10.0.2.200.43625 > 10.0.2.201.8472: [bad udp cksum 0x1a14 -> 0x4963!] OTV, flags [I] (0x08), overlay 0, instance 1
IP (tos 0x0, ttl 63, id 28578, offset 0, flags [DF], proto ICMP (1), length 84)
    10.244.1.3 > 10.244.2.3: ICMP echo request, id 57, seq 268, length 64
00:10:11.979218 IP (tos 0x0, ttl 64, id 12372, offset 0, flags [none], proto UDP (17), length 134)
    10.0.2.201.57002 > 10.0.2.200.8472: [udp sum ok] OTV, flags [I] (0x08), overlay 0, instance 1
IP (tos 0x0, ttl 63, id 61040, offset 0, flags [none], proto ICMP (1), length 84)
    10.244.2.3 > 10.244.1.3: ICMP echo reply, id 57, seq 268, length 64
```
