
local string = string
local table = table
local math = math

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
require "CommonMultiEntity"

local objEntity

function init(index)
	objEntity = class(CommonMultiEntity)

	objEntity = objEntity.new()
	objEntity.tbname = "c_guild_gift"

	objEntity:Init()
	snax.enablecluster()
	cluster.register(SERVICE_NAME)
end

function response.empty()

end

function response.Load()
	return objEntity:Load()
end

function response.UnLoad()
	return objEntity:UnLoad()
end

function response.Add( pid, indexId, row )
	return objEntity:Add( pid, indexId,row )
end

function response.Delete( pid, indexId )
	return objEntity:Delete( pid, indexId )
end

function response.Set( pid, indexId, key, value )
	return objEntity:Set( pid, indexId, key, value )
end

function response.Get( pid, indexId, key )
	return objEntity:Get( pid, indexId, key )
end

function response.Update( pid, indexId, row )
	return objEntity:Update( pid, indexId, row )
end

