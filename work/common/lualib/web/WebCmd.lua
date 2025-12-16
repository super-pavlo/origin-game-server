--[[
 * @file : WebCmd.lua
 * @type : lualib
 * @author : linfeng
 * @created : 2019-03-29 08:54:13
 * @Last Modified time: 2019-03-29 08:54:13
 * @department : Arabic Studio
 * @brief : Web命令逻辑相关
 * Copyright(C) 2019 IGG, All rights reserved
]]

local crypt = require "skynet.crypt"
local EntityImpl = require "EntityImpl"
local memory = require "skynet.memory"
local lfs = require "lfs"
local skynet = require "skynet"
local snax = require "skynet.snax"
local cjson = require "cjson.safe"

local WebCmd = {}

--------------------------------------------------local function--------------------------------
local function listDir(path, fbox, subpath)
	local check = io.open(path,"r")
	if not check then return {} else check:close() end
	if string.sub(path, -1) == "/" then path = string.sub(path, 1, -2) end
	if not subpath then subpath = path end
	fbox = fbox or {}
    for file in lfs.dir(subpath) do
        if file ~= "." and file ~= ".." then
            local f = subpath..'/'..file
            local attr = lfs.attributes(f)
            assert (type(attr) == "table")
            if attr.mode == "directory" then
				listDir(path, fbox, f)
			elseif attr.mode == "file" then
				if string.sub(f, -4) == ".lua" then
					local filedir = string.sub(f, string.len(path)+2, -5)
					fbox[#fbox+1] = string.gsub(filedir, "/", ".")
				end
			end
        end
    end
    return fbox
end

local function readFile( filename )
	local f = io.open(filename, "rb")
	if not f then
		return nil, "Can't open " .. filename
	end
	local source = f:read "*a"
	f:close()
	return source
end

function WebCmd.hotfix()
	--get all lua service(include snax lua service)
	local allServices = skynet.call(".launcher", "lua", "LIST")
	local hotfixModules
	local responseRet = ""
	local fullHotfixName
	local nodeName = skynet.getenv("clusternode")
	local dir

	--snax lua service
	dir = string.format("hotfix/snax/%s/", nodeName)
	hotfixModules = listDir (dir)
	for _,hotfixName in pairs(hotfixModules) do
		fullHotfixName = dir .. hotfixName .. ".lua"
		local code = readFile(fullHotfixName)
		if code then
			local serviceName = "snlua snaxd " .. hotfixName
			for address,name in pairs(allServices) do
				if name == serviceName then
					local snaxObj = snax.bind(address, hotfixName) --snax service obj,use for snax.hotfix
					snax.hotfix(snaxObj, code)
				end
			end
			responseRet = responseRet .. string.format("hotfix snax(%s) over!\n", fullHotfixName)
		end
	end

	--lua service
	dir = string.format("hotfix/luaservice/%s/", nodeName)
	hotfixModules = listDir (dir)
	for _,hotfixName in pairs(hotfixModules) do
		fullHotfixName = dir .. hotfixName .. ".lua"
		local code = readFile(fullHotfixName)
		if code then
			for address,name in pairs(allServices) do
				if name == "snlua " .. hotfixName then
					skynet.call(address, "debug", "RUN", code)
				end
			end
			responseRet = responseRet .. string.format("hotfix luaservice(%s) over!\n", fullHotfixName)
		end
	end

	-- all snax service
	local snaxName = "snlua snaxd "
	local matchPartern = "snlua snaxd "
	fullHotfixName = string.format("hotfix/allservice/%s/hotfix.lua", nodeName)
	local code = readFile(fullHotfixName)
	if code then
		for address,name in pairs(allServices) do
			if name:find(snaxName) and not name:find("SysLog") then
				local snaxObj = snax.bind(address, string.trim( name, matchPartern )) --snax service obj,use for snax.hotfix
				snax.hotfix(snaxObj, code)
			end
		end
		responseRet = responseRet .. string.format("hotfix all snax service over!\n")
	end

	-- delete hotfix
	os.execute(string.format("rm -rf hotfix/allservice/%s", nodeName))
	os.execute(string.format("rm -rf hotfix/luaservice/%s", nodeName))
	os.execute(string.format("rm -rf hotfix/snax/%s", nodeName))

	return responseRet
end

---@see 重载配置
function WebCmd.reloadConfig()
	-- 只能通过 monitor 服务器重载
	if Common.getSelfNodeName():find("monitor") == nil then return "only through Monitor Server reloadConfig" end
	-- 通过 monitorpublish通知各服务器重载
	return SM.MonitorPublish.req.reloadConfig()
end

---@see 重载自身配置
function WebCmd.reloadSelfConfig()
	SM.MonitorSubscribe.req.reloadConfig()
	return "jsonpCallback(" .. cjson.encode( { result = true, name = Common.getSelfNodeName() } ) .. ")"
end

---@see 重启集群
function WebCmd.restartCluster( arg )
	-- 只能通过 monitor 服务器重启
	if Common.getSelfNodeName():find("monitor") == nil then return "only through Monitor Server restartCluster" end
	-- 通过 monitorpublish 重启集群
	return SM.MonitorPublish.req.restartCluster(true, arg.branch)
end

---@see 关闭集群
function WebCmd.closeCluster()
	-- 只能通过 monitor 服务器关闭
	if Common.getSelfNodeName():find("monitor") == nil then return "only through Monitor Server closeCluster" end
	-- 通过 monitorpublish 关闭集群
	return SM.MonitorPublish.req.restartCluster()
end

---@see 关闭自身服务.维护通知
function WebCmd.closeSelf(arg)
	if Common.getSelfNodeName():find("game") ~= nil then
		SM.System.post.Maintain(tonumber(arg.type) or 0)
	else
		SM.MonitorSubscribe.req.restartCluster()
	end
	return "jsonpCallback(" .. cjson.encode( { result = true, name = Common.getSelfNodeName() } ) .. ")"
end

---@see 重启游服所有线路
function WebCmd.restartGame()
	if Common.getSelfNodeName():find("game") == nil then
		return "only through Game Server restartGame"
	end

	-- 通知所有的线路重启
	local allGameNodes = Common.getClusterNodeByName(Common.getSelfNodeName(), true)
	for _, gameNode in pairs(allGameNodes) do
		Common.rpcSend(gameNode, "MonitorSubscribe", "closeAndStart")
	end

	return "jsonpCallback(" .. cjson.encode( { result = true, name = Common.getSelfNodeName() } ) .. ")"
end

---@see PM命令
function WebCmd.pmCmd( arg )
	if Common.getSelfNodeName():find("game") == nil then return end
	if not Enum.DebugMode then return end
	local PMLogic = require "PMLogic"
	local cmd = arg.cmd
	local rid = tonumber(arg.rid) or arg.rid
	local ret, result
	arg.cmd = nil
	arg.rid = nil
	arg = table.keytonumber(arg)
	table.tonumber(arg)
	if PMLogic[cmd] then
		ret, result = pcall(PMLogic[cmd], PMLogic, rid, table.unpack(arg) )
	else
		ret = "jsonpCallback(" .. cjson.encode({ error = "invalid cmd->" .. cmd }) .. ")"
	end

	if type(ret) == "boolean" then
		if ret then
			ret = result or { error = "success" }
		else
			ret = { error = result }
		end
	end

	return "jsonpCallback(" .. cjson.encode(ret) .. ")"
end

---@see 获取集群服务器列表
function WebCmd.getServerList()
print("getServerList")
	if Common.getSelfNodeName():find("monitor") == nil then return end
	local serverList = SM.MonitorPublish.req.getServerList()
    return "jsonpCallback(" .. cjson.encode(serverList) .. ")"
end

---@see 获取在线人数
function WebCmd.getOnlineCount()
	if Common.getSelfNodeName():find("game") == nil then return end
	return "jsonpCallback(" .. cjson.encode( { count = SM.OnlineMgr.req.getOnline() } ) .. ")"
end

---@see 获取服务器详细信息
function WebCmd.getServerInfo()
	local serverInfo = {}
	-- 所有的服务列表
	local serviceList = skynet.call(".launcher", "lua", "LIST")
	local serviceStat = skynet.call(".launcher", "lua", "STAT")
	local serviceMem = skynet.call(".launcher", "lua", "MEM")
	local meminfo = memory.info()
	local serviceCMem = {}
	for k,v in pairs(meminfo) do
		serviceCMem[skynet.address(k)] = v
	end

	serverInfo.totalcmem = memory.total()
	serverInfo.blockcmem = memory.block()
	serverInfo.service = {}
	local oneService
	for addr,name in pairs(serviceList) do
		oneService = {}
		oneService.addr = addr
		oneService.name = name

		-- 获取服务状态
		oneService.stat = serviceStat[addr]
		oneService.mem = serviceMem[addr]
		oneService.cmem = ( serviceCMem[addr] or 0 ) // 1024
		--[[
		local ok, info = pcall(skynet.call, addr, "debug", "INFO")
		if ok then
			oneService.info = info
		end
		]]

		table.insert( serverInfo.service, oneService )
	end
	return "jsonpCallback(" .. cjson.encode(serverInfo) .. ")"
end

---@see 获取战斗服务器上的当前所有战斗索引
function WebCmd.getBattleServerAll()
	local battleInfo = MSM.BattleLoop[1].req.getBattle()
	return "jsonpCallback(" .. cjson.encode(table.keytostring(battleInfo)) .. ")"
end

---@see 获取战斗服务器战斗相关信息
function WebCmd.getBattleServerDetail( arg )
	if Common.getSelfNodeName():find("battle") == nil then return end

	local battleIndex = tonumber(arg.battleIndex)
	if not battleIndex then return end
	local battleInfo = MSM.BattleLoop[battleIndex].req.getBattle( battleIndex ) or {}
	return "jsonpCallback(" .. cjson.encode(table.keytostring(battleInfo)) .. ")"
end

---@see 执行测试用例
function WebCmd.runTestCase()
	os.execute("lua ./tool/script/autotest/AutoTest.lua")
end

---@see 查询.更新数据
function WebCmd.modifyData( arg )
	local mode = tonumber(arg.mode) or arg.mode
	local tbname = arg.tbname
	local key = tonumber(arg.key) or arg.key
	local ret = {}
	if mode == 1 then
		-- 查询
		if tbname:find("d_") then
			ret = MSM[tbname][key].req.Get(key)
		elseif tbname:find("c_") then
			ret = SM[tbname].req.Get(key)
		end
	end

	return "jsonpCallback(" .. cjson.encode(table.keytostring(ret)) .. ")"
end

---@see 转换数据库的二进制和json数据
function WebCmd.transData( arg )
	local tbName = arg.tbName
	local tbType = arg.tbType
	local transType = arg.transType

	local cmd
	local index = 0
	local configEntity = self:getEntityCfg(tbType, tbName)
	local jsonData, rawData
	if transType == 1 then
		-- data -> json
		while true do
			cmd = string.format("select %s,%s from %s limit %d,1000", configEntity.key, configEntity.value, configEntity.name, index)
			local sqlRet = Common.mysqlExecute(cmd)
			if #sqlRet <= 0 then break end
			-- 转换数据
			for _, value in pairs(sqlRet) do
				jsonData = EntityImpl:unserializeSproto( configEntity.name, value[2] )
				jsonData = cjson.encode(jsonData)
				cmd = string.format("update %s set json = '%s' where %s = %d", configEntity.name, jsonData, configEntity.key, value[1])
				Common.mysqlExecute(cmd)
			end
			index = index + 1000
		end
	elseif transType == 2 then
		-- json -> data
		while true do
			cmd = string.format("select %s,json from %s limit %d,1000", configEntity.key, configEntity.name, index)
			local sqlRet = Common.mysqlExecute(cmd)
			if #sqlRet <= 0 then break end
			-- 转换数据
			for _, value in pairs(sqlRet) do
				jsonData = cjson.decode(value[2])
				rawData = EntityImpl:serializeSproto( configEntity.name, jsonData, true )
				cmd = string.format("update %s set %s = %s where %s = %d",
								configEntity.name, configEntity.value, rawData, configEntity.key, value[1])
				Common.mysqlExecute(cmd)
			end
			index = index + 1000
		end
	end

	return "jsonpCallback(" .. cjson.encode({ result = true }) .. ")"
end

return WebCmd
