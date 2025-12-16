--[[
* @file : MonitorPublish.lua
* @type : service
* @author : linfeng
* @created : Thu Nov 23 2017 14:05:54 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : monitor_server 的发布服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
local cluster = require "skynet.cluster"
local sharedata = require "skynet.sharedata"
local string = string
local table = table
local snax = require "skynet.snax"
local Timer = require "Timer"

local clusterInfo = {}
local clusterWebInfo = {}
local thisNodeName
local serverId

---@see 更新集群的节点信息
local function updateClusterNodeInfo()
	local syncAgain = false
	local timeout, ret
	for node,_ in pairs(clusterInfo) do
		if node ~= thisNodeName then
			timeout, ret = Common.timeoutRun(2, Common.rpcCall, node, "MonitorSubscribe", "syncClusterInfo", clusterInfo)
			if timeout or not ret then
				-- 同步失败,移除node
				syncAgain = true
				clusterInfo[node] = nil
				clusterWebInfo[node] = nil
			end
		end
	end

	SM.Rpc.req.updateClusterName(clusterInfo)

	if syncAgain then
		updateClusterNodeInfo()
	end
end

---@see 集群健康检查
local function clusterHold()
	local sync = false
	local now = os.time()
	for node, nodeInfo in pairs(clusterInfo) do
		if node ~= thisNodeName then
			-- 服务器不在线(心跳超时)
			if nodeInfo.last + 6 <= now then
				sync = true
				clusterInfo[node] = nil
				clusterWebInfo[node] = nil
				LOG_INFO("node(%s) not alive or can't connect, remove it from cluster", node)
			end
		end
	end

	if sync then
		updateClusterNodeInfo()
	end
end

---@see 初始化
function init( selfNodeName )
	snax.enablecluster()
	cluster.register(SERVICE_NAME)
	if selfNodeName then
		thisNodeName = selfNodeName
		-- init self cluster info
		local ip = skynet.getenv("clusterip")
		local port = skynet.getenv("clusterport")
		local webIp = skynet.getenv("webip")
		local webPort = skynet.getenv("webport")
		clusterInfo[selfNodeName] = { ip = ip, port = tonumber(port)}
		clusterWebInfo[selfNodeName] = { ip = webIp, port = tonumber(webPort) }
	end

	sharedata.new( Enum.Share.NODELINENAME, { name = selfNodeName } )

	serverId = tonumber(skynet.getenv("serverid"))

	Timer.runEvery(300, clusterHold)

	SM.GCMgr.req.Init()
end


---@see 从其他服务节点请求.用于提交自己的节点信息.并返回整个集群的clusterInfo
---@param remoteName string @名称
---@param remoteIp string @地址
---@param remotePort string @端口
---@param remoteWebIp string @WEB地址
---@param remoteWebPort string @WEB端口
---@return table @整个分布集群的cluster info, eg: clusterinfo = { monitor = { ip = "127.0.0.1", port = 7000}, ... }
function response.sync( remoteName, remoteIp, remotePort, remoteWebIp, remoteWebPort )
	local tmpClusterInfo = table.copy(clusterInfo, true)
	tmpClusterInfo[remoteName] = { ip = remoteIp, port = tonumber(remotePort) }
	SM.Rpc.req.updateClusterName(tmpClusterInfo)

	-- 确保节点可以访问
	if Common.checkNodeAlive(remoteName, "MonitorSubscribe") then
		clusterInfo[remoteName] = { ip = remoteIp, port = tonumber(remotePort), last = os.time() }
		clusterWebInfo[remoteName] = { ip = remoteWebIp, port = tonumber(remoteWebPort) }
		updateClusterNodeInfo()
		LOG_INFO("remoteName(%s) remoteIp(%s) remotePort(%s) connected", remoteName, remoteIp, remotePort)
		return true
	else
		SM.Rpc.req.updateClusterName(clusterInfo)
	end
end

---@see 心跳
function response.heart( node )
	if not clusterInfo[node] then
		return false
	end

	clusterInfo[node].last = os.time()
	return true
end

---@see 重载配置
function response.reloadConfig()
	-- notify all other cluster node,reload config data
	for name,_ in pairs(clusterInfo) do
		if name ~= thisNodeName then
			LOG_INFO("pre reloadConfig(%s)", name)
			if not Enum.DebugMode or tonumber(name[name:len()]) == serverId then
				LOG_INFO("reloadConfig(%s)", name)
				Common.timeoutRun(10, Common.rpcCall, name,"MonitorSubscribe", "reloadConfig")
				LOG_INFO("reloadConfig(%s) ok", name)
			end
		end
	end
	return "cluster all node load config ok"
end

---@see 关闭集群
local function closeCluster()
    -- 关闭log
    snax.kill(SM.SysLog)
    skynet.abort()
end

---@see 十秒后重启集群
local function restartCluster( _branchName )
	Timer.runAfter( 10, closeCluster )
	os.execute("./start -i " .. _branchName)
end

---@see 重启集群
function response.restartCluster( isRestart, _branchName )
	LOG_INFO("restartCluster clusterInfo %s",tostring(clusterInfo))
	-- notify all other cluster node,restart
	for name,_ in pairs(clusterInfo) do
		if name:find("game") then -- 先通知gameserver,让数据更新到dbserver
			if not Enum.DebugMode or tonumber(name[name:len()]) == serverId then
				LOG_INFO("close %s",name)
				Common.timeoutRun(10, Common.rpcCall, name,"MonitorSubscribe", "restartCluster")
				LOG_INFO("close %s ok!",name)
			end
		end
	end

	-- notify all other cluster node,restart
	for name,_ in pairs(clusterInfo) do
		if name ~= thisNodeName and name:find("game") == nil then -- 不通知gameserver了,上面已经通知过
			if not Enum.DebugMode or tonumber(name[name:len()]) == serverId then
				LOG_INFO("close %s",name)
				Common.timeoutRun( 10, Common.rpcCall, name,"MonitorSubscribe", "restartCluster")
				LOG_INFO("close %s ok!",name)
			end
		end
	end

	clusterInfo = {}
	clusterWebInfo = {}

	-- 重启集群
	if isRestart then
		LOG_INFO("restart Cluster Node after 5s", thisNodeName)
		-- 5s后重启集群
		Timer.runAfter( 500, restartCluster, _branchName )
		return "restart cluster after 5s"
	else
		LOG_INFO("close this Cluster Node(%s) after 5s", thisNodeName)
		-- 5s后关闭掉此节点
		Timer.runAfter(500,closeCluster)
		return "close cluster after 5s"
	end
end

---@see 获取服务器集群列表信息
function response.getServerList()
	return clusterWebInfo
end

---@see web命令转发
function response.runWebCmd( serverNode, cmd, q, body )
	return Common.rpcCall( serverNode, "WebProxy", "RunWebCmd", cmd, q, body )
end