--[[
* @file : Rpc.lua
* @type : service
* @author : linfeng
* @created : Thu Nov 23 2017 14:23:48 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : RPC 服务,负责同其他进程节点的通信
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"

local string = string
local table = table

local clusterCfg = {}

function response.updateClusterName( clusterInfo )
	local f = io.open(skynet.getenv("cluster"),"w+")
	f:write("__nowaiting = true\n")
	local clusterNodeKey = {}
	for nodeName in pairs(clusterInfo) do
		table.insert( clusterNodeKey, nodeName )
	end
	table.sort( clusterNodeKey, function (a, b)
		return a < b
	end)

	for _, nodeName in pairs(clusterNodeKey) do
		local str = nodeName.."=\""..clusterInfo[nodeName].ip..":"..clusterInfo[nodeName].port.."\"\n"
		f:write(str)
	end

	f:close()
	cluster.reload()

	clusterCfg = clusterInfo
end

function response.getClusterCfg()
	return clusterCfg
end

function init()
	snax.enablecluster()
	cluster.register(SERVICE_NAME)
end

function exit()

end