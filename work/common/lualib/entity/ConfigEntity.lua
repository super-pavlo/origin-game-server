--[[
* @file : ConfigEntity.lua
* @type : lualib
* @author : linfeng
* @created : Tue Nov 21 2017 13:56:04 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : config 类型数据的实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local sharedata = require "skynet.sharedata"
local EntityImpl = require "EntityImpl"
require "Entity"

-- 定义ConfigEntity类型
ConfigEntity = class(Entity)

function ConfigEntity:ctor()

end

function ConfigEntity:dtor()

end

function ConfigEntity:Init()
	local ret = assert(EntityImpl:getEntityCfg( Enum.TableType.CONFIG, self.tbname ) )
	self.key = ret.key
	self.noreload = ret.noreload or false
end

function ConfigEntity:Load( reload )
	local rs = EntityImpl:loadConfig( self.tbname )
	if rs then
		if reload and not self.noreload then
			sharedata.update( self.tbname, rs )
			sharedata.flush()
		elseif not reload then
			sharedata.new( self.tbname, rs )
		end
	end
end

function ConfigEntity:UnLoad()
	sharedata.del( self.tbname )
end

function ConfigEntity:Set( recordset )
	sharedata.update( self.tbname, recordset )
	sharedata.flush()
end