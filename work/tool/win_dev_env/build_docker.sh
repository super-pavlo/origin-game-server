if [ $# -le 1 ]; then
    echo "Usage: build_docker.sh [container_name] [port_add]"
    exit
fi

container_name=$1
interval=2500

map_ssh=$((22 + $2 * $interval))
map_mysql=$((3306 + $2 * $interval))

map_cluster_begin=$((7000 + $2 * $interval))
map_cluster_end=$((7010 + $2 * $interval))
map_web_begin=$((8000 + $2 * $interval))
map_web_end=$((8010 + $2 * $interval))

map_nginx=$((10000 + $2 * $interval))
map_game_server=$((11000 + $2 * $interval))
map_chat_server=$((12000 + $2 * $interval))
map_netdata_port=$((19999 + $2 * $interval))

map_mongo=$((27017 + $2 * $interval))

docker stop ${container_name}
docker rm ${container_name}
docker rmi centos:coe
docker build --rm -t centos:coe -f centos7.Dockerfile ./

docker run -d --privileged=true \
-p ${map_ssh}:22 \
-p ${map_mysql}:3306 \
-p ${map_mongo}:27017 \
-p ${map_cluster_begin}-${map_cluster_end}:7000-7010 \
-p ${map_web_begin}-${map_web_end}:8000-8010 \
-p ${map_nginx}:10000 \
-p ${map_game_server}:11000 \
-p ${map_chat_server}:12000 \
-p ${map_netdata_port}:19999 \
-v //d/server:/home/server \
--name ${container_name} centos:coe init