

require "skynet.manager"
local string = string
local table = table

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
require "RoleSingleEntity"

local objEntity

function init(index)
	objEntity = class(RoleSingleEntity)

	objEntity = objEntity.new()
	objEntity.tbname = "d_user"

	objEntity:Init()
	snax.enablecluster()
	cluster.register(SERVICE_NAME .. index)
end

function response.empty()

end

function response.Load( rid )
	return objEntity:lock( rid )( objEntity.Load, objEntity, rid )
end

function response.UnLoad( rid )
	if rid then
		return objEntity:lock( rid )( objEntity.UnLoad, objEntity, rid )
	else
		return objEntity:UnLoad()
	end
end

function response.Add( rid, row )
	return objEntity:lock( rid )( objEntity.Add, objEntity, rid, row )
end

function response.Delete( rid )
	return objEntity:lock( rid )( objEntity.Delete, objEntity, rid )
end

function response.Set( rid, field, value )
	return objEntity:lock( rid )( objEntity.Set, objEntity, rid, field, value )
end

function response.Update( rid, row, lockFlag, saveFlag )
	return objEntity:lock( rid )( objEntity.Update, objEntity, rid, row, lockFlag, saveFlag )
end

function response.Get( rid, field )
	return objEntity:Get( rid, field )
end

function response.NewId()
	 return objEntity:NewId()
end

function response.Save( rid, noSave )
	return objEntity:lock( rid )( objEntity.Save, objEntity, rid, noSave )
end

function response.LockSet( rid, field, value )
	return objEntity:lock( rid )( objEntity.Set, objEntity, rid, field, value, true )
end

