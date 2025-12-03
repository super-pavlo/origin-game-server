
require "skynet.manager"
local string = string
local table = table

local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
require "RoleMultiEntity"

local objEntity

function init(index)
	objEntity = class(RoleMultiEntity)

	objEntity = objEntity.new()
	objEntity.tbname = "d_building"

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

function response.Add( rid, indexId, row )
	return objEntity:lock( rid )( objEntity.Add, objEntity, rid, indexId, row )
end

function response.Delete( rid, indexId )
	return objEntity:lock( rid )( objEntity.Delete, objEntity, rid, indexId )
end

function response.Set( rid, indexId, field, value )
	return objEntity:lock( rid )( objEntity.Set, objEntity, rid, indexId, field, value )
end

function response.Update( rid, indexId, row, saveFlag )
	return objEntity:lock( rid )( objEntity.Update, objEntity, rid, indexId, row, saveFlag )
end

function response.Get( rid, indexId, field )
	return objEntity:lock( rid )( objEntity.Get, objEntity, rid, indexId, field )
end

function response.NewId()
	return objEntity:NewId()
end

function response.Save( rid, noSave )
	return objEntity:lock( rid )( objEntity.Save, objEntity, rid, noSave )
end

