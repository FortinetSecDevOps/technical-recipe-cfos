---
title: "Task 5 - Create a ConfigMap with cFOS license"
chapter: true
weight: 6
---

### Task 5 - Create a ConfigMap with cFOS license

{{< notice note >}}cFOS license is required to run/deploy cFOS.{{< /notice >}}

> **_NOTE:_** cFOS license can either be used inside a configmap or can be imported into cfos using the cfos cli. Using configmap will allow to load license before installing cfos.


{{< notice info >}}
##### Below is the format of configmap with license
* Do not forgot the "|" after the license: field.
* the license text that between the lines "    -----BEGIN FGT VM LICENSE----- " and "     -----END FGT VM LICENSE-----" must not include any hard return.
* when you copy and paste licens . please remove hard return first**
* two bash script provided in the github repo  https://github.com/yagosys/202301.git  with name generatecfoslicensefromvmlicense.sh  generatedockersecret.sh to create license file and dockerpullsecret.
{{< /notice >}}

> **_NOTE:_** You can also use the script below to create a license file. Replace the VM license filename with your own license file name. The example below assumes you have already obtained a FortiGate VM license with the file name FGVMULTM23000010.lic. In the directory containing FGVMULTM23000010.lic, paste the script below to generate the license ConfigMap file.

> This script will generate a cfos_license.yaml file with the necessary ConfigMap format for the cFOS license.

```
licensestring=$(sed '1d;$d' FGVMULTM23000010.lic | tr -d '\n')
cat <<EOF >cfos_license.yaml
apiVersion: v1
kind: ConfigMap
metadata:
    name: fos-license
    labels:
        app: fos
        category: license
data:
    license: |
     -----BEGIN FGT VM LICENSE-----
     $licensestring
     -----END FGT VM LICENSE-----
EOF
```