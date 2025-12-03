--[[
* @file : Common.lua
* @type : lualib
* @author : linfeng
* @created : Thu Nov 23 2017 14:52:57 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 全局函数实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local crypt = require "skynet.crypt"
require "skynet.manager"
local string = string
local table = table
local snax = require "skynet.snax"
local Timer = require "Timer"

local Common = {}

---@see 判断是否是个table
function Common.isTable( t )
    return type(t) == "table"
end

---@see 判断是否是个number
function Common.isNumber( t )
    return type(t) == "number"
end

---@see 判断是否是个string
function Common.isString( t )
    return type(t) == "string"
end

---@see 移除全空的table
function Common.isEmptyTable( t )
    for _,subt in pairs(t) do
        if Common.isTable( subt ) then
            if not Common.isEmptyTable( subt ) then return false end
        else
            return false
        end
    end
    return true
end

---@see 执行mysql查询
---@param sql string 要执行的 sql 语句
---@param routeIndex integer 路由的索引,选择不同的 mysql agent,为 nil 时,默认为第一个
---@return table 执行结果
function Common.mysqlExecute(sql, routeIndex)
    routeIndex = routeIndex or 0
    return MSM.MysqlAgent[routeIndex].req.query(sql)
end

---@see 执行loginmysql查询
---@param sql string 要执行的 sql 语句
---@param routeIndex integer 路由的索引,选择不同的 mysql agent,为 nil 时,默认为第一个
---@return table 执行结果
function Common.loginMysqlExecute(sql, routeIndex)
    routeIndex = routeIndex or 0
    return MSM.LoginMysqlAgent[routeIndex].req.query(sql)
end

---@see 执行redis命令
---@param cmd table 要执行的 redis 命令,包含参数
---@param routeIndex integer 路由的索引,选择不同的 redis agent,为 nil 时,默认为第一个
---@param pipeline boolean 是否通过管道执行 redis 命令,为 true时,
---@return table 执行结果
function Common.redisExecute(cmd, routeIndex, pipeline)
    routeIndex = routeIndex or 0
    return MSM.RedisAgent[routeIndex].req.Do(cmd, pipeline)
end

---@see 缓存一个redis.lua脚本
function Common.redisScriptLoad( script, routeIndex )
    routeIndex = routeIndex or 0
    return MSM.RedisAgent[routeIndex].req.scriptLoad( script )
end

---@see 通过scan模糊查询
----@param _scanType integer 命令模式(Enum.Scan定义)
----@param _key string key值
----@param _match string 匹配串(glob风格)
----@param _count integer 一次迭代的count,默认为1000
----@param _valueFlag boolean true只返回value
---@return table
function Common.scanQuery( _scanType, _key, _match, _count, _valueFlag )
    _scanType = _scanType or Enum.Scan.KEY
    _count = _count or 1000
    local cursor = 0
    local ret
    local retValue = {}
    while true do
        local cmd = { _scanType, _key, cursor, "MATCH", _match, "COUNT", _count }
        ret = Common.redisExecute( cmd )
        if ret then
            cursor = tonumber(ret[1])
            if not _valueFlag then
                table.merge( retValue, ret[2] )
            else
                for i, value in pairs( ret[2] ) do
                    if i%2 == 0 then
                        table.insert( retValue, value )
                    end
                end
            end
        else
            break
        end

        if cursor == 0 then break end
    end
    return retValue
end

---@see 获取一个远程的snax服务
---@param node string 远程的 skynet 节点名称
---@param svrname string 远程的 snax service 名称
---@return any 远程服务在本地的代理,失败返回 nil
function Common.getRemoteSvr(node, svrname)
    local cluster = require "skynet.cluster"
    local ok, snaxObj, address
    ok, address = pcall(cluster.query, node, svrname)
	if not ok then
		LOG_ERROR("cluster query node(%s) svrname(%s) fail:%s", node, svrname, address)
		return nil
	end
	ok,snaxObj = pcall(cluster.snax, node, svrname, address)
	if not ok then
		LOG_ERROR("cluster snax node(%s) svrname(%s) fail:%s", node, svrname, snaxObj)
		return nil
	end

	if snaxObj then
		return snaxObj
	else
		LOG_SKYNET("Common.getRemoteSvr,snax remote node:%s svr:%s fail", node, svrname)
        return nil
    end
end

---@see 执行一个函数.进行超时判断
---@param timeout integer 超时秒数
---@param func function 执行函数
---@param ... any 参数列表
---@return boolean true为超时,其他为非超时
function Common.timeoutRun(timeout, func, ...)
    local co = coroutine.running()
    local ret, data
    local skynet = require "skynet"
    local funcArg = { ... }
    skynet.fork(function ()
        ret, data = pcall(func, table.unpack(funcArg))
        if co then skynet.wakeup(co) end
    end)

    skynet.sleep(timeout * 100)
    co = nil -- prevent wakeup after call
    if ret ~= nil then
        return nil,data
    end
    return true
end

---@see 发起一个远程RpcCall.将阻塞协程
---@param node string 远程的 skynet 节点名称
---@param svrname string 远程的 snax service 名称
---@param method string 远程的 snax service 的 方法
---@param ... any 参数
---@return any 远程调用结果,失败返回 nil
function Common.rpcCall(node, svrname, method, ...)
    local func
    if Common.getSelfNodeName() == node then
        func = SM[svrname].req[method]
    else
        local remoteSvr = Common.getRemoteSvr(node, svrname)
        if not remoteSvr then
            LOG_SKYNET("Common.rpcCall,snax remote node:%s svr:%s fail", node, svrname)
            return nil
        end
        func = remoteSvr.req[method]
    end

    local ok, ret, ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9 = pcall(func, ...)
    if not ok then
        LOG_SKYNET("Common.rpcCall %s-%s-%s Fail->%s", node, svrname, method, ret)
        return nil
    end
    local retValue = { ret, ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9 }
    return table.unpack(retValue)
end

---@see 发起一个远程RpcSend.立即返回不等待结果
---@param node string 远程的 skynet 节点名称
---@param svrname string 远程的 snax service 名称
---@param method string 远程的 snax service 的 方法
---@param ... any 参数
---@return any 远程调用结果,失败返回 nil
function Common.rpcSend(node, svrname, method, ...)
    local func
    if Common.getSelfNodeName() == node then
        func = SM[svrname].post[method]
    else
        local remoteSvr = Common.getRemoteSvr(node, svrname)
        if not remoteSvr then
            LOG_SKYNET("Common.rpcSend,snax remote node:%s svr:%s fail", node, svrname)
            return nil
        end
        func = remoteSvr.post[method]
    end

    local ok, ret = pcall(func, ...)
    if not ok then
        LOG_SKYNET("Common.rpcSend %s-%s-%s Fail->%s", node, svrname, method, ret)
        return nil
    end
    return ret
end

---@see 发起一个远程RpcCall.将阻塞协程
---@param node string 远程的 skynet 节点名称
---@param svrname string 远程的 snax service 名称
---@param method string 远程的 snax service 的 方法
---@param ... any 参数
---@return any 远程调用结果,失败返回 nil
function Common.rpcMultiCall(node, svrname, method, index, ...)
    local func
    if Common.getSelfNodeName() == node then
        func = MSM[svrname][index].req[method]
    else
        local skynet = require "skynet"
		--默认DEFUALT_SNAX_SERVICE_NUM个子服务
        local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
        local idx = index
        if idx > multiSnaxNum or idx < 1 then
            idx = idx % multiSnaxNum + 1
        end
        local remoteSvr = Common.getRemoteSvr(node, svrname .. idx)
        if not remoteSvr then
            LOG_SKYNET("Common.rpcMultiCall, snax remote node:%s svr:%s fail", node, svrname)
            return nil
        end
        func = remoteSvr.req[method]
    end

    local ok, ret, ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9 = pcall(func, index, ...)

    if not ok then
        LOG_SKYNET("Common.rpcMultiCall %s-%s-%s Fail->%s", node, svrname, method, ret)
        return nil
    end
    return ret, ret1, ret2, ret3, ret4, ret5, ret6, ret7, ret8, ret9
end

---@see 发起一个远程RpcSend.立即返回不等待结果
---@param node string 远程的 skynet 节点名称
---@param svrname string 远程的 snax service 名称
---@param method string 远程的 snax service 的 方法
---@param ... any 参数
---@return any 远程调用结果,失败返回 nil
function Common.rpcMultiSend(node, svrname, method, index, ...)
    local func
    if Common.getSelfNodeName() == node then
        func = MSM[svrname][index].post[method]
    else
        local skynet = require "skynet"
		--默认DEFUALT_SNAX_SERVICE_NUM个子服务
        local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
        local idx = index
        if idx > multiSnaxNum or idx < 1 then
            idx = idx % multiSnaxNum + 1
        end
        local remoteSvr = Common.getRemoteSvr(node, svrname .. idx)
        if not remoteSvr then
            LOG_SKYNET("Common.rpcMultiSend, snax remote node:%s svr:%s fail", node, svrname)
            return nil
        end
        func = remoteSvr.post[method]
    end

    local ok, ret = pcall(func, index, ...)

    if not ok then
        LOG_SKYNET("Common.rpcMultiSend %s-%s-%s Fail->%s", node, svrname, method, ret)
        return nil
    end
    return ret
end

---@see 根据名称获取cluster节点信息
---@param name string 节点名称
---@param fuzzy boolean 是否模糊匹配
---@return string 返回匹配到的节点名称
function Common.getClusterNodeByName(name, fuzzy)
    local clusterInfo = SM.Rpc.req.getClusterCfg()
    local ret
    if clusterInfo then
        for nodeName, _ in pairs(clusterInfo) do
            if fuzzy then
                if nodeName:find(name) ~= nil then
                    if not ret then
                        ret = {}
                    end
                    table.insert(ret, nodeName)
                end
            else
                if nodeName == name then
                    ret = nodeName
                    break
                end
            end
        end
    end

    return ret
end

---@see 获取本节点的名称
function Common.getSelfNodeName()
    local sharedata = require "skynet.sharedata"
    return sharedata.query( Enum.Share.NODENAME ).name
end

---@see 获取本节点ID
function Common.getSelfNodeId()
    local skynet = require "skynet"
    return skynet.getenv("serverid")
end

---@see 获取聊天服务节点名称
function Common.getChatNode()
    local sharedata = require "skynet.sharedata"
    return sharedata.query( Enum.Share.CHATNODE ).name
end

---@see 获取center服务节点名称
function Common.getCenterNode()
    local sharedata = require "skynet.sharedata"
    return sharedata.query( Enum.Share.CENTERNODE ).name
end

---@see 获取push服务节点名称
function Common.getPushNode()
    local sharedata = require "skynet.sharedata"
    return sharedata.query( Enum.Share.PUSHNODE ).name
end

---@see 获取db服务节点名称
function Common.getDbNode()
    local sharedata = require "skynet.sharedata"
    return sharedata.query( Enum.Share.DBNODE ).name
end

---@see 获取服务器开服时间.unix时间戳
function Common.getSelfNodeOpenTime()
    local sharedata = require "skynet.sharedata"
    return sharedata.query( Enum.Share.OPENTIME ).time
end

---@see 服务器启动c_map_object是否加载完成
function Common.getMapObjectLoadFinish()
    local mapObjectLoad = Common.redisExecute( { "Get", Enum.Share.MapObjectLoad } )
    return tonumber( mapObjectLoad ) > 0
end

---@see 获取服务器开服天数.unix时间戳
function Common.getSelfNodeOpenDays()
    local openTime = Common.getSelfNodeOpenTime()
    local openDays = Timer.getDiffDays( openTime, os.time() )
    if openDays < 1 then
        openDays = 1 -- 开服第一天算一天
    else
        openDays = openDays + 1
    end

    return openDays
end

---@see 根据username获uid和subid
function Common.getUSidByUserName(_username)
	-- base64(uid)@base64(server)#base64(subid)
	local uid, _, subid = _username:match "([^@]*)@([^#]*)#(.*)"
	return tonumber(crypt.base64decode(uid)), crypt.base64decode(subid)--, crypt.base64decode(servername)
end

---@see 根据rid获取Agent实例
function Common.getAgentByRid( _rid )
    local agentHandle = MSM.AgentMgr[_rid].req.getAgentHandle( _rid )
    if agentHandle then
        local agentName = "Agent"
        return snax.bind(agentHandle, agentName)
    end
end

---@see 根据rid获取username和agent
function Common.getUserNameAndAgentByRid( _rid )
    if not Common.isTable( _rid ) then
        _rid = { _rid }
    end

    local usernames = {}
    local agentHandles = {}
    for _,rid in pairs(_rid) do
        local username, agentHandle = MSM.AgentMgr[rid].req.getUserNameAndAgentByRid( rid )
        if agentHandle then
            local agentName = "Agent"
            agentHandle = snax.bind(agentHandle, agentName)
            table.insert( usernames, username )
            table.insert( agentHandles, agentHandle )
        end
    end

    if table.empty(usernames) then usernames = nil end
    if table.empty(agentHandles) then agentHandles = nil end

    return usernames, agentHandles
end

---@see 根据rid获取username
function Common.getUserNameByRid( _rid )
    if not Common.isTable( _rid ) then
        return MSM.AgentMgr[_rid].req.getUserNameByRid( _rid )
    else
        local usernames = {}
        local username
        for _,rid in pairs(_rid) do
            username = MSM.AgentMgr[rid].req.getUserNameByRid( rid )
            if username then
                table.insert( usernames, username )
            end
        end
        return usernames
    end
end

---@see 向rid推送消息
----@param _rid integer 角色ID
----@param _name string 内容名称
----@param _value any 内容
----@param _block boolean 是否使用阻塞版本
function Common.syncMsg( _rid, _name, _value, _block, _sendNow, _notLog, _cache, _skipOnline )
    if not Common.isTable(_rid) then _rid = { _rid } end

    if _block then
        for _,rid in pairs(_rid) do
            MSM.PushMsg[rid].req.syncMsg( rid, _name, _value, _sendNow, _notLog, _cache, _skipOnline )
        end
    else
        for _,rid in pairs(_rid) do
            MSM.PushMsg[rid].post.syncMsg( rid, _name, _value, _notLog, _cache, _skipOnline )
        end
    end
end

---@see and
function Common.addFlag( _value, _flag )
    _value = _value | _flag
    return _value
end

---@see or
function Common.checkFlag( _value, _flag )
    return ( _value & _flag ) ~= 0
end

---@see 获取SceneMgr对象
function Common.getSceneMgr( _mapId )
    local SceneMgrObj = MSM.AoiMgr[_mapId].req.getSceneMgr( _mapId )
    if SceneMgrObj then
        return snax.bind(SceneMgrObj, "SceneMgr")
    end
end

---@see 获取服务器在线人数
function Common.getOnlineCount( gameNode )
    return Common.rpcCall( gameNode, "OnlineMgr", "getOnline" )
end

---@see 数据封包拆包
function Common.SplitPackage( _msg )
	local pushMsgLen = _msg:len()
    local retMsg = {}
    local index = 0
    local allPackageSize = 0
    while pushMsgLen > 0 do
        table.insert( retMsg, _msg:sub(index * Enum.MaxPackageSize + 1, (index + 1) * Enum.MaxPackageSize) )
		if pushMsgLen > Enum.MaxPackageSize then
			pushMsgLen = pushMsgLen - Enum.MaxPackageSize
            index = index + 1
		else
            pushMsgLen = 0
        end
        allPackageSize = allPackageSize + 1
	end
	return retMsg, allPackageSize
end

---@see 根据语言和平台获取GameId
function Common.getGameId( _platform, _language )
    if _platform == Enum.DeviceType.ANDROID then
        if _language == Enum.LanguageType.ENGLISH then
            return Enum.GameID.ANDROID_EN
        elseif _language == Enum.LanguageType.ARABIC then
            return Enum.GameID.ANDROID_ARB
        elseif _language == Enum.LanguageType.CHINESE then
            return Enum.GameID.ANDROID_CN
        elseif _language == Enum.LanguageType.TURKEY then
            return Enum.GameID.ANDROID_TUR
        end
    elseif _platform == Enum.DeviceType.IOS then
        if _language == Enum.LanguageType.ENGLISH then
            return Enum.GameID.IOS_EN
        elseif _language == Enum.LanguageType.ARABIC then
            return Enum.GameID.IOS_ARB
        elseif _language == Enum.LanguageType.CHINESE then
            return Enum.GameID.IOS_CN
        elseif _language == Enum.LanguageType.TURKEY then
            return Enum.GameID.IOS_TUR
        end
    end

    return 0
end

---@see 检查某个节点是否可连接
function Common.checkNodeAlive( node, server )
    local cluster = require "skynet.cluster"
	local ok, address = pcall(cluster.query, node, server)
	return ok == true and type(address) == "number"
end

---@see 检查指定节点是否存在
function Common.checkNodeExist( node )
    return Common.getClusterNodeByName( node ) ~= nil
end

---@see 生成新的对象索引
function Common.newMapObjectIndex()
    return Common.redisExecute( { "incr", "mapObjectIndex" } )
end

---@see 生成新的远征地图索引
function Common.newExpeditionMapIndex()
    return Common.redisExecute( { "incr", "expeditionMapObjectIndex" } ) + Enum.MapLevel.EXPEDITION
end

---@see 查询rid是否在线
function Common.offOnline( _rid )
    local roleInfo = MSM.d_role[_rid].req.Get( _rid, { Enum.Role.isAfk, Enum.Role.online} )
    return (roleInfo.isAfk or not roleInfo.online)
end

---@see 角色是否afk
function Common.isAfk( _rid )
    return MSM.d_role[_rid].req.Get( _rid, Enum.Role.isAfk ) == true
end

---@see 服务器是否启动中
function Common.isServerStart()
    local sharedata = require "skynet.sharedata"
    return sharedata.query(Enum.Share.ServerStart).start
end

---@see 主动GC所有lua服务
function Common.gcAllServiceLuaMem()
    local skynet = require "skynet"
    skynet.call(".launcher", "lua", "GC")
end

---@see 发送资源阈值警告
function Common.sendResourceAlarm( _rid, _resourceId, _resourceNum )
    if Enum.DebugMode then
        -- 调试模式不发送警告
        return
    end
    local RoleLogic = require "RoleLogic"
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.iggid, Enum.Role.language, Enum.Role.platform } )
    if roleInfo then
        local gameId = Common.getGameId( roleInfo.platform, roleInfo.language )
        if gameId then
            local pushNode = Common.getPushNode()
            Common.rpcSend( pushNode, "AlarmMgr", "alarmResource", roleInfo.iggid, _rid, gameId, _resourceId, _resourceNum )
        end
    end
