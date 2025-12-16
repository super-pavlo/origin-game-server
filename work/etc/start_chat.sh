#优先执行common脚本
bash etc/start_common.sh

#工作线程数量(根据CPU核心数而定)
export WORK_THREAD=8
#是否启动为守护模式
export DAEMON=1

#游服配置
export HOST="0.0.0.0"
export PORT=44446
export MAX_CLIENT=100000
export CONNECT_IP="127.0.0.1"
export CONNECT_REAL_IP="127.0.0.1"

#cluster配置
export MONITOR_NODE_NAME="monitor"
export MONITOR_NODE_IP="127.0.0.1"
export MONITOR_NODE_PORT="57000"

#自身节点信息
export CLUSTER_IP="127.0.0.1"
export CLUSTER_PORT="57009"
export CLUSTER_NODE="chat"

#WEB监听端口
export WEB_IP="127.0.0.1"
export WEB_PORT=58009

#skynet DEBUG端口(telnet),0为不开启
export DEBUG_PORT=56009

#服务器ID
export SERVER_ID=1
#日志服务器节点ID
export LOGNODE=1

#启动
chmod +x co
mkdir -p logs
touch etc/cluster_${CLUSTER_NODE}${SERVER_ID}.lua
./co etc/chat.conf
