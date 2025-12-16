--[[
* @file : RoleTimerLogic.lua
* @type : lualib
* @author : dingyuchao
* @created : Tue Feb 18 2020 16:26:51 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色跨天相关逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local TaskLogic = require "TaskLogic"
local BuildingLogic = require "BuildingLogic"
local ActivityLogic = require "ActivityLogic"
local RechargeLogic = require "RechargeLogic"
local Timer = require "Timer"
local ExpeditionLogic = require "ExpeditionLogic"
local RoleDef = require "RoleDef"
local GuildLogic = require "GuildLogic"

local RoleTimerLogic = {}

---@see 生成角色定时器索引
function RoleTimerLogic:getTimerIndex( _rid )
    return Common.redisExecute({"incr", "timerIndex"})
end

---@see 创建角色每秒定时器
function RoleTimerLogic:createRoleTimerTick( _roleTimerSorts, _roleTimers, _roleRunTimerId, _rid )
    if not _roleRunTimerId[_rid] then
        _roleRunTimerId[_rid] = Timer.runEvery( 100, self.run, self, _roleTimerSorts, _roleTimers, _roleRunTimerId, _rid )
    end
end

---@see 删除角色每秒定时器
function RoleTimerLogic:deleteRoleTimerTick( _roleRunTimerId, _rid )
    if _roleRunTimerId[_rid] then
        Timer.delete( _roleRunTimerId[_rid] )
        _roleRunTimerId[_rid] = nil
    end
end

---@see 执行角色定时器
---@param _rid integer
function RoleTimerLogic:run( _roleTimerSorts, _roleTimers, _roleRunTimerId, _rid )
    local ret, err
    if _roleTimers[_rid] and _roleTimerSorts[_rid] then
        local now = os.time()
        local addTimers = {}
        local deleteTimers = {}
        for _, timeStamp in pairs(_roleTimerSorts[_rid]) do
            repeat
                if timeStamp > now then
                    break
                end

                if not _roleTimers[_rid][timeStamp] then
                    break
                end

                for _, roleTimeInfo in pairs(_roleTimers[_rid][timeStamp]) do
                    ret, err = xpcall( roleTimeInfo.func, debug.traceback, table.unpack( roleTimeInfo.args ) )
                    if not ret then
                        LOG_ERROR("timer run func err:%s", err)
                    end
                    -- 如果是循环执行,再次加入
                    if roleTimeInfo.interval > 0 then
                        if not addTimers[roleTimeInfo.interval] then
                            addTimers[roleTimeInfo.interval] = {}
                        end
                        table.insert( addTimers[roleTimeInfo.interval], roleTimeInfo )
                    end
                end

                if _roleTimers[_rid] then
                    _roleTimers[_rid][timeStamp] = nil
                end

                if _roleTimerSorts[_rid] then
                    table.insert( deleteTimers, timeStamp )
                end
            until true
        end

        -- 移除过期或者执行过的定时器
        for _, removeTimeStamp in pairs(deleteTimers) do
            table.removevalue( _roleTimerSorts[_rid], removeTimeStamp )
        end

        for interval, roleTimeInfos in pairs(addTimers) do
            for _, roleTimeInfo in pairs(roleTimeInfos) do
                -- 重新加入
                self:addTimer( _roleTimerSorts, _roleTimers, _rid, interval, roleTimeInfo.interval, roleTimeInfo.isLogoutDelete, roleTimeInfo.func, table.unpack( roleTimeInfo.args ) )
            end
        end

        if table.empty( addTimers) and table.empty( _roleTimers[_rid] ) then
            _roleTimers[_rid] = nil
            _roleTimerSorts[_rid] = nil
            self:deleteRoleTimerTick( _roleRunTimerId, _rid )
        end
    end
end

---@see 增加角色定时器
function RoleTimerLogic:addTimer( _roleTimerSorts, _roleTimers, _rid, _afterInterval, _interval, _isLogoutDelete, _func, ...  )
    local timerIndex = self:getTimerIndex( _rid )
    if not _roleTimers[_rid] then
        _roleTimers[_rid] = {}
    end

    local timeStamp = os.time() + _afterInterval
    if not _roleTimers[_rid][timeStamp] then
        _roleTimers[_rid][timeStamp] = {}
    end

    assert( _roleTimers[_rid][timeStamp][timerIndex] == nil )

    local defaultRoleTimerInfo = RoleDef:getDefaultRoleTimerInfo()
    defaultRoleTimerInfo.interval = _interval or 0
    assert( type(_func) == "function" )
    defaultRoleTimerInfo.func = _func
    defaultRoleTimerInfo.args = { ... }
    if _isLogoutDelete == nil then
        -- 不传默认离线删除
        _isLogoutDelete = true
    end
    defaultRoleTimerInfo.isLogoutDelete = _isLogoutDelete

    _roleTimers[_rid][timeStamp][timerIndex] = defaultRoleTimerInfo
    -- 重新排序
    _roleTimerSorts[_rid] = table.indexs( _roleTimers[_rid] )
    table.sort( _roleTimerSorts[_rid], function ( a, b )
        return a < b
    end)

    return timerIndex
end

---@see 增加跨天定时器
function RoleTimerLogic:addCrossDayTimer( _roleTimerSorts, _roleTimers, _rid, _nextTimeStamp, _func, ... )
    return self:addTimer( _roleTimerSorts, _roleTimers, _rid, _nextTimeStamp - os.time(), 3600 * 24, true, _func, ... )
end

---@see 增加一次定时器
function RoleTimerLogic:runAt( _roleTimerSorts, _roleTimers, _rid, _nextTimeStamp, _isLogoutDelete, _func, ... )
    return self:addTimer( _roleTimerSorts, _roleTimers, _rid, _nextTimeStamp - os.time(), 0, _isLogoutDelete, _func, ... )
end

---@see 增加若干时间一次定时器
function RoleTimerLogic:runAfter( _roleTimerSorts, _roleTimers, _rid, _interval, _isLogoutDelete, _func, ... )
    return self:addTimer( _roleTimerSorts, _roleTimers, _rid, _interval, 0, _isLogoutDelete, _func, ... )
end

---@see 增加循环定时器
function RoleTimerLogic:runEvery( _roleTimerSorts, _roleTimers, _rid, _interval, _isLogoutDelete, _func, ... )
    return self:addTimer( _roleTimerSorts, _roleTimers, _rid, _interval, _interval, _isLogoutDelete, _func, ... )
end

---@see 删除角色定时器
function RoleTimerLogic:deleteTimer( _roleTimerSorts, _roleTimers, _roleRunTimerId, _rid, _timerIndex )
    if _roleTimers[_rid] then
        for timeStamp, roleTimerInfos in pairs(_roleTimers[_rid]) do
            for timerIndex in pairs(roleTimerInfos) do
                if timerIndex == _timerIndex then
                    roleTimerInfos[timerIndex] = nil
                end
            end

            if table.empty( roleTimerInfos) then
                _roleTimers[_rid][timeStamp] = nil
            end
        end

        if table.empty( _roleTimers[_rid] ) then
            _roleTimers[_rid] = nil
            _roleTimerSorts[_rid] = nil
            self:deleteRoleTimerTick( _roleRunTimerId, _rid )
        end
    end
end

---@see 角色登出移除所有定时器
function RoleTimerLogic:deleteTimerOnRoleLogout( _roleTimerSorts, _roleTimers, _roleRunTimerId, _rid )
    if _roleTimers[_rid] then
        for timeStamp, roleTimerInfos in pairs(_roleTimers[_rid]) do
            for timerIndex, roleTimerInfo in pairs(roleTimerInfos) do
                if roleTimerInfo.isLogoutDelete then
                    roleTimerInfos[timerIndex] = nil
                end
            end

            if table.empty( roleTimerInfos) then
                _roleTimers[_rid][timeStamp] = nil
            end
        end

        if table.empty( _roleTimers[_rid] ) then
            _roleTimers[_rid] = nil
            _roleTimerSorts[_rid] = nil
            self:deleteRoleTimerTick( _roleRunTimerId, _rid )
        end
    end
end

---@see 跨周
function RoleTimerLogic:crossWeek( _rid, _isLogin )
    local ret, err
    ret, err = xpcall( RechargeLogic.resetRecharge, debug.traceback, RechargeLogic, _rid, _isLogin, true )
    if not ret then
        LOG_ERROR("crossWeek resetRecharge err:%s", err)
    end
    ret, err = xpcall( RoleLogic.refreshVipShop, debug.traceback, RoleLogic, _rid, _isLogin, true )
    if not ret then
        LOG_ERROR("crossWeek refreshVipShop err:%s", err)
    end
end

---@see 跨月
function RoleTimerLogic:crossMonth( _rid, _isLogin )
    local ret, err = xpcall( RechargeLogic.resetRecharge, debug.traceback, RechargeLogic, _rid, _isLogin, nil, true )
    if not ret then
        LOG_ERROR("crossMonth resetRecharge err:%s", err)
    end
end

---@see 跨天
function RoleTimerLogic:crossDay( _rid, _isLogin, _lastLoginTime )
    local ret, err
    -- 每天都重新获取一次上次跨天时间
    local lastCrossDayTime = RoleLogic:getRole( _rid, Enum.Role.lastCrossDayTime )
    -- 重置每日角色相关信息
    ret, err = xpcall( RoleLogic.resetRoleAttrDaily, debug.traceback, RoleLogic, _rid, _isLogin )
    if not ret then
        LOG_ERROR("crossDay resetRoleAttrDaily err:%s", err)
    end
    -- 重置每日任务
    ret, err = xpcall( TaskLogic.resetTaskInfoDaily, debug.traceback, TaskLogic, _rid, _isLogin )
    if not ret then
        LOG_ERROR("crossDay resetTaskInfoDaily err:%s", err)
    end
    -- 重置白银宝箱免费次数
    ret, err = xpcall( BuildingLogic.resetSilver, debug.traceback, BuildingLogic, _rid, _isLogin )
    if not ret then
        LOG_ERROR("crossDay resetSilver err:%s", err)
    end
    -- 重置活动信息
    ret, err = xpcall( ActivityLogic.resetActivity, debug.traceback, ActivityLogic, _rid, _isLogin )
    if not ret then
        LOG_ERROR("crossDay resetActivity err:%s", err)
    end
    -- 刷新神秘商人
    ret, err = xpcall( RoleLogic.refreshPost, debug.traceback, RoleLogic, _rid, _isLogin )
    if not ret then
        LOG_ERROR("crossDay refreshPost err:%s", err)
    end
    -- 刷新vip相关
    ret, err = xpcall( RoleLogic.vipLogin, debug.traceback, RoleLogic, _rid, _lastLoginTime , _isLogin )
    if not ret then
        LOG_ERROR("crossDay vipLogin err:%s", err)
    end
    -- 活动开启处理
    ret, err = xpcall( ActivityLogic.checkActivityOpen, debug.traceback, ActivityLogic, _rid, _isLogin )
    if not ret then
        LOG_ERROR("crossDay resetActivitySchedule err:%s", err)
    end
    -- 活动进度处理
    ret, err = xpcall( ActivityLogic.resetActivitySchedule, debug.traceback, ActivityLogic, _rid, _isLogin )
    if not ret then
        LOG_ERROR("crossDay resetActivitySchedule err:%s", err)
    end
    -- 重置礼包购买记录
    ret, err = xpcall( RechargeLogic.resetRecharge, debug.traceback, RechargeLogic, _rid, _isLogin )
    if not ret then
        LOG_ERROR("crossDay resetRecharge err:%s", err)
    end
    -- 重置远征商店
    ret, err = xpcall( RoleLogic.resetExpeditionStore, debug.traceback, RoleLogic, _rid, _isLogin )
    if not ret then
        LOG_ERROR("crossDay resetExpeditionStore err:%s", err)
    end
    -- 重置远征信息
    ret, err = xpcall( ExpeditionLogic.resetExpedition, debug.traceback, ExpeditionLogic, _rid, _isLogin )
    if not ret then
        LOG_ERROR("crossDay resetExpedition err:%s", err)
    end

    -- 在线跨天检测
    if not _isLogin then
        -- 发送联盟不活跃成员邮件
        Timer.runAfter( 200, GuildLogic.sendInactiveMembersEmail, GuildLogic, _rid )
    end

    if Timer.isDiffWeek( lastCrossDayTime ) then
        self:crossWeek( _rid, _isLogin )
    end
    if Timer.isDiffMonth( lastCrossDayTime ) then
        self:crossMonth( _rid, _isLogin )
    end

    -- 更新跨天时间
    RoleLogic:setRole( _rid, Enum.Role.lastCrossDayTime, os.time() )
end


return RoleTimerLogic