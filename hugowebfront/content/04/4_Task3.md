---
title: "Task 3 - Create role for cFOS"
chapter: true
weight: 4
---

### Task 3 - Create role for cFOS


* **cFOS** pod would need a role to  
   * Communicate with kubernetes API to read the ConfigMap 
   * Read secret to pull docker image 

> **_NOTE:_** So by following principle of least privilege, we need to assign a role to **cFOS** POD.

* Below we create a ClusterRole to read ConfigMap and Secret, and bind them to default ServiceAccount.

> **_NOTE:_** When a **cFOS** POD is created with default ServiceAccount, the pod will have permission to read ConfigMap and Secret.

Use the below copy and paste below code to your client terminal window to create role for 

> By using below code in your client terminal window, will create role for **cFOS**

``` yaml
cat << EOF | kubectl create -f - 
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  namespace: default
  name: configmap-reader
rules:
  - apiGroups:
      - ""
resources:
  - configmaps
verbs:
  - get
  - watch
  - list
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
  - apiGroups:
      - ""
    resources:
      - secrets
    verbs:
      - get
      - watch
      - list
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

> output will be similar as below

   ```
   clusterrole.rbac.authorization.k8s.io/configmap-reader created
   rolebinding.rbac.authorization.k8s.io/read-configmaps created
   clusterrole.rbac.authorization.k8s.io/secrets-reader created
   rolebinding.rbac.authorization.k8s.io/read-secrets created
   ```