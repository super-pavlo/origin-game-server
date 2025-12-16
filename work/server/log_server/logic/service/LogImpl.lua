--[[
 * @file : LogImpl.lua
 * @type : multi snax service
 * @author : linfeng
 * @created : 2019-04-01 10:38:24
 * @Last Modified time: 2019-04-01 10:38:24
 * @department : Arabic Studio
 * @brief : 日志写入实现服务
 * Copyright(C) 2019 IGG, All rights reserved
]]

---@see 角色登陆日志
function accept.roleLogin( _rid, _values )
    Common.loginMysqlExecute(string.format("call sp_add_game_login_log('%s','%s','%s','%s','',now())",
                                            _values.gameId, _values.serverId, _values.iggid, _values.ip))
end

---@see 角色登出日志
function accept.roleLogout( _rid, _values )
    Common.loginMysqlExecute(string.format("call sp_add_game_logout_log('%s','%s','%s','%s','',now(),%d)",
                                            _values.gameId, _values.serverId, _values.iggid, _values.ip, _values.onlineSeconds))
end