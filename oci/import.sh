#!/bin/bash

# 本地仓库启动端口，导出导入必须一致
registry_port="51125"
# 本地仓库数据文件目录
registry_data="registry_data"
# 读取镜像列表的文件，一个一行
image_file="registry_images.txt"

repo_url="192.168.7.21:5000"

# 傻等5秒 funWait 5
funWait() {
    mark=''
    for ((ratio=0;${ratio}<=$1;ratio+=1))
    do
        sleep 1
        mark="#${mark}"
        printf "[%-$1s]\r" "${mark}"
    done
}

# 

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

read -p "确认镜像后输入(y, 其他退出): " value

if [ "$value" = "y" ]; then
    break
else
    echo "退出"
    exit 0
fi

echo ""


echo "启动本地临时仓库端口: " ${registry_port}

mkdir -p ${current_dir}/${registry_data}

docker run -d --name registry_temp --rm -v ${current_dir}/${registry_data}:/var/lib/registry/docker/registry -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 -p ${registry_port}:5000 registry:2 > /dev/null

funWait 5

echo "开始导入镜像到本地临时仓库..."

# mark=''
# for ((ratio=0;${ratio}<=100;ratio+=2))
# do
#     sleep 0.2
#     printf "[%-50s]%d%%\r" "${mark}" "${ratio}"
#     mark="#${mark}"
# done

index=0
for element in "${images[@]}"; do
    ((index++))
    registry_image=${element}
    echo "(${index}/${#images[@]}) 拉取镜像: ${registry_image}"
    docker pull ${registry_image} > /dev/null

    tagert_image="${repo_url}/${registry_image#*/}"
    echo "(${index}/${#images[@]}) 推送镜像: ${tagert_image}"
    docker tag ${registry_image} ${tagert_image} > /dev/null
    docker push ${tagert_image} > /dev/null 2>&1
done

# echo "停止本地临时仓库..."
# docker kill registry_temp > /dev/null
