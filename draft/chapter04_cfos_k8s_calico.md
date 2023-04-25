- ## Task Create cFOS for egress security in self managed kubernetes with Calcio and bridge CNI 


- ## Description


This chapter will guide you through setting up cFOS on an EKS cluster with `Calico CNI ` and `Brdige CNI`. The application pod will use an additional network to communicate with cFOS. Multus CNI is required to create and manage the additional network.

In this chapter, we will demonstrate how to set up cFOS to use an additional network to route traffic from two applications to the internet. We use Multus CNI to manage the additional network for traffic between cFOS and the application pod. `Bridge CNI` is utilized as the actual CNI for the secondary network. In this setup, the application pod's IP address is visible to cFOS.  We also demonstrate how cFOS can detect malicious URLs from the application pod to the internet, even when the traffic is HTTPS-based.




- ## Network Diagram


```
+---------------+   eth0    +--------------+  eth0 (SNAT)           
| Application   +---------->|    cFOS      |--------------  internet 
| Pod           |Calico CNI |              |  
+               +           +              +          
|               |   net1    |  DaemonSet   | 
|               +---------->|              |
|               |Bridge CNI |              |
+---------------+           +--------------+ 

Cluster POD to POD Traffic: eth0 (Application Pod) <--> eth0 (cFOS Pod)
Internet Traffic: Application Pod ---> net1 (cFOS Pod) ---> eth0 (sNAT enabled) ---> Internet  

The eth0 interfaces are managed by Multus with delegation to `Calico CNI`, and the net1 interfaces are managed by Multus with delegation to `Bridge CNI`

```

both the Application POD and cFOS POD have two interfaces: eth0 and net1. The eth0 interfaces are managed by Multus with delegation to `Calico cni`, and the net1 interfaces are managed by Multus with delegation to `Bridge CNI` . The application POD communicates with the cFOS POD using the net1 interface. The traffic from the Application POD to the internet is routed through the cFOS POD, with SNAT enabled on the cFOS eth0 interface.


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
- ## install calico

*this section will install tigera operator to install other calico crd, then install cr(customer resource), we also modify cr with necessary change such as cidr etc*

The Calico Tigera Operator is a Kubernetes operator designed to simplify the installation and management of the Calico networking and network policy solution on Kubernetes clusters. Calico is an open-source networking and network policy solution for Kubernetes and other cloud-native platforms.

The Calico Tigera Operator automates the deployment of Calico on Kubernetes, which can be complex and time-consuming to do manually. The operator uses a declarative configuration model, which allows you to define the desired state of your Calico deployment, and the operator will ensure that the actual state matches the desired state.

`calictl` is a command-line tool that allows you to interact with Calico to manage networking and network security policies on a Kubernetes cluster. this is optional. but will be useful for throubleshooting. 

Custom resources are extensions to the Kubernetes API that allow you to define and use resources beyond the built-in resources that come with Kubernetes. Calico uses custom resources to provide additional functionality beyond what is available with standard Kubernetes resources.

We need to modify Custom resources to enable **containerIPForwarding** and also change **podCIDR** to match cluster podCIDR configuration. 

for detail about Custom resources spec. use `kubectl explain Installation.spec`. 

copy and paste below script to your terminal to download yaml file and install tigera operator from yaml file.

```
sudo curl -fL https://github.com/projectcalico/calico/releases/latest/download/calicoctl-linux-amd64 -o /usr/local/bin/calicoctl
sudo chmod +x /usr/local/bin/calicoctl
curl -fLO https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/tigera-operator.yaml
kubectl create -f tigera-operator.yaml
```
you shall see output

```
namespace/tigera-operator created
customresourcedefinition.apiextensions.k8s.io/bgpconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgppeers.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/blockaffinities.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/caliconodestatuses.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/clusterinformations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/felixconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/hostendpoints.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamblocks.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamconfigs.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamhandles.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ippools.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipreservations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/kubecontrollersconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/apiservers.operator.tigera.io created
customresourcedefinition.apiextensions.k8s.io/imagesets.operator.tigera.io created
customresourcedefinition.apiextensions.k8s.io/installations.operator.tigera.io created
customresourcedefinition.apiextensions.k8s.io/tigerastatuses.operator.tigera.io created
serviceaccount/tigera-operator created
clusterrole.rbac.authorization.k8s.io/tigera-operator created
clusterrolebinding.rbac.authorization.k8s.io/tigera-operator created
deployment.apps/tigera-operator created
```

copy and paste below script to your terminal to install calico 


```
cat << EOF | kubectl create -f - 
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Configures Calico networking.
  calicoNetwork:
    bgp: Disabled
    containerIPForwarding: Enabled
    # Note: The ipPools section cannot be modified post-install.
    ipPools:
    - blockSize: 24
      cidr: 10.244.0.0/16
      encapsulation: VXLAN
      natOutgoing: Enabled
      nodeSelector: all()
---
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF
```

you shall see output
```
installation.operator.tigera.io/default created
apiserver.operator.tigera.io/default created
```


- ### check calico installation 
it will take a while to install calico , you can use below command to check the readiness 

use `kubectl get node -o json | jq .items[].metadata.annotations` to check the annotations added by calico , you can find podCIDR for each node.

use `kubectl get installation default -o yaml` to check the Custome resources installed by calico 

use `kubectl get all -n calico-system` to check calico resources is up and running 

use `kubectl get all -n calico-apiserver` to check api server is up and running 

use `sudo calicoctl node status` to check the  calico status and networking 


below is the output of a ready installation 
```
ubuntu@ip-10-0-1-100:~$ kubectl get node -o json | jq .items[].metadata.annotations
{
  "csi.volume.kubernetes.io/nodeid": "{\"csi.tigera.io\":\"ip-10-0-2-200\"}",
  "kubeadm.alpha.kubernetes.io/cri-socket": "unix:///var/run/crio/crio.sock",
  "node.alpha.kubernetes.io/ttl": "0",
  "projectcalico.org/IPv4Address": "10.0.2.200/24",
  "projectcalico.org/IPv4VXLANTunnelAddr": "10.244.97.0",
  "volumes.kubernetes.io/controller-managed-attach-detach": "true"
}
{
  "csi.volume.kubernetes.io/nodeid": "{\"csi.tigera.io\":\"ip-10-0-2-201\"}",
  "kubeadm.alpha.kubernetes.io/cri-socket": "unix:///var/run/crio/crio.sock",
  "node.alpha.kubernetes.io/ttl": "0",
  "projectcalico.org/IPv4Address": "10.0.2.201/24",
  "projectcalico.org/IPv4VXLANTunnelAddr": "10.244.93.0",
  "volumes.kubernetes.io/controller-managed-attach-detach": "true"
}
{
  "csi.volume.kubernetes.io/nodeid": "{\"csi.tigera.io\":\"ip1001100\"}",
  "kubeadm.alpha.kubernetes.io/cri-socket": "unix:///var/run/crio/crio.sock",
  "node.alpha.kubernetes.io/ttl": "0",
  "projectcalico.org/IPv4Address": "10.0.1.100/24",
  "projectcalico.org/IPv4VXLANTunnelAddr": "10.244.6.0",
  "volumes.kubernetes.io/controller-managed-attach-detach": "true"
}

ubuntu@ip-10-0-1-100:~$ kubectl get all -n calico-apiserver
NAME                                   READY   STATUS    RESTARTS   AGE
pod/calico-apiserver-87cfcf4f7-fjzfz   1/1     Running   0          95s
pod/calico-apiserver-87cfcf4f7-shkv8   1/1     Running   0          95s

NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/calico-api   ClusterIP   10.104.148.221   <none>        443/TCP   95s

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/calico-apiserver   2/2     2            2           95s

NAME                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/calico-apiserver-87cfcf4f7   2         2         2       96s


ubuntu@ip-10-0-1-100:~$ sudo calicoctl node status
Calico process is running.

The BGP backend process (BIRD) is not running.


```

