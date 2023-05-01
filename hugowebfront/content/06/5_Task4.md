---
title: "Task 4 - Deploy constraint for cFOS network policy"
chapter: true
weight: 5
---

### Task 4 - Deploy constraint for cFOS network policy

1. ***Kind*** must match the one defined in the template.

1. ***enforcementAction:deny*** means if condition met, the gatekeeper will not send it to kubernetes API.

1. ***match/kinds/NetworkPolicy*** means only watch for ***NetworkPolicy API***.

1. For parameters, we use label ***cfosegressfirewallpolicy***.

> Use below script craete network policy 

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

> output will be similar as below

```
k8segressnetworkpolicytocfosutmpolicy.constraints.gatekeeper.sh/cfosnetworkpolicy created
```

> you can use `kubectl get k8segressnetworkpolicytocfosutmpolicy` to check 

```
➜  policy git:(main) ✗ kubectl get k8segressnetworkpolicytocfosutmpolicy
NAME                ENFORCEMENT-ACTION   TOTAL-VIOLATIONS
cfosnetworkpolicy   deny
```