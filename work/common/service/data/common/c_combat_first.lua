
local string = string
local table = table

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
require "CommonSingleEntity"

local objEntity

function init( index )
	objEntity = class(CommonSingleEntity)
	objEntity = objEntity.new()
	objEntity.tbname = "c_combat_first"

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

function response.Add( pid, row )
	return objEntity:Add( pid, row )
end

function accept.Add( pid, row )
	objEntity:Add( pid, row )
end

function response.Delete( pid )
	return objEntity:Delete( pid )
end

function response.DeleteAll()
	return objEntity:DeleteAll()
end

function response.Set( pid, field, value )
	return objEntity:Set(pid, field, value)
end

function accept.Set( pid, field, value )
	objEntity:Set(pid, field, value)
end

function response.Get( pid, field )
	return objEntity:Get( pid, field )
end

function response.Update( pid, row, lockFlag )
	return objEntity:Update( pid, row, lockFlag )
end

function response.NewId()
	return objEntity:NewId()
end

function response.LockSet( pid, field, value )
	return objEntity:Set( pid, field, value, true )
end