- ## install  multus with multus-conf-file set to manual  
*this section install multus cni but will not config to use multus as the default cni yet before we create multus crd*

Multus CNI is a Container Network Interface (CNI) plugin for Kubernetes that allows multiple network interfaces to be attached to a Kubernetes pod. This means that a pod can have multiple network interfaces, each with its own IP address, and can communicate with different networks simultaneously. 

When installing Multus CNI for Kubernetes, the multus-conf-file parameter by default set with the value "auto" which  means that Multus will automatically detect the configuration file to use.
The configuration file specifies how Multus CNI should operate and which network interfaces should be created for the pods. By default, Multus looks for a configuration file in the directory /etc/cni/net.d/ and uses the first configuration file it finds. If no configuration file is found, Multus uses a default configuration. 

We can config cni for Multus to use manually, so we change the **"auto" to 70-multus.conf**. the 70-multus.conf often will not become the first CNI for kubernetes if you already have installed calico or flannel etc other CNI. By default, the 70-multus.conf file includes bridge , loopback CNI, we do not need that.  

we can manually pull multu-cni installation package beforehand if you have a slow network or we can directly clone it from internent and install it with kubectl 

there is a multus-daemonset configuration file already placed in the /home/ubuntu directory. which file use 3.9.3 stable release of multus image which is copied directly from multus github website. 

```
sudo crictl pull ghcr.io/k8snetworkplumbingwg/multus-cni:stable 
cd /home/ubuntu
sudo sed -i 's/multus-conf-file=auto/multus-conf-file=\/tmp\/multus-conf\/70-multus.conf/g' /home/ubuntu/multus-daemonset.yml
cat /home/ubuntu/multus-daemonset.yml | kubectl apply -f -
```
you shall see below output
```
Image is up to date for ghcr.io/k8snetworkplumbingwg/multus-cni@sha256:b228057275949471dc5751fd9e06839200d94f00f198d75b9052576d7ea0fdc5
customresourcedefinition.apiextensions.k8s.io/network-attachment-definitions.k8s.cni.cncf.io created
clusterrole.rbac.authorization.k8s.io/multus created
clusterrolebinding.rbac.authorization.k8s.io/multus created
serviceaccount/multus created
configmap/multus-cni-config created
daemonset.apps/kube-multus-ds created
```

- ### check the multus installation 

```
kubectl get ds kube-multus-ds -n kube-system && kubectl logs ds/kube-multus-ds -n kube-system 
```
you shall see below output

```
NAME             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
kube-multus-ds   3         3         3       3            3           <none>          59s
Found 3 pods, using pod/kube-multus-ds-vg7k7
Defaulted container "kube-multus" out of: kube-multus, install-multus-binary (init)
2023-04-04T02:38:09+00:00 Entering sleep (success)...

```

- ### check cni configuration 

the default directory for cni config is under by default /etc/cni/net.d. 

```
ubuntu@ip-10-0-1-100:~$ ls /etc/cni/net.d
10-calico.conflist  200-loopback.conf  70-multus.conf  calico-kubeconfig  multus.d
```

the file with extension name **.conf** or **.conflist** will be parsed by crio. 
The file with the highest priority for the CRI-O runtime is the one with the lowest alphabetically prefix in its filename. In this case, the file with the highest priority would be "10-calico.conflist".

The alphabetically prefix in the filename is used by CNI plugins to determine the order in which the plugin configurations are applied. A lower alphabetically prefix indicates higher priority, and hence, the configuration in the file with the lowest alphabetically prefix (in this case, 10) will be applied first, followed by the configuration in the file with the next lowest alphabetically prefix, and so on.

the ".conf" file extension is used for a single CNI plugin configuration file, while the ".conflist" file extension is used for a list of CNI plugin configurations.

the 10-calico.conf has name "k8s-pod-network" 
```
ubuntu@ip-10-0-1-100:/etc/cni/net.d$ cat 10-calico.conflist  | grep name
  "name": "k8s-pod-network",
```
since 10-calico.conflist has highest priority. so it shall be picked up by crio. so although multus has installed. but the default cni for kubernetes is still the calico. 

you can check crio log to confirm this with `journalctl -u crio  | grep "Updated default CNI network name to "  | tail -n 1`

``` 
ubuntu@ip-10-0-1-100:/etc/cni/net.d$ journalctl -u crio  | grep "Updated default CNI network name to "  | tail -n 1
Mar 14 01:34:22 ip-10-0-1-100 crio[1675]: time="2023-03-14 01:34:22.467251630Z" level=info msg="Updated default CNI network name to k8s-pod-network"
ubuntu@ip-10-0-1-100:/etc/cni/net.d$

```

- ### create multus configuration and make multus become the default CNI for crio
*this section we  create multus cni config as the default cni also config it to delegate to multus crd object, the crd object will reference to json cni config on each of the node*

we need create two configuration that related with multus, first we need to create a multus crd with cni json config on each node  for multus cni  to delegates with. then we create multus cni config for crio to use it as the default cni .  after done these ,the order of cni operation for crio will become 

**pod request ---> k8s API--- crio --- multus cni ---- multu-crd with calico json config on each node**

first  we create net-calico.conf with name net-calico and place it under /etc/cni/multus/netd.conf/ , this config file will be read by multus crd. 
then we create multus crd to use net-calico.conf on each node. multus crd use key name to reference net-calico.conf on each node
finally, we create 00-multus.conf under /etc/cni/net.d for crio to pick as the default cni for kubernetes.


- ### create directory /etc/cni/multus/net.d  on each node 

this is the default directory for multus to fetch configuration. multus ds read config from this directory  automatically , there is no need to restart ds or do other config. 
first we need to create directory , by default, the directory is not exist. since crio is running on each node. so we need to do this on all nodes.

paste below to your terminal 

```
for node in 10.0.2.200 10.0.2.201 10.0.1.100; do
ssh -o "StrictHostKeyChecking=no" -i  ~/.ssh/id_ed25519cfoslab ubuntu@$node  sudo mkdir -p /etc/cni/multus/net.d
done
```

- ### create multus crd object  on master node
**the name is net-calico** 

paste below to your terminal 