end

---@see 发送开服异常
function Common.sendGameOpenFail( _gameNode, _err )
    if Enum.DebugMode then
        -- 调试模式不发送警告
        return
    end
    local pushNode = Common.getPushNode()
    Common.rpcSend( pushNode, "AlarmMgr", "openGameFail", _gameNode, _err )
end

---@see 发送开服成功
function Common.sendGameOpenSuccess( _gameNode )
    if Enum.DebugMode then
        -- 调试模式不发送警告
        return
    end
    local pushNode = Common.getPushNode()
    Common.rpcSend( pushNode, "AlarmMgr", "openGameSuccess", _gameNode )
end

---@see 发送关服成功
function Common.sendCloseNodeSuccess( _nodeName )
    if Enum.DebugMode then
        -- 调试模式不发送警告
        return
    end
    -- 这里dbserver也会调用到
    local pushNode = Common.getClusterNodeByName("push", true)
    if pushNode and not table.empty(pushNode) then
        Common.rpcSend( pushNode[1], "AlarmMgr", "closeNodeSuccess", _nodeName )
    end
end

---@see 尝试持有分布式锁.利用redis
function Common.tryLock( _name )
    local skynet = require "skynet"
    local cmd = { "SETNX", _name, 1 }
    while Common.redisExecute(cmd) == 0 do
        skynet.sleep(1)
    end
    -- 10s time out
    Common.redisExecute( { "EXPIRE", _name, 10 } )
    return true
end

---@see 释放分布式锁.利用redis
function Common.unLock( _name )
    Common.redisExecute( { "DEL", _name } )
end

return Common