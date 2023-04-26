if [ $# -eq 0 ]; then
  echo "Usage: $0 <fortigate VM license file >"
  exit 1
fi

input_file="$1"

if [ -f "$input_file" ]; then


licensestring=$(sed '1d;$d' $input_file | tr -d '\n')
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
echo cfos_license.yaml created
else

echo $input_file not exist

fi
