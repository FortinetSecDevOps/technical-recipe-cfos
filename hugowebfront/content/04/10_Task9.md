---
title: "Task 9 - Verify cFOS configuration"
chapter: true
weight: 10
---

### Task 9 - Verify cFOS configuration with cFOS cli

> **_NOTE:_** AS of now, **cFOS** has no configuration but just a license.

* Use ***`fcnsh`*** to enter **cFOS** shell

* Use ***`sysctl sh`*** go exit from **cFOS** shell

```
cfospodname=$(kubectl get pod -l app=fos -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it po/$cfospodname -- sh
```

> With above command will enter into a shell. Type ***`fcnsh`*** to enter cFOS shell

```
fcnsh
```

> **_NOTE:_** You will notice  **cFOS** cli interface, where you can use fortiOS cli commands

```
FOS Container # show firewall policy
config firewall policy
end

FOS Container # show firewall addrgrp
config firewall addrgrp
end
FOS Container # sysctl sh
#
``` 

> To exit from the **cFOS** cli, enter ***`sysctl sh`*** command

```
FOS Container # sysctl sh
# exit
```