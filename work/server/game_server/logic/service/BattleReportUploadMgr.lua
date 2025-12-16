--[[
 * @file : BattleReportUploadMgr.lua
 * @type : multi snax service
 * @author : linfeng
 * @created : 2020-08-05 16:16:27
 * @Last Modified time: 2020-08-05 16:16:27
 * @department : Arabic Studio
 * @brief : 邮件上传服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local EmailLogic = require "EmailLogic"

function init()

end

function response.Init()

end

---@see 上传邮件简要信息
function accept.uploadEmail( _rid, _emailIndex, _battleReportEx )
    -- 推送到push服务器上传
    local gameId = RoleLogic:getRole( _rid, Enum.Role.gameId )
    local fileUrl = Common.rpcMultiCall( Common.getPushNode(), "FileUploadMgr", "uploadFileToRemote", _rid, gameId, _battleReportEx )
    if fileUrl then
        -- 更新到邮件中
        EmailLogic:setEmail( _rid, _emailIndex, { battleReportEx = fileUrl, reportStatus = 1 } )
        -- 推送给客户端
        EmailLogic:syncEmail( _rid, _emailIndex, { battleReportEx = fileUrl, reportStatus = 1 }, true )
    else
        -- 上传失败
        LOG_ERROR("rid(%d) uploadEmail, deleteEmail, save to battleReportExContent", _rid)
        -- 更新到邮件中
        EmailLogic:setEmail( _rid, _emailIndex, { battleReportExContent = _battleReportEx, reportStatus = 2 } )
        -- 推送给客户端
        EmailLogic:syncEmail( _rid, _emailIndex, { battleReportExContent = _battleReportEx, reportStatus = 2 }, true )
    end
end

---@see 上传邮件文件战报信息
function accept.uploadEmailDetail()
    -- body
end

---@see 删除邮件简要信息
function accept.deleteEmail( _rid, _url )
    local gameId = RoleLogic:getRole( _rid, Enum.Role.gameId )
    Common.rpcMultiSend( Common.getPushNode(), "FileUploadMgr", "DeleteFile", gameId, _url )
end