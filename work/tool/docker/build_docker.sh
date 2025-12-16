#!/bin/sh
if [ $# -le 1 ]; then
    echo "Usage: build_docker.sh [container_name] [port_add]"
    exit
fi
container_name=$1
interval=2500
map_mysql=$((3306 + $2 * $interval))
map_ssh=$((22 + $2 * $interval))
map_clunster_begin=$((7000 + $2 * $interval))
map_clunster_end=$((7010 + $2 * $interval))
map_web_begin=$((8000 + $2 * $interval))
map_web_end=$((8010 + $2 * $interval))

docker stop ${container_name}
docker rm ${container_name}
docker rmi centos:7
docker build --rm -t centos:7 -f centos7.Dockerfile ./
if [ "${container_name}" = "TON-Master-Server" ]; then
    docker run -d --privileged=true \
    -p ${map_mysql}:3306 \
    -p 9900-10000:9900-10000 \
    -p ${map_ssh}:22 \
    -p ${map_clunster_begin}-${map_clunster_end}:${map_clunster_begin}-${map_clunster_end} \
    -p ${map_web_begin}-${map_web_end}:${map_web_begin}-${map_web_end} \
    -v /etc/localtime:/etc/localtime:ro \
    --name ${container_name} centos:7 /usr/sbin/init
else
    docker run -d --privileged=true \
    -p ${map_mysql}:3306 \
    -p ${map_ssh}:22 \
    -p ${map_clunster_begin}-${map_clunster_end}:${map_clunster_begin}-${map_clunster_end} \
    -p ${map_web_begin}-${map_web_end}:${map_web_begin}-${map_web_end} \
    -v /etc/localtime:/etc/localtime:ro \
    --name ${container_name} centos:7 /usr/sbin/init
fi

#enter container
docker exec -ti ${container_name} /bin/bash