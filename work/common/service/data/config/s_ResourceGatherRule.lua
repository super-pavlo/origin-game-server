
local string = string
local table = table
require "ConfigEntity"

local objEntity

function init()
	objEntity = class(ConfigEntity)

	objEntity = objEntity.new()
	objEntity.tbname = "s_ResourceGatherRule"

	objEntity:Init()
end

function response.Load( reload )
	objEntity:Load( reload )
end

function response.UnLoad()
	return objEntity:UnLoad()
end

function response.Set(row)
	objEntity:Set(row)
end

