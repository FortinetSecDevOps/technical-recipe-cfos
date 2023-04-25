---
title: "Task 7 - check cFOS firewall policy"
chapter: true
weight: 8
---

### Task 7 - check cFOS firewall policy

```
FOS Container # show firewall policy
config firewall policy
    edit "101"
        set utm-status enable
        set name "corptraffic101"
        set srcintf any
        set dstintf eth0
        set srcaddr defaultappmultitool
        set dstaddr all
        set service ALL
        set ssl-ssh-profile "deep-inspection"
        set av-profile "default"
        set webfilter-profile "default"
        set ips-sensor "default"
        set nat enable
        set logtraffic all
    next
    edit "102"
        set utm-status enable
        set name "corptraffic102"
        set srcintf any
        set dstintf eth0
        set srcaddr defaultappnewtest
        set dstaddr all
        set service ALL
        set ssl-ssh-profile "deep-inspection"
        set av-profile "default"
        set webfilter-profile "default"
        set ips-sensor "default"
        set nat enable
        set logtraffic all
    next
end
```