```
cat << EOF | kubectl apply -f -
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: net-calico
  namespace: kube-system
EOF
```
you shall see 
```
networkattachmentdefinition.k8s.cni.cncf.io/net-calico created
```

- ### create net-calico cni config under /etc/cni/multus/net.d on each worker node 
the net-calico.conf has name **"net-calico"** which match the crd net-attach-def (NetworkAttachmentDefinition) name, we also config to use host-local ipam and config different subnet range for pods on each node.  

paste below script on your termial to create cni config. 
```
nodes=("10.0.1.100" "10.0.2.200" "10.0.2.201")
cidr=("10.244.6" "10.244.97" "10.244.93")
for i in "${!nodes[@]}"; do
ssh -o "StrictHostKeyChecking=no" -i  ~/.ssh/id_ed25519cfoslab ubuntu@"${nodes[$i]}" << EOF 
cat << INNEREOF | sudo tee /etc/cni/multus/net.d/net-calico.conf
{
  "cniVersion": "0.3.1",
  "name": "net-calico",
  "type": "calico",
  "datastore_type": "kubernetes",
  "mtu": 0,
  "nodename_file_optional": false,
  "log_level": "Info",
  "log_file_path": "/var/log/calico/cni/cni.log",
  "ipam": {
    "type": "host-local",
    "ranges": [
       [
         {
           "subnet": "${cidr[$i]}.0/24",
           "rangeStart": "${cidr[$i]}.150",
           "rangeEnd": "${cidr[$i]}.250"
         }
       ]
    ]
  },
  "container_settings": {
      "allow_ip_forwarding": true
  },
  "policy": {
      "type": "k8s"
  },
  "kubernetes": {
      "k8s_api_root":"https://10.96.0.1:443",
      "kubeconfig": "/etc/cni/net.d/calico-kubeconfig"
  }
}
INNEREOF
EOF
done
```

- ### create 00-multus.conf under /etc/cni/net.d on each node 

00-multus.conf has the lowest alphabetically order, so it will become the first CNI for crio. after create this file. the kubernetes cluster will not longer use 10-calico.conf 

we need to  create 00-multus.conf on each node. multus delegates to other cni based on multus crd config.

in 00-multus.conf ,  "clusterNetwork" and "defaultNetworks" fields are used to define the networking configuration for Kubernetes pods.

The "clusterNetwork" field specifies the name of the network that Kubernetes uses for internal cluster communication. This network is typically used for Kubernetes services, which provide a stable IP address and DNS name for accessing pods. The value of this field must match the name of a network plugin that has been installed on the cluster, such as net-calico 

The "defaultNetworks" field is used to specify a list of additional network plugins that should be used for the default network configuration of pods. When a pod is created, it will automatically be assigned one of these networks as its primary network. This allows pods to be connected to multiple networks simultaneously.

since we do not want add additional network for all pod in this cluster automatically. we do not config "defaultNetworks".  but just config **"clusterNetwork"** as pod in this cluster will need to have a clsuter network. 

this cni config has name **"multus-cni-network"**

if we run into issue . we can change logLevel to debug for more verbose information.

```
for node in 10.0.2.200 10.0.2.201 10.0.1.100; do
ssh -o "StrictHostKeyChecking=no" -i  ~/.ssh/id_ed25519cfoslab ubuntu@$node << EOF
cat << INNER_EOF | sudo tee /etc/cni/net.d/00-multus.conf
{
  "name": "multus-cni-network",
  "type": "multus",
  "confDir": "/etc/cni/multus/net.d",
  "cniDir": "/var/lib/cni/multus",
  "binDir": "/opt/cni/bin",
  "logFile": "/var/log/multus.log",
  "logLevel": "info",
  "capabilities": {
    "portMappings": true
  },
  "clusterNetwork": "net-calico",
  "defaultNetworks": [],
  "delegates": [],
  "kubeconfig": "/etc/cni/net.d/multus.d/multus.kubeconfig"
}
INNER_EOF
EOF
done
``` 

- ### check crio log on each node
we can use `journalctl -f -u crio | grep 'Updated default CNI network name' ` to confirm that crio have picked up the multus-cni-network as the default network.

```
ubuntu@ip-10-0-1-100:/etc/cni/net.d$ journalctl -f -u crio | grep 'Updated default CNI network name'
Mar 13 02:46:54 ip-10-0-1-100 crio[2449]: time="2023-03-13 02:46:54.059049524Z" level=info msg="Updated default CNI network name to multus-cni-network"
Mar 13 02:46:54 ip-10-0-1-100 crio[2449]: time="2023-03-13 02:46:54.132076903Z" level=info msg="Updated default CNI network name to multus-cni-network"
```

- ### verify multus now delegates to net-calico cni for default cluster network 
we can create a deployment without using any annotations to check whether default cluster newtork works.
below you will see that pod get network from kube-system/net-calico
```
kubectl create deployment normal --image=praqma/network-multitool --replicas=3 && kubectl rollout status deployment normal &&  kubectl get pod
```
you shall see output 
```
ubuntu@ip-10-0-1-100:~$ kubectl create deployment normal --image=praqma/network-multitool --replicas=3 && kubectl rollout status deployment normal &&  kubectl get pod
deployment.apps/normal created
Waiting for deployment "normal" rollout to finish: 0 of 3 updated replicas are available...
Waiting for deployment "normal" rollout to finish: 1 of 3 updated replicas are available...
Waiting for deployment "normal" rollout to finish: 2 of 3 updated replicas are available...
deployment "normal" successfully rolled out
NAME                      READY   STATUS    RESTARTS   AGE
normal-6965c788cf-bh55t   1/1     Running   0          2s
normal-6965c788cf-flxpb   1/1     Running   0          2s
normal-6965c788cf-lc5xw   1/1     Running   0          2s

```

- ### delete deployment normal

```
kubectl delete deployment normal
```


- ###  create network "default-calico" under /etc/cni/multus/net.d on each node 

create default-calico multus crd with cni config under /etc/cni/multus/net.d on each node with different pod ip address range  for application that want to route traffic to cfos 

this step is **optional**, POD can directly use net-calico crd for default networking. here we just show that we can create multiple default cluster network. and let application to choose which default network. with this approach. we need keep original pod/cluster configuration not impacted at all. only those application that want route traffic to cfos will using new default network based on the annotations.

we do not want a default route from this network. so we remove the default route from this cni configuration below,but we added two specif route.

the crd has name "default-calico" and the cni config on each node has same name but with different PODCIDR address.

 
```
cat << EOF | kubectl apply -f - 
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: default-calico
  namespace: kube-system
EOF

```
*default-calico cni under /etc/cni/multus/net.d on each node*

