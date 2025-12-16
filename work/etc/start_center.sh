#优先执行common脚本
bash etc/start_common.sh

#工作线程数量(根据CPU核心数而定)
export WORK_THREAD=8
#是否启动为守护模式
export DAEMON=1

#cluster配置
export MONITOR_NODE_NAME="monitor"
export MONITOR_NODE_IP="127.0.0.1"
export MONITOR_NODE_PORT="57000"

#自身节点信息
export CLUSTER_NODE="center"
export CLUSTER_IP="127.0.0.1"
export CLUSTER_PORT="57002"

#WEB监听端口
export WEB_IP="127.0.0.1"
export WEB_PORT=58002

#skynet DEBUG端口(telnet),0为不开启
export DEBUG_PORT=56002

#服务器ID
export SERVER_ID=1
#日志服务器节点ID
export LOGNODE=1
#是否是联盟名称服
export GUILD_NAME_CENTER=true
#是否是地狱活动服
export HELL_ACTIVITY_CENTER=true
#是否是角色信息服
export ROLE_CENTER=true

#启动
chmod +x co
mkdir -p logs
touch etc/cluster_${CLUSTER_NODE}${SERVER_ID}.lua
./co etc/center.conf
