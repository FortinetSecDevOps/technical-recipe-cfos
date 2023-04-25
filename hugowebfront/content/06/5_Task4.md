---
title: "Task 4 - deploy actual constraint for cFOS network policy"
chapter: true
weight: 5
---

### Task 4 - deploy actual constraint for cFOS network policy

* the kind must match the one defined in the template
* the enforcementAction:deny means if condition met, the gatekeeper will not send it to kubernetes API
* match/kinds/NetworkPolicy mean only watch for NetworkPlicy API
* in parameters, we use label cfosegressfirewallpolicy. then a networkpolicy has same label will be checked

paste below to your client terminal 

```
cat << EOF | kubectl create -f -
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sEgressNetworkPolicyToCfosUtmPolicy
metadata:
  name: cfosnetworkpolicy
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: ["networking.k8s.io"]
        kinds: ["NetworkPolicy"]
  parameters:
    firewalladdressapiurl : "http://fos-deployment.default.svc.cluster.local/api/v2/cmdb/firewall/address"
    firewallpolicyapiurl : "http://fos-deployment.default.svc.cluster.local/api/v2/cmdb/firewall/policy"
    firewalladdressgrpapiurl: "http://fos-deployment.default.svc.cluster.local/api/v2/cmdb/firewall/addrgrp"
    policyid : "200"
    label: "cfosegressfirewallpolicy"
    outgoingport: "eth0"
    utmstatus: "enable"
    ipsprofile: "default"
    avprofile: "default"
    sslsshprofile: "deep-inspection"
    action: "permit"
    srcintf: "any"
    extraservice: "PING"
EOF
```

you shall see

```
k8segressnetworkpolicytocfosutmpolicy.constraints.gatekeeper.sh/cfosnetworkpolicy created
```
you can use `kubectl get k8segressnetworkpolicytocfosutmpolicy` to check 

```
➜  policy git:(main) ✗ kubectl get k8segressnetworkpolicytocfosutmpolicy
NAME                ENFORCEMENT-ACTION   TOTAL-VIOLATIONS
cfosnetworkpolicy   deny
```