paste below on master node 
```
nodes=("10.0.1.100" "10.0.2.200" "10.0.2.201")
cidr=("10.244.6" "10.244.97" "10.244.93")
for i in "${!nodes[@]}"; do
ssh -o "StrictHostKeyChecking=no" -i  ~/.ssh/id_ed25519cfoslab ubuntu@"${nodes[$i]}" << EOF
cat << INNEREOF | sudo tee /etc/cni/multus/net.d/default-calico.conf
{
  "cniVersion": "0.3.1",
  "name": "default-calico",
  "type": "calico",
  "datastore_type": "kubernetes",
  "mtu": 0,
  "nodename_file_optional": false,
  "log_level": "Info",
  "log_file_path": "/var/log/calico/cni/cni.log",
  "ipam": {
    "type": "host-local",
    "ranges": [
       [
         {
           "subnet": "${cidr[$i]}.0/24", 
           "rangeStart": "${cidr[$i]}.50",
           "rangeEnd": "${cidr[$i]}.100"
         }
       ]
    ],
   "routes": [
      { "dst": "10.96.0.0/12" },
      { "dst": "10.0.0.0/8" }
   ]
  },
  "container_settings": {
      "allow_ip_forwarding": true
  },
  "policy": {
      "type": "k8s"
  },
  "kubernetes": {
      "k8s_api_root":"https://10.96.0.1:443",
      "kubeconfig": "/etc/cni/net.d/calico-kubeconfig"
  }
}
INNEREOF
EOF
done

```

- ## show how POD can attach to different network 
*this section we show how to create a pod use default cluster-network, then use annotations to change the default network and then use annotations to add additional network*

- ###  creaete a pod attach to  default cluster network to net-calico 

we create an deployment without using annotations. then POD will be assigned with default cluster network configuration by multus. which is net-calico. 
the net-calico do not have any confiugration about route entry. so POD in this network will have default route . which is 169.254.1.1 for calico CNI.

```
kubectl create deployment normal --image=praqma/network-multitool --replicas=3 && kubectl rollout status deployment normal
```
you shall see 

```
deployment.apps/normal created
Waiting for deployment "normal" rollout to finish: 0 out of 3 new replicas have been updated...
Waiting for deployment "normal" rollout to finish: 0 of 3 updated replicas are available...
Waiting for deployment "normal" rollout to finish: 1 of 3 updated replicas are available...
Waiting for deployment "normal" rollout to finish: 2 of 3 updated replicas are available...
deployment "normal" successfully rolled out
```
check the ip routing table of the pod 
```
podname=$(kubectl get pod -l app=normal -o jsonpath='{.items[0].metadata.name}') && kubectl exec -it po/$podname -- ip route
kubectl exec -it po/$podname -- ip route
```
you shall see that the default route is point to 169.254.1.1 which is installed by calico crd net-calico
```
default via 169.254.1.1 dev eth0
169.254.1.1 dev eth0 scope link
```
- ### use annotations to change pod's default network to default-calico 

use kubectl patch to config deployment with new network "default-calico" by add annotations to metadata field, this network have removed default route for pod

```
kubectl patch deployment normal  -p '{"spec": {"template":{"metadata":{"annotations":{"v1.multus-cni.io/default-network":"[{\"name\": \"default-calico\"}]"}}}}}'
```

then check the routing table again

```
podname=$(kubectl get pod -l app=normal -o jsonpath='{.items[0].metadata.name}') && kubectl exec -it po/$podname -- ip route
```
you shall see that default route is gone, but two specific route being installed per default-calico crd configuration. 

```
10.0.0.0/8 via 169.254.1.1 dev eth0
10.96.0.0/12 via 169.254.1.1 dev eth0
169.254.1.1 dev eth0 scope link
```
you can check the annotation which indicate that applied annotations on the normal deployment 

```
podname=$(kubectl get pod -l app=normal -o jsonpath='{.items[0].metadata.name}') && kubectl describe po/$podname 
...
Name:             normal-7cd6974c5c-t4hfq
Namespace:        default
Priority:         0
Service Account:  default
Node:             ip1001100/10.0.1.100
Start Time:       Mon, 13 Mar 2023 00:18:08 +0000
Labels:           app=normal
                  pod-template-hash=7cd6974c5c
Annotations:      cni.projectcalico.org/containerID: 62d6132c27c7a648ed2a7e9b453969f470b3928232ce9e0059092021bc436bf9
                  cni.projectcalico.org/podIP: 10.244.6.51/32
                  cni.projectcalico.org/podIPs: 10.244.6.51/32
                  k8s.v1.cni.cncf.io/network-status:
                    [{
                        "name": "kube-system/default-calico",
                        "ips": [
                            "10.244.6.51"
                        ],
                        "default": true,
                        "dns": {}
                    }]
                  k8s.v1.cni.cncf.io/networks-status:
                    [{
                        "name": "kube-system/default-calico",
                        "ips": [
                            "10.244.6.51"
                        ],
                        "default": true,
                        "dns": {}
                    }]
                  v1.multus-cni.io/default-network: [{"name": "default-calico"}]
Status:           Running
IP:               10.244.6.51
...

```


- ## create multus secondary network crd  with bridge cni json config  
this crd will assign a secondary network to the pod that attached to. both application pod and cFOS will attached to this network later on. so application POD can send traffic to cFOS via this network. "ipMasq" is disabled , so POD IP address is visible to cFOS. in this CRD. we also ask two route 10.96.0.0/12 and 10.0.0.2/32 with nexthop point to host Ip address 10.1.128.1. 

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
- ### patch normal deployment to use secondary bridge network and add a default route 

```
kubectl patch deployment normal -p '{"spec": {"template":{"metadata":{"annotations":{"k8s.v1.cni.cncf.io/networks":"[{\"name\": \"cfosdefaultcni5\", \"default-route\": [\"10.1.128.2\"]}]"}}}}}'
```

you will see the pod now has a default route point to secondary network which is 10.1.128.2 via net1 interface.
```
podname=$(kubectl get pod -l app=normal -o jsonpath='{.items[0].metadata.name}') && kubectl exec -it  po/$podname -- ip route 
 
```
you shall see 
```
default via 10.1.128.2 dev net1
10.0.0.0/8 via 169.254.1.1 dev eth0
10.0.0.2 via 10.1.128.1 dev net1
10.1.128.0/24 dev net1 proto kernel scope link src 10.1.128.2
10.96.0.0/12 via 10.1.128.1 dev net1
10.96.0.0/12 via 169.254.1.1 dev eth0
169.254.1.1 dev eth0 scope link
```

check the interface ip address of this POD
```
podname=$(kubectl get pod -l app=normal -o jsonpath='{.items[0].metadata.name}') && kubectl exec -it  po/$podname -- ip -4 address 
``` 
you shall see a net1 interface is assigned to this POD
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
3: eth0@if13: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue state UP group default  link-netnsid 0
    inet 10.244.97.51/32 scope global eth0
       valid_lft forever preferred_lft forever
4: net1@if15: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default  link-netnsid 0
    inet 10.1.128.2/24 brd 10.1.128.255 scope global net1
       valid_lft forever preferred_lft forever

```
- ### delete normal deployment 

``` 
  kubectl delete deployment normal 

