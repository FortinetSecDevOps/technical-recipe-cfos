---
title: "Task 7 - Verify IP address and Routing Table"
chapter: true
weight: 8
---

### Task 7 - Verify IP address and Routing Table of cfos container

* Once **cFOS** is deployed, you will notice container has ***eth0*** and ***net1*** interfaces.
   * ***net1 interface*** is created by ***macvlan cni***
   * ***eth0 interface*** is created by ***aws vpc cni***

* **cFOS** container has default route pointing to ***`169.254.1.1`*** which has fixed mac address from ***veth pair interface*** on the host side (enixxx interface on host).

> Below command will get IP address details of the **cFOS** container

```
cfospodname=$(kubectl get pod -l app=fos -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it po/$cfospodname -- ip a
```

> output will be similar as below. 

> **_NOTE:_** You can notice different ip address on eth0, but the net1 ip address will be 10.1.200.252. 

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
3: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP group default
    link/ether 7e:55:44:3d:62:fa brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.19.107/32 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::7c55:44ff:fe3d:62fa/64 scope link
       valid_lft forever preferred_lft forever
4: net1@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP group default
    link/ether 8e:2c:2a:6b:90:49 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.1.200.252/24 brd 10.1.200.255 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::8c2c:2aff:fe6b:9049/64 scope link
       valid_lft forever preferred_lft forever
```

> Below command will get IP routing table of the **cFOS** container

```
cfospodname=$(kubectl get pod -l app=fos -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it po/$cfospodname -- ip route
```

> output will be similar as below. 

```
default via 169.254.1.1 dev eth0
10.1.200.0/24 dev net1 proto kernel scope link src 10.1.200.252
169.254.1.1 dev eth0 scope link
```