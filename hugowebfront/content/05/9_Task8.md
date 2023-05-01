---
title: "Task 8 - Verify cFOS state"
chapter: true
weight: 9
---

### Task 8 - Verify if cFOS is in healthy state

> **_NOTE:_** **cFOS** might run into some SSL related issue which needs to be fixed. Below script will help fixing it 

```
#!/bin/bash

# Get list of node names
node_list=$(kubectl get nodes -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

function deletepod {
for nodeName in $node_list; do
	echo $1
     while true ; do
        kubectl rollout status deployment multitool01-deployment
        cfospod=`kubectl get pods -l app=fos --field-selector spec.nodeName=$nodeName |    cut -d ' ' -f 1 | tail -n -1`
        multpod=`kubectl get pods -l app=$1 --field-selector spec.nodeName=$nodeName |   cut -d ' ' -f 1 | tail -n -1`
        result=$(kubectl exec -it po/$multpod -- curl -k  https://1.1.1.1 2>&1 | grep -o 'decryption failed or bad record mac')
        if [ "$result" = "decryption failed or bad record mac" ]
        then
        echo "cfos is not ready, delete cfos pod"
        kubectl delete po/$cfospod
        else
                echo " on $nodeName cfos is ready"
                break

        fi
     done
done
}

deletepod "multitool01"
deletepod "newtest"
```