--[[
* @file : EntityLoad.lua
* @type : lualib
* @author : linfeng
* @created : Wed Nov 22 2017 12:11:14 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 加载数据逻辑实现
* Copyright(C) 2017 IGG, All rights reserved
]]

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local EntityImpl = require "EntityImpl"

local EntityLoad = {}

---@see 加载角色信息
function EntityLoad.loadRole( rid, tbname )
	if tbname then
		-- 加载某个指定表
		MSM[tbname][rid].req.Load( rid, rid )
	else
		-- 全部加载
		local entityCfg = EntityImpl:getEntityCfg( Enum.TableType.ROLE )
		if not entityCfg then return end
		for _,v in pairs(entityCfg) do
			if not v.noLoad then
				MSM[v.name][rid].req.Load( rid )
			end
		end
	end
end

---@see 保存角色信息
function EntityLoad.saveRole( rid, tbname, noSave )
	if tbname then
		-- 保存指定表
		if type(tbname) == "string" then
			MSM[tbname][rid].req.Save( rid, noSave )
		elseif type(tbname) == "table" then
			for _, subTbname in pairs(tbname) do
				MSM[subTbname][rid].req.Save( rid, noSave )
			end
		end
	else
		-- 全部保存
		local entityCfg = EntityImpl:getEntityCfg( Enum.TableType.ROLE )
		if not entityCfg then return end
		for _,v in pairs(entityCfg) do
			if not v.noLoad then
				MSM[v.name][rid].req.Save( rid, noSave )
			end
		end
	end
end

---@see 卸载角色信息
function EntityLoad.unLoadRole( rid, tbname )
	if tbname then
		-- 卸载某个指定表
		MSM[tbname][rid].req.UnLoad( rid )
	elseif rid then
		-- 指定角色全部卸载
		local entityCfg = EntityImpl:getEntityCfg( Enum.TableType.ROLE )
		if not entityCfg then return end
		for _,v in pairs(entityCfg) do
			if not v.noLoad then
				MSM[v.name][rid].req.UnLoad( rid )
			end
		end
	else
		-- 全部卸载所有角色
		local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
		local entityCfg = EntityImpl:getEntityCfg( Enum.TableType.ROLE )
		if not entityCfg then return end
		for _,v in pairs(entityCfg) do
			for i = 1, multiSnaxNum do
				if not v.noLoad then
					pcall(MSM[v.name][i].req.UnLoad)
				end
			end
		end
	end
end

---@see 删除角色
function EntityLoad.deleteRole( rid )
	local entityCfg = EntityImpl:getEntityCfg( Enum.TableType.ROLE )
		if not entityCfg then return end
		for _,v in pairs(entityCfg) do
			if not v.noLoad then
				MSM[v.name][rid].req.Delete( rid )
			end
		end
end

---@see 加载配置文件
function EntityLoad.loadConfig( reload )
	-- 全部加载
	local entityCfg = EntityImpl:getEntityCfg( Enum.TableType.CONFIG )
	if not entityCfg or table.empty(entityCfg) then return end
	for _,v in pairs(entityCfg) do
		SM[v.name].req.Load( reload )
	end
end

---@see 卸载配置文件
function EntityLoad.unloadConfig( )
	-- 全部卸载
	local entityCfg = EntityImpl:getEntityCfg( Enum.TableType.CONFIG )
	if not entityCfg then return end
	for _,v in pairs(entityCfg) do
		SM[v.name].req.UnLoad()
	end
end

---@see 加载common数据
function EntityLoad.loadCommon( )
	-- 全部加载
	local entityCfg = EntityImpl:getEntityCfg( Enum.TableType.COMMON )
	if not entityCfg then return end
	for _,v in pairs(entityCfg) do
		SM[v.name].req.Load()
	end
end

---@see 卸载common数据
function EntityLoad:unLoadCommon()
	-- 全部卸载
	local entityCfg = EntityImpl:getEntityCfg( Enum.TableType.COMMON )
	if not entityCfg then return end
	for _,v in pairs(entityCfg) do
		SM[v.name].req.UnLoad()
	end
end

return EntityLoad