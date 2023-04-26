#!/bin/bash
#
if [ $# -eq 0 ]; then
  echo "Usage: $0 <config.json >"
  exit 1
fi

input_file="$1"

case "$(uname -s)" in
    Linux*)  base64_flag="-w0";;
    Darwin*) base64_flag="";;
    *)       echo "Unknown operating system"; exit 1;;
esac

if [ -f "$input_file" ]; then


ENCODED_CONFIG_DATA=$(cat $input_file | base64  $base64_flag)

cat <<EOF >  dockerpullsecret.yaml
{
  "apiVersion": "v1",
  "kind": "Secret",
  "metadata": {
    "name": "dockerinterbeing"
  },
  "type": "kubernetes.io/dockerconfigjson",
  "data": {
    ".dockerconfigjson": "${ENCODED_CONFIG_DATA}"
  }
}
EOF

echo dockerpullsecret.yaml created
else

echo $input_file not exist, please supply full path of the file, such as /home/ubuntu/snap/docker/2746/.docker/config.json

fi