```



- ## create storage for persistent cFOS configuration 

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
EOF
```
- ## create clusterRole for cFOS to read configmap and imagePull secret 
```
cat << EOF | kubectl apply -f -
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
- ### use  configmap to create config of static route, firewall policy and dns config  for cFOS to read. 
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


- ## deploy cfos daemonSet with new defaultNetwork and secondaryNetwork
*cfos use annotations to specify default-network to "default-calico, and additional network to cfosdefaultcni5 crd*

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
        v1.multus-cni.io/default-network: default-calico
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
- ### check cfos deployment 

```
kubectl rollout status ds/fos-deployment  && kubectl get pod -l app=fos
```
you shall see
```
daemon set "fos-deployment" successfully rolled out
NAME                   READY   STATUS    RESTARTS   AGE
fos-deployment-87l7v   1/1     Running   0          75s
fos-deployment-jn6xj   1/1     Running   0          75s
fos-deployment-p2m8p   1/1     Running   0          75s

```
- ### restart cFOS DS
```
by default, cFOS will not install sNAT entry in iptables even configmap already has config. we have to restart cFOS DS to install the sNAT entry 
```

```
kubectl rollout restart ds/fos-deployment && kubectl rollout status ds/fos-deployment  && kubectl get pod -l app=fos
```
you shall see 
```
daemonset.apps/fos-deployment restarted
Waiting for daemon set "fos-deployment" rollout to finish: 0 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 0 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 1 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 1 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 1 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 1 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 2 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 2 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 2 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 2 out of 3 new pods have been updated...
Waiting for daemon set "fos-deployment" rollout to finish: 2 of 3 updated pods are available...
daemon set "fos-deployment" successfully rolled out
NAME                   READY   STATUS    RESTARTS   AGE
fos-deployment-4jcdw   1/1     Running   0          1s
fos-deployment-s9bzz   1/1     Running   0          34s
fos-deployment-trc6m   1/1     Running   0          67s

```

check the cfos pod log on pod on node 10-0-2-200

you will found the cfos is running 7.2.0.0231 version and System is ready, also a few configmap has been read into cfos include license etc.,

```
kubectl logs -f po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`
```
you shall see
```
System is starting...

Firmware version is 7.2.0.0231
Preparing environment...
RTNETLINK answers: File exists
Starting services...
System is ready.

2023-04-04_03:15:15.15749 ok: run: /run/fcn_service/certd: (pid 299) 0s, normally down
2023-04-04_03:15:20.22868 INFO: 2023/04/04 03:15:20 received a new fos configmap
2023-04-04_03:15:20.22869 INFO: 2023/04/04 03:15:20 configmap name: foscfgstaticdefaultroute, labels: map[app:fos category:config]
2023-04-04_03:15:20.22869 INFO: 2023/04/04 03:15:20 got a fos config
2023-04-04_03:15:20.22869 INFO: 2023/04/04 03:15:20 received a new fos configmap
2023-04-04_03:15:20.22870 INFO: 2023/04/04 03:15:20 configmap name: foscfgdns, labels: map[app:fos category:config]
2023-04-04_03:15:20.22870 INFO: 2023/04/04 03:15:20 got a fos config
2023-04-04_03:15:20.22870 INFO: 2023/04/04 03:15:20 received a new fos configmap
2023-04-04_03:15:20.22870 INFO: 2023/04/04 03:15:20 configmap name: foscfgfirewallpolicy, labels: map[app:fos category:config]
2023-04-04_03:15:20.22870 INFO: 2023/04/04 03:15:20 got a fos config
2023-04-04_03:15:20.22870 INFO: 2023/04/04 03:15:20 received a new fos configmap
2023-04-04_03:15:20.22870 INFO: 2023/04/04 03:15:20 configmap name: fos-license, labels: map[app:fos category:license]
2023-04-04_03:15:20.22870 INFO: 2023/04/04 03:15:20 got a fos license

```

- ### shell into cfos container to check route 

```
kubectl exec -it po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- ip route

```
cfos do not have default route on main routing table.  

```
ubuntu@ip-10-0-1-100:~$ kubectl exec -it po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- ip route
10.0.0.0/8 via 169.254.1.1 dev eth0
10.0.0.2 via 10.1.128.1 dev net1
10.1.128.0/24 dev net1 proto kernel scope link src 10.1.128.252
10.96.0.0/12 via 10.1.128.1 dev net1
10.96.0.0/12 via 169.254.1.1 dev eth0
169.254.1.1 dev eth0 scope link
```
instead ,it will install the default route on table 231. this is configured by cfos static route via configmap.
```
kubectl exec -it po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- ip route show table 231
```
```
default via 169.254.1.1 dev eth0 metric 10
10.0.0.0/8 via 169.254.1.1 dev eth0
10.0.0.2 via 10.1.128.1 dev net1
10.1.128.0/24 dev net1 proto kernel scope link src 10.1.128.252
10.96.0.0/12 via 10.1.128.1 dev net1
169.254.1.1 dev eth0 scope link
```

we can check this from cFOS cli 

```
kubectl exec -it po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1` -- fcnsh
```

you can use "show route static" to check  the configuration 
```
FOS Container # show router static
config router static
    edit "1"
        set gateway 169.254.1.1
        set device "eth0"
    next
end
```


so cfos container can reach internet, we can go back from cfos console via `sysctl sh` to container shell to do this

```
FOS Container # sysctl sh
# ip route get 1.1.1.1
1.1.1.1 via 169.254.1.1 dev eth0 table 231 src 10.244.97.53 uid 0
    cache
# ping -c 1 1.1.1.1
PING 1.1.1.1 (1.1.1.1): 56 data bytes
64 bytes from 1.1.1.1: seq=0 ttl=48 time=1.753 ms

--- 1.1.1.1 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 1.753/1.753/1.753 ms
```
check firewall policy configured on cfos
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
you can also use cFOS restful API to config firewall policy. 
cFOS deployed a cluster-IP svc with port 80. 
 
```
kubectl get svc fos-deployment
```

you shall see 
```
NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
fos-deployment   ClusterIP   10.100.57.107   <none>        80/TCP    19m
```

the svc has domain name fos-deployment.default.svc.cluster.local which can be resolved by DNS kube-dns which has IP 10.96.0.10.

we can config master node to use this DNS server to resolve cFOS svc name. 

```
cat << EOF | sudo tee  /etc/resolv.conf
nameserver 10.96.0.10
nameserver 127.0.0.53
options edns0 trust-ad
search cluster.local ec2.internal
EOF
```

then you can use fos-deployment.default.svc.cluster.local to access fos restful api. 

```
curl http://fos-deployment.default.svc.cluster.local
```

you will see that cFOS reponse with 
```
welcome to the REST API server`
```


retrive the firewall policy use API.

```
 curl http://fos-deployment.default.svc.cluster.local/api/v2/cmdb/firewall/policy
```

you shall see 

```
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
  }
```


- ### create demo application deployment  
*this application pod use default-network "default-calico", and also attached to secondary network "cfosdefaultcni5"*

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
        v1.multus-cni.io/default-network: default-calico
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

- ### check the application pod 

*application pod shall have default route point to cfos* 

*application pod shall have route to cluster via 169.254.1.1*

