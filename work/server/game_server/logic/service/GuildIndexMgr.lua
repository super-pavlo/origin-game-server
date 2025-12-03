--[[
* @file : GuildIndexMgr.lua
* @type : snax multi service
* @author : dingyuchao
* @created : Wed Apr 08 2020 13:29:14 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 联盟相关修改标识管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

-- {
--      guildId =
--      {
--          guildIndex = 1,
--          noticeIndex = 1,
--      }
-- }
local guildIndexs = {}

---@see 初始化联盟相关修改标识
local function initGuildIndex( _guildId )
    if guildIndexs[_guildId] then return end

    -- 初始化联盟修改标识
    guildIndexs[_guildId] = {
        guildId = _guildId,
        guildIndex = 1,
        noticeIndex = 1,
        applyGlobalIndex = 1,
        memberGlobalIndex = 1,
        depotRecordIndex = 1,
        requestHelpGlobalIndex = 1,
        welcomeEmailIndex = 1,
        buildGlobalIndex = 1,
        resourcePointIndex = 1,
        holyLandGlobalIndex = 1,
        applys = {},
        members = {},
        requestHelps = {},
        builds = {},
        holyLands = {}
    }
end

---@see 获取联盟修改标识
function response.getGuildIndex( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId].guildIndex
end

---@see 更新联盟修改标识
function accept.addGuildIndex( _guildId )
    initGuildIndex( _guildId )

    guildIndexs[_guildId].guildIndex = guildIndexs[_guildId].guildIndex + 1
end

---@see 更新联盟修改标识
function response.addGuildIndex( _guildId )
    initGuildIndex( _guildId )

    guildIndexs[_guildId].guildIndex = guildIndexs[_guildId].guildIndex + 1

    return guildIndexs[_guildId].guildIndex
end

---@see 联盟解散删除联盟索引信息
function accept.deleteGuildIndex( _guildId )
    if guildIndexs[_guildId] then
        guildIndexs[_guildId] = nil
    end
end

---@see 更新联盟公告标识
function accept.addGuildNoticeIndex( _guildId )
    initGuildIndex( _guildId )

    guildIndexs[_guildId].noticeIndex = guildIndexs[_guildId].noticeIndex + 1
end

---@see 获取联盟公告标识
function response.getGuildNoticeIndex( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId].noticeIndex
end

---@see 获取全局入盟申请修改标识
function response.getApplyGlobalIndex( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId].applyGlobalIndex
end

---@see 获取入盟申请修改标识
function response.getApplyIndex( _guildId, _applyRid )
    initGuildIndex( _guildId )

    local guildInfo = guildIndexs[_guildId]
    if not guildInfo then return end

    return guildInfo.applys[_applyRid]
end

---@see 更新入盟申请修改标识
function accept.addApplyIndex( _guildId, _applyRid )
    initGuildIndex( _guildId )

    guildIndexs[_guildId].applyGlobalIndex = guildIndexs[_guildId].applyGlobalIndex + 1
    guildIndexs[_guildId].applys[_applyRid] = guildIndexs[_guildId].applyGlobalIndex
end

---@see 删除入盟申请修改标识
function accept.deleteApplyIndex( _guildId, _applyRid )
    if guildIndexs[_guildId] and guildIndexs[_guildId].applys[_applyRid] then
        guildIndexs[_guildId].applys[_applyRid] = nil
    end
end

---@see 获取全局成员修改标识
function response.getMemberGlobalIndex( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId].memberGlobalIndex
end

---@see 更新联盟成员修改标识
function accept.addMemberIndex( _guildId, _memberRid, _index )
    initGuildIndex( _guildId )

    if _index then
        guildIndexs[_guildId].members[_memberRid] = _index
    else
        guildIndexs[_guildId].memberGlobalIndex = guildIndexs[_guildId].memberGlobalIndex + 1
        guildIndexs[_guildId].members[_memberRid] = guildIndexs[_guildId].memberGlobalIndex
    end
end

---@see 成员退出联盟删除联盟成员索引信息
function accept.deleteMemberIndex( _guildId, _memberRid )
    if guildIndexs[_guildId] and guildIndexs[_guildId].members[_memberRid] then
        guildIndexs[_guildId].members[_memberRid] = nil
    end
end

---@see 获取所有联盟成员修改标识
function response.getMemberIndexs( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId] and guildIndexs[_guildId].members
end

---@see 获取联盟修改标识
function response.getGuildDepotRecordIndex( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId].depotRecordIndex
end

---@see 更新联盟修改标识
function accept.addGuildDepotRecordIndex( _guildId )
    initGuildIndex( _guildId )

    guildIndexs[_guildId].depotRecordIndex = guildIndexs[_guildId].depotRecordIndex + 1
end

---@see 获取全局求助修改标识
function response.getRequestHelpGlobalIndex( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId].requestHelpGlobalIndex
end

---@see 获取求助标识
function response.getRequestHelpIndexs( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId] and guildIndexs[_guildId].requestHelps
end

---@see 获取求助标识
function response.getRequestHelpIndex( _guildId, _index )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId] and guildIndexs[_guildId].requestHelps and guildIndexs[_guildId].requestHelps[_index]
end

---@see 删除求助索引
function accept.delRequestHelpIndex( _guildId, _helpIndex )
    initGuildIndex( _guildId )

    guildIndexs[_guildId].requestHelps[_helpIndex] = nil
end

---@see 更新求助索引
function accept.addRequestHelpIndex( _guildId, _helpIndex )
    initGuildIndex( _guildId )

    guildIndexs[_guildId].requestHelpGlobalIndex = guildIndexs[_guildId].requestHelpGlobalIndex + 1
    guildIndexs[_guildId].requestHelps[_helpIndex] = guildIndexs[_guildId].requestHelpGlobalIndex
end

---@see 帮助更新求助标识
function accept.updateRequestHelpIndexs( _guildId, _indexs )
    initGuildIndex( _guildId )

    guildIndexs[_guildId].requestHelpGlobalIndex = guildIndexs[_guildId].requestHelpGlobalIndex + 1
    for _, index in pairs( _indexs ) do
        guildIndexs[_guildId].requestHelps[index] = guildIndexs[_guildId].requestHelpGlobalIndex
    end
end

---@see 更新联盟欢迎邮件标识
function response.addWelcomeEmailIndex( _guildId )
    initGuildIndex( _guildId )

    guildIndexs[_guildId].welcomeEmailIndex = guildIndexs[_guildId].welcomeEmailIndex + 1

    return guildIndexs[_guildId].welcomeEmailIndex
end

---@see 更新联盟欢迎邮件标识
function response.getWelcomeEmailIndex( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId].welcomeEmailIndex
end

---@see 更新联盟建筑标识
function accept.addBuildIndex( _guildId, _buildIndex )
    initGuildIndex( _guildId )

    guildIndexs[_guildId].buildGlobalIndex = guildIndexs[_guildId].buildGlobalIndex + 1
    guildIndexs[_guildId].builds[_buildIndex] = guildIndexs[_guildId].buildGlobalIndex
end

---@see 删除联盟建筑标识
function accept.delBuildIndex( _guildId, _buildIndex )
    initGuildIndex( _guildId )

    local index = guildIndexs[_guildId].builds[_buildIndex]
    guildIndexs[_guildId].buildGlobalIndex = guildIndexs[_guildId].buildGlobalIndex + 1

    guildIndexs[_guildId].builds[_buildIndex] = nil

    return index or 0
end

---@see 获取全局联盟建筑标识
function response.getBuildGlobalIndex( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId].buildGlobalIndex
end

---@see 获取所有的联盟建筑标识
function response.getBuildIndexs( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId].builds
end

---@see 更新联盟资源点标识
function accept.addResourcePointIndex( _guildId )
    initGuildIndex( _guildId )

    guildIndexs[_guildId].resourcePointIndex = guildIndexs[_guildId].resourcePointIndex + 1
end

---@see 获取联盟资源点标识
function response.getResourcePointIndex( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId].resourcePointIndex
end

---@see 更新联盟圣地标识
function accept.addHolyLandIndex( _guildId, _holyLandId )
    initGuildIndex( _guildId )

    guildIndexs[_guildId].holyLandGlobalIndex = guildIndexs[_guildId].holyLandGlobalIndex + 1
    guildIndexs[_guildId].holyLands[_holyLandId] = guildIndexs[_guildId].holyLandGlobalIndex
end

---@see 删除联盟圣地标识
function response.delHolyLandIndex( _guildId, _holyLandId )
    initGuildIndex( _guildId )

    local holyLandIndex = guildIndexs[_guildId].holyLands[_holyLandId]
    guildIndexs[_guildId].holyLands[_holyLandId] = nil

    return holyLandIndex
end

---@see 获取全局联盟圣地标识
function response.getHolyLandGlobalIndex( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId].holyLandGlobalIndex
end

---@see 获取所有的联盟圣地标识
function response.getHolyLandIndexs( _guildId )
    initGuildIndex( _guildId )

    return guildIndexs[_guildId].holyLands
end