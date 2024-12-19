#!/bin/bash

if [ -z "$1" ]; then
    echo "请输入namespace"
    exit 0
fi

build_path="build"

current_dir=$(dirname "$(readlink -f "$0")")
echo "进入sh所在目录：$current_dir"
cd $current_dir

mkdir -p $current_dir/$build_path

FILE_NAME=${build_path}/images.txt

kubectl -n $1 get deployments -o jsonpath="{.items[*].spec.template.spec.containers[*].image}" | awk '{for(i=1;i<=NF;i++) print $i}' > ${FILE_NAME}

echo "harbor.nancalcloud.com/tools/ingress-nginx-controller:v1" >> ${FILE_NAME}
echo "harbor.nancalcloud.com/tools/kube-webhook-certgen:v20220916" >> ${FILE_NAME}
echo "harbor.nancalcloud.com/tools/busybox:latest" >> ${FILE_NAME}

cat ${FILE_NAME}
