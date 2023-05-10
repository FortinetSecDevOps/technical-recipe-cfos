---
title: "Task 5 - Create ConfigMap"
chapter: true
weight: 6
---

### Task 5 - Create a ConfigMap with cFOS license

{{< notice note >}}License is required to run/deploy **cFOS**.{{< /notice >}}

> **_NOTE:_** **cFOS** license can either be used inside a configmap or can be imported into **cFOS** using the cfos cli. Using ***configmap*** will allow to load license before installing **cFOS**.

{{< notice note >}}
* Do not forgot the "|" after the license: field.
* License text between the lines "    -----BEGIN FGT VM LICENSE----- " and "     -----END FGT VM LICENSE-----" must be formatted properly.
* You can use the below files (bash scripts) from [GitHub repo](https://github.com/FortinetSecDevOps/technical-recipe-cfos.git) to create license file and dockerpullsecret 
    * ***generatecfoslicensefromvmlicense.sh*** (create license file)
    * ***generatedockersecret.sh*** (dockerpullsecret) 
* You can also use the below script to create a license file. 
    * Replace the VM license filename with your own license file name. 
    * The example below assumes you already obtained a FortiGate VM license with the file name FGVMULTM23000010.lic. 
    * In the directory containing FGVMULTM23000010.lic, paste the below script to generate ConfigMap file.
    * This script will generate a ***cfos_license.yaml*** file with the necessary ConfigMap format for the **cFOS** license.
{{< /notice >}}

##### Below is the format of configmap with license

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