#!/bin/bash

# 本地仓库启动端口，导出导入必须一致
registry_port="51125"
# 读取镜像列表的文件，一个一行
image_file="images.txt"
build_path="build"

current_dir=$(dirname "$(readlink -f "$0")")
echo "进入sh所在目录：$current_dir"
cd $current_dir

mkdir -p $current_dir/$build_path

funWait() {
    mark=''
    for ((ratio=0;${ratio}<=$1;ratio+=1))
    do
        sleep 1
        mark="#${mark}"
        printf "[%-$1s]\r" "${mark}"
    done
}

funCheckResult() {
    if [ $? -ne 0 ]; then 
        echo "执行错误，脚本中断"
        exit 1
    fi
}

funRunRegistry() {
    echo "启动本地临时仓库端口: " $1

    mkdir -p ${current_dir}/${build_path}/registry_data

    # 使用docker ps命令查找容器
    CONTAINER_EXISTS=$(docker ps -aq --filter "name=^registry_temp$")
     
    # 检查容器是否存在
    if [ -n "$CONTAINER_EXISTS" ]; then
        read -p "容器 name: registry_temp 存在, 是否强制停止(y, 其他退出): " value

        if [ "$value" = "y" ]; then
                
            docker kill registry_temp > /dev/null 2>&1
            docker rm registry_temp > /dev/null 2>&1
        else
            echo "退出"
            exit 0
        fi
    fi

    docker run -d --name registry_temp --rm -v ${current_dir}/${build_path}/registry_data:/var/lib/registry/docker/registry -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 -p ${registry_port}:5000 registry:2

    if [ $? -ne 0 ]; then
        echo "仓库启动失败"
        exit 1
    fi

    for ((ratio=0;${ratio}<=5;ratio+=1))
    do
        sleep 1
        result=$(docker inspect --format '{{ .State.Status }}' registry_temp)
        if [ $? -ne 0 ]; then
            echo "获取仓库状态异常: ${result}"
            exit 1
        fi
        echo "status: ${result}"
        if [ "$result" == "running" ]; then
            echo "仓库已启动"
            return 0
        fi
    done
    return 1
}

funStopRegistry() {
    echo "停止本地临时仓库..."
    docker kill registry_temp > /dev/null
}

funExportImage() {
    echo "开始导入镜像到本地临时仓库..."
    rm -rf ${build_path}/registry_images.txt
    touch ${build_path}/registry_images.txt

    images=$1

    index=0
    for element in "${images[@]}"; do
        ((index++))
        origin_image=${element}
        echo "(${index}/${#images[@]}) 拉取镜像: ${origin_image}"
        docker pull ${origin_image} > /dev/null
        funCheckResult

        registry_image="127.0.0.1:${registry_port}/${origin_image#*/}"
        echo "(${index}/${#images[@]}) 推送镜像: ${registry_image}"
        docker tag ${origin_image} ${registry_image} > /dev/null
        funCheckResult
        docker push ${registry_image} > /dev/null 2>&1
        funCheckResult
        echo "${registry_image}" >> ${build_path}/registry_images.txt
    done
}

echo "读取镜像列表文件:" ${build_path}/${image_file} 
if [ -e ${build_path}/${image_file} ]; then
    echo "文件存在"
else
    echo "文件不存在"
    exit 0
fi

images=()

while IFS= read -r line
do
    images+=("$line")
done < ${build_path}/${image_file}

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

funRunRegistry ${registry_port}
    
if [ $? == 0 ]; then
    funExportImage ${images}
fi

funStopRegistry


funWait 2

echo "清理临时tag"
while IFS= read -r line
do
    docker rmi ${line}
done < ${build_path}/registry_images.txt
rm -rf .DS_Store

echo "压缩数据文件..."
tar -zcf ${build_path}/registry_data.tar.gz ${build_path}/registry_data ${build_path}/registry_images.txt

echo "清理本地临时仓库文件..."
rm -rf ${build_path}/registry_data ${build_path}/registry_images.txt