```
 kubectl exec -it po/`kubectl get pods -l app=multitool01 --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- ip address
 ```
 you shall see the application pod have additional interface "net1"
```
 # ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
3: eth0@if11: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue state UP group default
    link/ether f2:da:87:c5:92:46 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.244.97.51/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::f0da:87ff:fec5:9246/64 scope link
       valid_lft forever preferred_lft forever
4: net1@if12: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether ba:5a:93:d8:61:44 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.1.128.253/24 brd 10.1.128.255 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::b85a:93ff:fed8:6144/64 scope link
       valid_lft forever preferred_lft forever

```
check the route table of application pod
```
kubectl exec -it po/`kubectl get pods -l app=multitool01 --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- ip route
```
you shall see 
```
 # ip r
default via 10.1.128.252 dev net1
10.0.0.0/8 via 169.254.1.1 dev eth0
10.0.0.2 via 10.1.128.1 dev net1
10.1.128.0/24 dev net1 proto kernel scope link src 10.1.128.253
10.96.0.0/12 via 10.1.128.1 dev net1
10.96.0.0/12 via 169.254.1.1 dev eth0
169.254.1.1 dev eth0 scope link

```
check whether application POD can reach internet 
```
kubectl exec -it po/`kubectl get pods -l app=multitool01 --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- ping -c 1 1.1.1.1  

```
you shall see 

```
 # ping -c 1 1.1.1.1
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=47 time=2.12 ms
--- 1.1.1.1 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 2.121/2.121/2.121/0.000 ms
```
check whether application POD can access https://www.google.com

```
kubectl exec -it po/`kubectl get pods -l app=multitool01 --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- curl -I -k https://www.google.com
 
```

*we can also do sniff on cfos for traffic from pod to internet*

*continue ping on application pod*
*you can use tmux to open a windows to do ping, then use Ctrl-B to switch back to the main windows*

```
kubectl exec -it po/`kubectl get pods -l app=multitool01 --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- ping 1.1.1.1 
```

```
*check cfos sniff* 


```
podname=$(kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1)
kubectl exec -it po/$podname -- fcnsh
```
use `diagnose sniffer  packet  any icmp` to do the sniff 

FOS Container # diagnose sniffer packet any icmp
interfaces=[any]

filters=[icmp]
count=unlimited
snaplen=1600
FOS Container # linktype = 113
0.710661 10.1.128.253 -> 1.1.1.1: icmp: echo request
0.710772 10.244.97.53 -> 1.1.1.1: icmp: echo request
0.712074 1.1.1.1 -> 10.244.97.53: icmp: echo reply
0.712139 1.1.1.1 -> 10.1.128.253: icmp: echo reply
1.711631 10.1.128.253 -> 1.1.1.1: icmp: echo request
1.711747 10.244.97.53 -> 1.1.1.1: icmp: echo request
1.713072 1.1.1.1 -> 10.244.97.53: icmp: echo reply
1.713158 1.1.1.1 -> 10.1.128.253: icmp: echo reply
2.713326 10.1.128.253 -> 1.1.1.1: icmp: echo request
2.713438 10.244.97.53 -> 1.1.1.1: icmp: echo request
2.714742 1.1.1.1 -> 10.244.97.53: icmp: echo reply
2.714946 1.1.1.1 -> 10.1.128.253: icmp: echo reply
exit on interrupt

16 packets received by filter
0 packets dropped by kernel
```

- ### check cfos traffic log

you can use cFOS cli to check log or directly retrive log from /data folder 

```
podname=$(kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1)
kubectl exec -it po/$podname -- fcnsh
```

```
FOS Container # execute  log filter category traffic

FOS Container # execute log filter device disk

FOS Container # execute  log display
date=2023-04-04 time=03:34:54 eventtime=1680579294 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.253 identifier=30 dstip=1.1.1.1 sessionid=2162419778 proto=1 action="accept" policyid=3 service="ICMP" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-04-04 time=03:35:56 eventtime=1680579356 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.253 identifier=36 dstip=1.1.1.1 sessionid=2892995414 proto=1 action="accept" policyid=3 service="ICMP" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-04-04 time=03:37:59 eventtime=1680579479 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.253 srcport=57104 dstip=1.1.1.1 dstport=443 sessionid=1472067573 proto=6 action="accept" policyid=3 service="HTTPS" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-04-04 time=03:39:19 eventtime=1680579559 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.253 srcport=33692 dstip=1.1.1.1 dstport=443 sessionid=1761115261 proto=6 action="accept" policyid=3 service="HTTPS" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-04-04 time=03:39:19 eventtime=1680579559 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.253 srcport=59400 dstip=142.251.111.104 dstport=443 sessionid=536138460 proto=6 action="accept" policyid=3 service="HTTPS" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-04-04 time=03:39:19 eventtime=1680579559 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.253 identifier=82 dstip=1.1.1.1 sessionid=2918398085 proto=1 action="accept" policyid=3 service="ICMP" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-04-04 time=03:39:19 eventtime=1680579559 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.253 srcport=38716 dstip=1.1.1.1 dstport=80 sessionid=104067363 proto=6 action="accept" policyid=3 service="HTTP" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-04-04 time=03:40:20 eventtime=1680579620 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.253 identifier=88 dstip=1.1.1.1 sessionid=835062401 proto=1 action="accept" policyid=3 service="ICMP" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-04-04 time=03:40:20 eventtime=1680579620 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.253 srcport=36984 dstip=142.251.16.105 dstport=443 sessionid=3703662473 proto=6 action="accept" policyid=3 service="HTTPS" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-04-04 time=03:42:23 eventtime=1680579743 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.253 identifier=94 dstip=1.1.1.1 sessionid=3696144910 proto=1 action="accept" policyid=3 service="ICMP" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0
date=2023-04-04 time=03:43:24 eventtime=1680579804 tz="+0000" logid="0000000013" type="traffic" subtype="forward" level="notice" srcip=10.1.128.253 identifier=103 dstip=1.1.1.1 sessionid=984349417 proto=1 action="accept" policyid=3 service="ICMP" trandisp="noop" duration=0 sentbyte=0 rcvdbyte=0 sentpkt=0 rcvdpkt=0


11 logs returned.
```
*or directly cat the log file from container*

```
podname=$(kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1)
kubectl exec -it po/$podname -- tail -f /var/log/log/traffic.0
```
you shall see same log



- ## cfos utm feature 
*in this section, we config cfos to test web filter feature and ips feature use https traffic* 

- ### web filter feature 

```
kubectl exec -it po/`kubectl get pods -l app=multitool01 --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  --  curl -k -I  https://www.eicar.org/download/eicar.com.txt
```

you shall see that cFOS blocked the access due to it's classified as malicious traffic. 
```
HTTP/1.1 403 Forbidden
X-Frame-Options: SAMEORIGIN
X-XSS-Protection: 1; mode=block
X-Content-Type-Options: nosniff
Content-Security-Policy: frame-ancestors 'self'
Content-Type: text/html; charset="utf-8"
Content-Length: 5211
Connection: Close

```

