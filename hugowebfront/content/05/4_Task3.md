---
title: "Task 3 - Create other deployment"
chapter: true
weight: 4
---

### Task 3 - Create deployment with a different label

* To support multiple application(s) based on label(s), for this Demo, will create one more deployment with different label.

paste below script to create another deployment, we assign label to pod app=newtest 
in this deployment, we use initContainers to insert a route for this POD.  this route is telling for POD to POD traffic from eth0. not goes to cFOS. but continue to use aws VPC CNI created cluster network. 

> Below command will create another deployment

> **_NOTE:_**  POD is assigned with a label ***app=newtest*** in this deployment. We use ***initContainers*** to insert a ***route*** for this POD. By this route, POD to POD traffic from ***eth0*** will traverse through ***aws VPC CNI*** created cluster network but NOT through **cFOS**.

``` yaml
cat << EOF | kubectl create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: testtest-deployment
  labels:
    app: newtest
spec:
  replicas: 2
  selector:
    matchLabels:
      app: newtest
  template:
    metadata:
      labels:
        app: newtest
      annotations:
        k8s.v1.cni.cncf.io/networks: '[ { "name": "cfosdefaultcni5",  "default-route":
          ["10.1.200.252"]  } ]'
    spec:
      initContainers:
        - name: init-wait
          image: alpine
          command:
            - sh
            - -c
            - ip route add 10.0.0.0/16 via 169.254.1.1
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
      containers:
        - name: newtest
          image: praqma/network-multitool
          imagePullPolicy: Always
          securityContext:
            privileged: true
EOF
```

> Below command will get status of the POD

```
  kubectl get pod -l app=newtest
````

> output will be similar as below

```
➜  ✗ kubectl  get pod -l app=newtest
NAME                                   READY   STATUS    RESTARTS   AGE
testtest-deployment-5768f678d7-76krs   1/1     Running   0          28s
testtest-deployment-5768f678d7-ng92z   1/1     Running   0          28s
```