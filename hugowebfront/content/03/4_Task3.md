---
title: "Task 3 - Create Multus CRD"
chapter: true
weight: 4
---

### Task 3 - Create Multus CRD on EKS for application and **cFOS** to attach

   > **_NOTE:_** We need to create additional network for application pod to communicate with **cFOS**. We use multus CRD to create this. 

1. Create Multus CRD on EKS for application and **cFOS** to attach 

   * The API for this CRD is k8s.cni.cncf.io/v1 
   * This is a CRD which has kind **NetworkAttachmentDefinition**
   * The CRD has name **cfosdefaultcni5**
   * Inside CRD, there is a json formatted **cni configuration**, it is the actual cni configuration, the **macvlan binary** will parse this json
   * cni uses **macvlan**
   * cni mode is **bridge**
   * Master interface for this **maclan** is **eth0**. EKS will not create additional ENI as we will use this network for communication between applicaton POD to **cFOS** POD
   * **ipam** is **host-local**

   > Paste the below code in the terminal window

``` yaml
cat << EOF | kubectl create -f -
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: cfosdefaultcni5
spec:
  config: '{
         "cniVersion": "0.3.0",
         "type": "macvlan",
         "master": "eth0",
         "mode": "bridge",
         "ipam": {
            "type": "host-local",
            "subnet": "10.1.200.0/24",
            "rangeStart": "10.1.200.20",
            "rangeEnd": "10.1.200.253",
            "gateway": "10.1.200.1"
         }
      }'
EOF
```

1. Validate CRD installation

   ```
   ✗ kubectl get net-attach-def cfosdefaultcni5 -o yaml
   apiVersion: k8s.cni.cncf.io/v1
   kind: NetworkAttachmentDefinition
   metadata:
   creationTimestamp: "2023-03-31T03:53:31Z"
   generation: 1
   name: cfosdefaultcni5
   namespace: default
   resourceVersion: "5700"
   uid: 2e8127d2-4dd5-4c8d-b1c4-c43a7f78ecbd
   spec:
   config: '{ "cniVersion": "0.3.0", "type": "macvlan", "master": "eth0", "mode": "bridge",
      "ipam": { "type": "host-local", "subnet": "10.1.200.0/24", "rangeStart": "10.1.200.20",
      "rangeEnd": "10.1.200.253", "gateway": "10.1.200.1" } }'
   ```