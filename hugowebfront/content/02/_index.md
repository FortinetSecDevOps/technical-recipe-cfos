---
title: "Chapter 2 - Setting up EKS Cluster"
chapter: true
weight: 2
---

## Fortinet cFOS Workshop

### Chapter 2 - Setting up EKS Cluster

This chapter will guide you through setting up cFOS on an EKS cluster with AWS VPC CNI and macvlan CNI. The application pod will use an additional network to communicate with cFOS. Multus CNI is required to create and manage the additional network.

In this chapter, we will demonstrate how to set up cFOS to use an additional network to route traffic from two applications to the internet. We use Multus CNI to manage the additional network for traffic between cFOS and the application pod. Macvlan CNI is utilized as the actual CNI for the secondary network. In this setup, the application pod's IP address is visible to cFOS. There is no SNAT enabled on the net1 interface, so cFOS will need to add each pod IP address to the address group and use it as the source address in the firewall policy. We then use a client pod that continually updates the real pod IP address from the Kubernetes pod to the cFOS address group. We also demonstrate how cFOS can detect malicious URLs from the application pod to the internet, even when the traffic is HTTPS-based.

In the final portion, we demonstrate how to use Kubernetes egress network policy to apply firewall policy to cFOS. We use Gatekeeper to monitor the network policy. If the network policy has a label that matches what cFOS needs, the network policy request will be sent to cFOS via cFOS RESTful API to create a firewall policy configuration on cFOS.

## Network Diagram
```stl
+---------------+   eth0    +--------------+  eth0 (SNAT)           
| Application   +---------->|    cFOS      |--------------  internet 
| Pod           | (VPC CNI) |              |  
+               +           +              +          
|               |   net1    |  DaemonSet   | 
|               +---------->|              |
|               | (macvlan) |              |
+---------------+           +--------------+ 
```
{{< notice info >}}
* Cluster POD to POD Traffic: eth0 (Application Pod) <--> eth0 (cFOS Pod).
* Internet Traffic: Application Pod ---> net1 (cFOS Pod) ---> eth0 (sNAT enabled) ---> Internet.
* The eth0 interfaces are managed by Multus with delegation to `AWS VPC CNI`, and the net1 interfaces are managed by Multus with delegation to `macvlan CNI`.
{{< /notice >}}

Both the Application POD and cFOS POD have two interfaces: eth0 and net1. The eth0 interfaces are managed by Multus with delegation to `AWS VPC CNI`, and the net1 interfaces are managed by Multus with delegation to `macvlan CNI`. The application POD communicates with the cFOS POD using the net1 interface. The traffic from the Application POD to the internet is routed through the cFOS POD, with SNAT enabled on the cFOS eth0 interface.


Tasks

* Install eksctl and kubectl
* IAM permissions to create EKS Cluster
* Deploying EKS Cluster
* 1
* 2
* install multus
* clone the code from github
* install multus from yaml file
* check the multus installation
* chech the multus cni now become the default cni for EKS on work node
* Create multus crd on EKS for application and cfos to attach
* check the crd installation
* install docker secret to pull cfos image from docker repository
* create a configmap with cfos license
* create role for cfos
* create cfos daemonSet
* check the cfos daemonSet deployment
* check cfos container log
* check the ip address and routing table of cfos container
* check cfos POD description
* check cfos configuration use cfos cli
* create demo application deployment
* check the deployment result
* create another deployment with different label
* create a clientpod to manage the networkpolicy and update pod ip address to cfos
* check both deployment now shall able to access internet via cfos
* check cfos firewall addressgroup
* check cfos firewall policy
* verify whether cFOS is in health state
* demo cfos l7 security feature -Web Filter feature
* check the webfilter log on cFOS
* scale the app deployment
* check cfos firewall addressgroup has also updated
* use eksctl to scale nodes
* check new cfos DaemonSet on new work node
* scale out application to use new node
* test whether all these POD can access internet via cFOS
* use kubernetes network policy to create firewallpolicy on cFOS
* delete existing firewall policy and clientpod
* install gatekeeperv3
* deploy constraintTemplate
* deploy actual constraint for cFOS network policy
* create clientpod to update the addressgroup
* clean up
* demo script
* how to build clientpod