- ###  Check log on cFOS
the pod that access malicious is on node ip-10-0-2.200. so we need use cFOS POD on same node to check the block log.

```
kubectl exec -it po/`kubectl get pods -l app=fos --field-selector spec.nodeName=ip-10-0-2-200 |     cut -d ' ' -f 1 | tail -n -1`  -- tail -f -n 1 /var/log/log/webf.0
```
you shall see 
```
date=2023-04-04 time=03:48:26 eventtime=1680580106 tz="+0000" logid="0316013056" type="utm" subtype="webfilter" eventtype="ftgd_blk" level="warning" policyid=3 sessionid=6 srcip=10.1.128.253 srcport=50532 srcintf="net1" dstip=89.238.73.97 dstport=443 dstintf="eth0" proto=6 service="HTTPS" hostname="www.eicar.org" profile="default" action="blocked" reqtype="direct" url="https://www.eicar.org/download/eicar.com.txt" sentbyte=100 rcvdbyte=0 direction="outgoing" msg="URL belongs to a denied category in policy" method="domain" cat=26 catdesc="Malicious Websites"
```

- ### ips inspect feature 

*we can use curl to generate attack traffic to target ip address, this traffic will be detected by cfos and block it* 

```
kubectl get pod | grep multi | grep -v termin | awk '{print $1}'  | while read line; do kubectl exec -t po/$line --  curl --max-time 5  -k -H "User-Agent: () { :; }; /bin/ls" https://1.1.1.1  ; done
```
you will see that request has been blocked by cFOS . 
```
ubuntu@ip-10-0-1-100:~/202301$ kubectl get pod | grep multi | grep -v termin | awk '{print $1}'  | while read line; do kubectl exec -t po/$line --  curl --max-time 5  -k -H "User-Agent: () { :; }; /bin/ls" https://1.1.1.1  ; done
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:05 --:--:--     0
curl: (28) Operation timed out after 5001 milliseconds with 0 bytes received
command terminated with exit code 28
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:05 --:--:--     0
curl: (28) Operation timed out after 5001 milliseconds with 0 bytes received
command terminated with exit code 28
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:04 --:--:--     0
curl: (28) Operation timed out after 5000 milliseconds with 0 bytes received
command terminated with exit code 28

```
- ### check cfos ips block log 

```
kubectl get pod | grep fos | awk '{print $1}'  | while read line; do kubectl exec -t po/$line -- tail  /data/var/log/log/ips.0  ; done
```
you shall see log 
```
 date=2023-03-15 time=09:21:46 eventtime=1678872106 tz="+0000" logid="0419016384" type="utm" subtype="ips" eventtype="signature" level="alert" severity="critical" srcip=10.1.128.253 dstip=1.1.1.1 srcintf="net1" dstintf="eth0" sessionid=6 action="dropped" proto=6 service="HTTPS" policyid=3 attack="Bash.Function.Definitions.Remote.Code.Execution" srcport=44084 dstport=443 hostname="1.1.1.1" url="/" direction="outgoing" attackid=39294 profile="default" incidentserialno=10485761 msg="applications3: Bash.Function.Definitions.Remote.Code.Execution"
date=2023-03-15 time=09:21:41 eventtime=1678872101 tz="+0000" logid="0419016384" type="utm" subtype="ips" eventtype="signature" level="alert" severity="critical" srcip=10.1.128.253 dstip=1.1.1.1 srcintf="net1" dstintf="eth0" sessionid=2 action="dropped" proto=6 service="HTTPS" policyid=3 attack="Bash.Function.Definitions.Remote.Code.Execution" srcport=56174 dstport=443 hostname="1.1.1.1" url="/" direction="outgoing" attackid=39294 profile="default" incidentserialno=167772161 msg="applications3: Bash.Function.Definitions.Remote.Code.Execution"
date=2023-03-15 time=09:21:51 eventtime=1678872111 tz="+0000" logid="0419016384" type="utm" subtype="ips" eventtype="signature" level="alert" severity="critical" srcip=10.1.128.253 dstip=1.1.1.1 srcintf="net1" dstintf="eth0" sessionid=2 action="dropped" proto=6 service="HTTPS" policyid=3 attack="Bash.Function.Definitions.Remote.Code.Execution" srcport=60116 dstport=443 hostname="1.1.1.1" url="/" direction="outgoing" attackid=39294 profile="default" incidentserialno=29360129 msg="applications3: Bash.Function.Definitions.Remote.Code.Execution"
```
or use cfos console 

```
FOS Container # execute  log filter category 4

FOS Container # execute  log filter device disk

FOS Container # execute log display
date=2023-03-15 time=09:21:46 eventtime=1678872106 tz="+0000" logid="0419016384" type="utm" subtype="ips" eventtype="signature" level="alert" severity="critical" srcip=10.1.128.253 dstip=1.1.1.1 srcintf="net1" dstintf="eth0" sessionid=6 action="dropped" proto=6 service="HTTPS" policyid=3 attack="Bash.Function.Definitions.Remote.Code.Execution" srcport=44084 dstport=443 hostname="1.1.1.1" url="/" direction="outgoing" attackid=39294 profile="default" incidentserialno=10485761 msg="applications3: Bash.Function.Definitions.Remote.Code.Execution"

1 logs returned.
```

- ### clean up

logout from kubernetes master , back to your client terminal.

use `terraform destroy` to delete kubernetes cluster 

```
terraform destroy -auto-approve
```



- ### calico network explained


*this section we explain how calico network works,the key is calico use proxy arp with a pesudo gateway 169.254.1.1*

calico network configuraition can be checked with
```
ubuntu@ip-10-0-2-200:~$ kubectl get installation default -o jsonpath={.spec.calicoNetwork}
{"bgp":"Disabled","containerIPForwarding":"Enabled","hostPorts":"Enabled","ipPools":[{"blockSize":24,"cidr":"10.244.0.0/16","disableBGPExport":false,"encapsulation":"VXLAN","natOutgoing":"Enabled","nodeSelector":"all()"}],"linuxDataplane":"Iptables","multiInterfaceMode":"None","nodeAddressAutodetectionV4":{"firstFound":true}}ubuntu@ip-10-0-2-200:~$ kubectl get installation default -o jsonpath={.spec.calicoNetwork} | jq .
{
  "bgp": "Disabled",
  "containerIPForwarding": "Enabled",
  "hostPorts": "Enabled",
  "ipPools": [
    {
      "blockSize": 24,
      "cidr": "10.244.0.0/16",
      "disableBGPExport": false,
      "encapsulation": "VXLAN",
      "natOutgoing": "Enabled",
      "nodeSelector": "all()"
    }
  ],
  "linuxDataplane": "Iptables",
  "multiInterfaceMode": "None",
  "nodeAddressAutodetectionV4": {
    "firstFound": true
  }
}
```

- ### walkthrough each hop from source pod to destination pod on other node 

