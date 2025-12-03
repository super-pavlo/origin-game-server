--[[
 * @file : MapLevelMgr.lua
 * @type : snax single service
 * @author : linfeng
 * @created : 2019-12-30 15:36:42
 * @Last Modified time: 2019-12-30 15:36:42
 * @department : Arabic Studio
 * @brief : 地图层级管理
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"

---@see 初始化地图层级
function response.Init()
    -- 初始化AOI层级
    MSM.AoiMgr[Enum.MapLevel.CITY].req.initMapAoi(0, Enum.MapLevel.CITY) -- 城堡
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.initMapAoi(0, Enum.MapLevel.ARMY) -- 军队
    MSM.AoiMgr[Enum.MapLevel.RESOURCE].req.initMapAoi(0, Enum.MapLevel.RESOURCE) -- 资源
    MSM.AoiMgr[Enum.MapLevel.GUILD].req.initMapAoi(0, Enum.MapLevel.GUILD) -- 联盟
    MSM.AoiMgr[Enum.MapLevel.PREVIEW].req.initMapAoi(0, Enum.MapLevel.PREVIEW, CFG.s_Config:Get( "previewDataRadius" ) * 100) -- 预览层
end

---@see 角色进入各层级
function response.roleEnterMapLevel( _rid, _pos, _fd, _secret )
    MSM.AoiMgr[Enum.MapLevel.CITY].req.roleEnter( Enum.MapLevel.CITY, _rid, _pos, _pos, _fd, _secret )
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.roleEnter( Enum.MapLevel.ARMY, _rid, _pos, _pos, _fd, _secret )
    MSM.AoiMgr[Enum.MapLevel.RESOURCE].req.roleEnter( Enum.MapLevel.RESOURCE, _rid, _pos, _pos, _fd, _secret )
    MSM.AoiMgr[Enum.MapLevel.GUILD].req.roleEnter( Enum.MapLevel.GUILD, _rid, _pos, _pos, _fd, _secret )
    MSM.AoiMgr[Enum.MapLevel.PREVIEW].req.roleEnter( Enum.MapLevel.PREVIEW, _rid, _pos, _pos, _fd, _secret )
end

---@see 角色离开各层级
function response.roleLeaveMapLevel( _rid )
    local pos = { x = -1, y = -1 }
    MSM.AoiMgr[Enum.MapLevel.CITY].req.roleLeave( Enum.MapLevel.CITY, _rid, pos )
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.roleLeave( Enum.MapLevel.ARMY, _rid, pos )
    MSM.AoiMgr[Enum.MapLevel.RESOURCE].req.roleLeave( Enum.MapLevel.RESOURCE, _rid, pos )
    MSM.AoiMgr[Enum.MapLevel.GUILD].req.roleLeave( Enum.MapLevel.GUILD, _rid, pos )
    MSM.AoiMgr[Enum.MapLevel.PREVIEW].req.roleLeave( Enum.MapLevel.PREVIEW, _rid, pos )
end

---@see 角色重新进入各层级
function response.roleReEnterMapLevel( _rid, _pos, _fd, _secret )
    local pos = { x = -1, y = -1 }
    MSM.AoiMgr[Enum.MapLevel.CITY].req.roleLeave( Enum.MapLevel.CITY, _rid, pos )
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.roleLeave( Enum.MapLevel.ARMY, _rid, pos )
    MSM.AoiMgr[Enum.MapLevel.RESOURCE].req.roleLeave( Enum.MapLevel.RESOURCE, _rid, pos )
    MSM.AoiMgr[Enum.MapLevel.GUILD].req.roleLeave( Enum.MapLevel.GUILD, _rid, pos )
    MSM.AoiMgr[Enum.MapLevel.PREVIEW].req.roleLeave( Enum.MapLevel.PREVIEW, _rid, pos )

    MSM.AoiMgr[Enum.MapLevel.CITY].req.roleEnter( Enum.MapLevel.CITY, _rid, _pos, _pos, _fd, _secret )
    MSM.AoiMgr[Enum.MapLevel.ARMY].req.roleEnter( Enum.MapLevel.ARMY, _rid, _pos, _pos, _fd, _secret )
    MSM.AoiMgr[Enum.MapLevel.RESOURCE].req.roleEnter( Enum.MapLevel.RESOURCE, _rid, _pos, _pos, _fd, _secret )
    MSM.AoiMgr[Enum.MapLevel.GUILD].req.roleEnter( Enum.MapLevel.GUILD, _rid, _pos, _pos, _fd, _secret )
    MSM.AoiMgr[Enum.MapLevel.PREVIEW].req.roleEnter( Enum.MapLevel.PREVIEW, _rid, _pos, _pos, _fd, _secret )
end

---@see 角色移动镜头
function accept.roleUpdateMapLevel( _rid, _pos, _isPreview, _inPreview )
    if _isPreview then
        -- 客户端角色在预览层操作
        if not _inPreview then
            -- 服务端角退出其他层, 只更新预览层
            local pos = { x = -100000, y = -100000 }
            MSM.AoiMgr[Enum.MapLevel.CITY].post.roleUpdate( Enum.MapLevel.CITY, _rid, pos, pos )
            MSM.AoiMgr[Enum.MapLevel.ARMY].post.roleUpdate( Enum.MapLevel.ARMY, _rid, pos, pos )
            MSM.AoiMgr[Enum.MapLevel.RESOURCE].post.roleUpdate( Enum.MapLevel.RESOURCE, _rid, pos, pos )
            MSM.AoiMgr[Enum.MapLevel.GUILD].post.roleUpdate( Enum.MapLevel.GUILD, _rid, pos, pos )

            RoleLogic:setRole( _rid, { [Enum.Role.inPreview] = true } )
        end

        -- 更新角色在预览层的坐标
        MSM.AoiMgr[Enum.MapLevel.PREVIEW].post.roleUpdate( Enum.MapLevel.PREVIEW, _rid, _pos, _pos )
    else
        -- 客户端角色不在预览层
        MSM.AoiMgr[Enum.MapLevel.CITY].post.roleUpdate( Enum.MapLevel.CITY, _rid, _pos, _pos )
        MSM.AoiMgr[Enum.MapLevel.ARMY].post.roleUpdate( Enum.MapLevel.ARMY, _rid, _pos, _pos )
        MSM.AoiMgr[Enum.MapLevel.RESOURCE].post.roleUpdate( Enum.MapLevel.RESOURCE, _rid, _pos, _pos )
        MSM.AoiMgr[Enum.MapLevel.GUILD].post.roleUpdate( Enum.MapLevel.GUILD, _rid, _pos, _pos )
        MSM.AoiMgr[Enum.MapLevel.PREVIEW].post.roleUpdate( Enum.MapLevel.PREVIEW, _rid, _pos, _pos )
        if _inPreview then
            RoleLogic:setRole( _rid, { [Enum.Role.inPreview] = false } )
        end
    end
end