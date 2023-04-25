---
title: "Task 6 - check cFOS firewall addressgroup"
chapter: true
weight: 7
---

### Task 6 - check cFOS firewall addressgroup

* the firewall addrgrp has each POD IP in the group

```
cfospod=$(kubectl get pod | grep fos | awk '{print $1}')
kubectl exec -it po/$cfospod -- fcnsh
```

use ***`show firewall addrgrp`*** will show that the address group include all POD ip address

```
FOS Container # show firewall addrgrp
config firewall addrgrp
    edit "defaultappmultitool"
        set member 10.1.200.21 10.1.200.22 10.1.200.253 10.1.200.20
    next
    edit "defaultappnewtest"
        set member 10.1.200.24 10.1.200.23
    next
end
```