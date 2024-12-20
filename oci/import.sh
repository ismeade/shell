#!/bin/bash

. ./pub/common.sh
. ./pub/repo.sh

# 本地仓库启动端口，导出导入必须一致
registry_port="51125"
# 读取镜像列表的文件，一个一行
image_file="./build/registry_images.txt"


if [ -z "$1" ]; then
    echo "请输入repo_url, 如: harbor.nancalcloud.com/nancal、192.168.1.100:5000/nancal"
    exit 0
fi

repo_url=$1

current_dir=$(dirname "$(readlink -f "$0")")
echo "进入sh所在目录：$current_dir"
cd $current_dir

echo "读取镜像列表文件:" ${image_file} 
if [ -e ${image_file} ]; then
    echo ""
else
    echo "文件不存在"
    exit 0
fi

images=()

while IFS= read -r line
do
    images+=("$line")
done < ${image_file}

echo "#############################################################"
for element in "${images[@]}"; do
    echo "$element"
done
echo "#############################################################"
echo "镜像仓库前缀：${repo_url}"
echo "#############################################################"

read -p "确认镜像后输入(y, 其他退出): " value

if [ "$value" = "y" ]; then
    break
else
    echo "退出"
    exit 0
fi

funRunRegistry ${registry_port}

index=0
for element in "${images[@]}"; do
    ((index++))
    registry_image=${element}
    echo "(${index}/${#images[@]}) 拉取镜像: ${registry_image}"
    docker pull ${registry_image} > /dev/null

    tagert_image="${repo_url}/${registry_image##*/}"
    echo "(${index}/${#images[@]}) 推送镜像: ${tagert_image}"
    docker tag ${registry_image} ${tagert_image} > /dev/null
    docker push ${tagert_image} > /dev/null 2>&1
done

funStopRegistry
