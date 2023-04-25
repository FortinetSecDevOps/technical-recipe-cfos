---
title: "Task 3 - Create role for cFOS"
chapter: true
weight: 4
---

### Task 3 - Create role for cFOS


* cfos pod  will need permission to communicate with kubernetes API to read the configmap and also need able to read secret to pull docker image so we need assign role with permission to cfos POD based on least priviledge principle

* below we create ClusterRole to read configmaps and secrets and bind them to default serviceaccount

* when we create cfos POD with default serviceaccount, the pod will have permission to read configmap and secret

   copy and paste below code to your client terminal window to create role for cFOS

   ```
   cat << EOF | kubectl create -f - 
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

   you shall see  output like below

   ```
   clusterrole.rbac.authorization.k8s.io/configmap-reader created
   rolebinding.rbac.authorization.k8s.io/read-configmaps created
   clusterrole.rbac.authorization.k8s.io/secrets-reader created
   rolebinding.rbac.authorization.k8s.io/read-secrets created
   ```