```
ubuntu@ip-10-0-2-200:~$ kubectl get pod -o wide
NAME                                    READY   STATUS    RESTARTS   AGE    IP             NODE            NOMINATED NODE   READINESS GATES
multitool01-deployment-bb4c98bb-8p4lt   1/1     Running   0          155m   10.244.97.51   ip-10-0-2-200   <none>           <none>
multitool01-deployment-bb4c98bb-flspr   1/1     Running   0          155m   10.244.93.50   ip-10-0-2-201   <none>           <none>
```
above we have two pod in two nodes. they are in different subnets. we can check on each hop with tcpdump etc tool.


```
 (src pod:10.244.97.51)---[(cali-)-(vxlan.calico-10.244.97.0/32)-ens5-(10-0.2.200)]
                                                                   -vpc-subnet-[(10.0.2.0/24)
 (dst pod:10.244.93.50)---[(cali-)-(vxlan.calico-10.244.93.0/32)-ens5-(10.0.2.201)]

 ```

from pod eth0 interface 10.244.97.51 to pod 10.244.93.50

- #### step1: ip route lookup found the nexthop is 169.254.1.1

this ip address is not on any interface. caclico hardcoded this ip address. so the arp request for this address will happen routing happens.

``` 
ubuntu@ip-10-0-2-200:~$ kubectl exec -it po/multitool01-deployment-bb4c98bb-8p4lt -- ip route get 10.244.93.50
10.244.93.50 via 169.254.1.1 dev eth0 src 10.244.97.51 uid 0
    cache
```

- #### step2: send arp request for 169.254.1.1 got reply with mac address: ee:ee:ee:ee:ee:ee 
when source pod do l3 forwarding. the arp request to 169.254.1.1 will be generated. this arp request will reach host interface via veth pair.(pod3: host:if13)
pod is connecting with host interface (index13 : cali6d544638a21@if3). 
```
ubuntu@ip-10-0-2-200:~$ kubectl exec -it po/multitool01-deployment-bb4c98bb-8p4lt -- ip a  | grep eth0
3: eth0@if13: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue state UP group default
    inet 10.244.97.51/32 scope global eth0

ubuntu@ip-10-0-2-200:~$ kubectl exec -it po/multitool01-deployment-bb4c98bb-8p4lt -- ping 10.244.93.50

ubuntu@ip-10-0-2-200:~$ kubectl exec -it po/multitool01-deployment-bb4c98bb-8p4lt -- sh 
ubuntu@ip-10-0-2-200:~$ sudo tcpdump -i cali6d544638a21 arp
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on cali6d544638a21, link-type EN10MB (Ethernet), snapshot length 262144 bytes
06:16:47.733555 ARP, Request who-has 169.254.1.1 tell 10.244.97.51, length 28
06:16:47.733635 ARP, Reply 169.254.1.1 is-at ee:ee:ee:ee:ee:ee (oui Unknown), length 28

```

- #### step3: this arp request reached host interface cali6d544638a21, this cali interface replied the arp request with mac ee:ee:ee:ee:ee:ee 
```
ubuntu@ip-10-0-2-200:~$ sudo tcpdump -i cali6d544638a21  -n
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on cali6d544638a21, link-type EN10MB (Ethernet), snapshot length 262144 bytes
05:36:54.101773 ARP, Request who-has 169.254.1.1 tell 10.244.97.51, length 28
05:36:54.101784 ARP, Reply 169.254.1.1 is-at ee:ee:ee:ee:ee:ee, length 28
``` 
this is because the interface cali6d544638a21 on host has **proxy arp** enabled. this interface does not have ip address. but will response arp request with it's macddress

```
ubuntu@ip-10-0-2-200:~$ cat /proc/sys/net/ipv4/conf/cali6d544638a21/proxy_arp
1
```

- #### step4: source pod use ee:ee:ee:ee:ee:ee as dst mac send traffic to host. 
- #### step5: host do route lookup for dst 10.244.93.50 found nexthop is 10.244.93.0 which is vxlan.calico interface , normal vxlan tunnel follows. 
```
ubuntu@ip-10-0-2-200:~$ ip r get 10.244.93.50
10.244.93.50 via 10.244.93.0 dev vxlan.calico src 10.244.97.0 uid 1000
    cache
``` 
on this host, the nexthop ip address 10.244.93.0 has a permant mac address. so traffic will reach tunnel interface.   
```
ubuntu@ip-10-0-2-200:~$ ip route | grep 10.244.93.0
10.244.93.0/24 via 10.244.93.0 dev vxlan.calico onlink
ubuntu@ip-10-0-2-200:~$ ip neighbor | grep 10.244.93.0
10.244.93.0 dev vxlan.calico lladdr 66:73:5c:ce:0d:ae PERMANENT
```
- #### step6: vxlan.calico interface encapsulate packet with vxlan and send via ens5 interface to peer node. 
you can see, by default, vxlan.calico interface use vlxan id 4096 and dst port is 4789. nolearning is configured, so no mac will be learned on this interface  
```
ubuntu@ip-10-0-2-200:~$ ip -d address show dev vxlan.calico
5: vxlan.calico: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue state UNKNOWN group default
    link/ether 66:55:b7:b7:f8:dc brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 65535
    vxlan id 4096 local 10.0.2.200 dev ens5 srcport 0 0 dstport 4789 nolearning ttl auto ageing 300 udpcsum noudp6zerocsumtx noudp6zerocsumrx numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535
    inet 10.244.97.0/32 scope global vxlan.calico
       valid_lft forever preferred_lft forever
    inet6 fe80::6455:b7ff:feb7:f8dc/64 scope link
       valid_lft forever preferred_lft forever

ubuntu@ip-10-0-2-200:~$ sudo tcpdump -i vxlan.calico -n -vvv src 10.244.97.51
tcpdump: listening on vxlan.calico, link-type EN10MB (Ethernet), snapshot length 262144 bytes
05:50:40.481791 IP (tos 0x0, ttl 63, id 19904, offset 0, flags [DF], proto ICMP (1), length 84)
    10.244.97.51 > 10.244.93.50: ICMP echo request, id 60, seq 134, length 64
05:50:41.505776 IP (tos 0x0, ttl 63, id 20114, offset 0, flags [DF], proto ICMP (1), length 84)
    10.244.97.51 > 10.244.93.50: ICMP echo request, id 60, seq 135, length 64
```
- #### step 7 ens5 interface send vxlan packet to destination, packet reach destination pod. reverse procedure will happen for icmp reply. 
```
ubuntu@ip-10-0-2-200:~$ sudo tcpdump -i ens5 -n udp  port 4789 && src 10.0.2.200
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on ens5, link-type EN10MB (Ethernet), snapshot length 262144 bytes
05:55:35.201797 IP 10.0.2.200.45547 > 10.0.2.201.4789: VXLAN, flags [I] (0x08), vni 4096
IP 10.244.97.51 > 10.244.93.50: ICMP echo request, id 60, seq 422, length 64
05:55:35.202047 IP 10.0.2.201.40770 > 10.0.2.200.4789: VXLAN, flags [I] (0x08), vni 4096
IP 10.244.93.50 > 10.244.97.51: ICMP echo reply, id 60, seq 422, length 64
```

