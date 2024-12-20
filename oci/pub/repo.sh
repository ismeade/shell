#!/bin/bash

build_path="build"

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

        registry_image="127.0.0.1:${registry_port}/${origin_image##*/}"
        echo "(${index}/${#images[@]}) 推送镜像: ${registry_image}"
        docker tag ${origin_image} ${registry_image} > /dev/null
        funCheckResult
        docker push ${registry_image} > /dev/null 2>&1
        funCheckResult
        echo "${registry_image}" >> ${build_path}/registry_images.txt
    done
}
