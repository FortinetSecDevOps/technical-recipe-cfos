---
title: "Task 9 - check cFOS configuration use cFOS cli"
chapter: true
weight: 10
---

### Task 9 - check cFOS configuration use cFOS cli

* at this moment, cfos has no configuration but a license
* use ***`fcnsh`*** to enter cfos shell
* use ***`sysctl sh`*** go back to sh

```
cfospodname=$(kubectl get pod -l app=fos -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it po/$cfospodname -- sh
```

you will be dropped into the shell. then type ***`fcnsh`*** to enter cFOS shell

```
fcnsh
```

you will see  cFOS cli interface, where you can use fortiOS cli 

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

you can use ***`sysctl sh`*** command back to cFOS container linux shell

```
FOS Container # sysctl sh
# exit
```