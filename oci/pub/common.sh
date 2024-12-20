#!/bin/bash 


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
