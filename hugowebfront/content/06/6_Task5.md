---
title: "Task 5 - Create egress network policy"
chapter: true
weight: 6
---

### Task 5 - Create egress network policy

we create a normal egress network policy with label "cfosegressfirewallpolicy" to match contraint. 

```
cat << EOF | kubectl create -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: createdbygatekeeper
  labels:
    app: cfosegressfirewallpolicy
spec:
  podSelector:
    matchLabels:
      app: multitool
      namespace: default
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
EOF
```
you shall see output 
```
Error from server (Forbidden): error when creating "STDIN": admission webhook "validation.gatekeeper.sh" denied the request: [cfosnetworkpolicy]
{200 200  {{"name": "HTTP"}, {"name": "HTTPS"}, {"name": "PING"}}}
```

above means gatekeeper after evaluate the condition like label etc, it deny send the request to kubernetes API for create network policy, instead, it send the request to cFOS to create firewall policy. 

after that. login cFOS to check firewall policy,you shall see a policy created by cFOS

```
FOS Container # show firewall policy
config firewall policy
    edit "200"
        set utm-status enable
        set name "createdbygatekeeper"
        set srcintf any
        set dstintf eth0
        set srcaddr defaultappmultitool
        set dstaddr all
        set service HTTP HTTPS PING
        set ssl-ssh-profile "deep-inspection"
        set av-profile "default"
        set webfilter-profile "default"
        set ips-sensor "default"
        set nat enable
        set logtraffic all
    next
end
```