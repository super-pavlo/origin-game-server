--[[
* @file : RoleTimer.lua
* @type : snax multi service
* @author : linfeng
* @created : Tue May 29 2018 14:48:38 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : 角色相关定时器逻辑
* Copyright(C) 2017 IGG, All rights reserved
]]

local Timer = require "Timer"
local RoleLogic = require "RoleLogic"
local EntityLoad = require "EntityLoad"
local RoleTimerLogic = require "RoleTimerLogic"
local BuildingLogic = require "BuildingLogic"
local ArmyTrainLogic = require "ArmyTrainLogic"
local TechnologyLogic = require "TechnologyLogic"
local HospitalLogic = require "HospitalLogic"
local math = require "math"
local RoleSync = require "RoleSync"
local RechargeLogic = require "RechargeLogic"
local ExpeditionLogic = require "ExpeditionLogic"

local SaveRoleInterval = 600    -- 保存role数据间隔(600秒)

local actionForceTimers = {}  -- { [rid] = timerId }
local buildTimer = {} -- { [rid][timerId] }
local trainTimer = {} -- { [rid][timerId] }
local technology = {} -- { [rid] = timerId }
local treatment = {} -- { [rid] = timerId }
local produce = {} -- { [rid] = timerId }

local goldFreeTimer = {}
local wallBurnTimer = {}
local buffTimer = {} -- { [rid][buffId] = timerId }
local mysteryStore = {}
local guardTowerHpTimer = {}

local limitPackageTimer = {} -- {[rid][index] = timerId}
local expeditionTimer = {}

local roleRunTimerId = {}
---@type table<int, table<int, table<int, defaultRoleTimerClass>>>
local roleTimers = {}
---@type table<int, int>
local roleTimerSorts = {}

---@see 恢复行动力
local function recoverActionForce( _rid )
    actionForceTimers[_rid] = nil
    local actionForceLimit = RoleLogic:getActionForceLimit( _rid )
    if not RoleLogic:checkActionForce( _rid, actionForceLimit ) then
        -- 行动力不到上限, 增加行动力
        local actionForce = RoleLogic:addActionForce( _rid, 1, nil, Enum.LogType.RECOVER_GAIN_ACTION )
        -- 行动力恢复是否已满
        if actionForce < actionForceLimit then
            MSM.RoleTimer[_rid].req.addActionForceTimer( _rid )
        end
    end
end

---@see 角色登陆.注册相关定时器
function response.OnRoleLoginTimer( _rid, _lastLoginTime )
    LOG_INFO("rid(%d) OnRoleLoginTimer reg", _rid)
    -- 获取上次跨天时间
    local lastCrossDayTime = RoleLogic:getRole( _rid, Enum.Role.lastCrossDayTime )
    if Timer.isDiffDay( lastCrossDayTime ) then
        -- 补偿执行跨天
        RoleTimerLogic:crossDay( _rid, true, _lastLoginTime )
    end
    -- 创建每秒主定时器
    RoleTimerLogic:createRoleTimerTick( roleTimerSorts, roleTimers, roleRunTimerId, _rid )
    -- 创建保存数据定时器
    RoleTimerLogic:runEvery( roleTimerSorts, roleTimers, _rid, SaveRoleInterval, true, EntityLoad.saveRole, _rid )

    local systemDayTime = CFG.s_Config:Get("systemDayTime")
    -- 跨天定时器
    RoleTimerLogic:addCrossDayTimer( roleTimerSorts, roleTimers, _rid, Timer.GetNextDayX( systemDayTime or 0, true ), RoleTimerLogic.crossDay, RoleTimerLogic, _rid )
    -- 警戒塔定时器
    guardTowerHpTimer[_rid] = RoleTimerLogic:runEvery( roleTimerSorts, roleTimers, _rid, 60, true, BuildingLogic.addGuardTowerHpOnTimer, BuildingLogic, _rid )
end

---@see 角色登出.移除相关定时器
function response.OnRoleLogoutTimer( _rid )
    LOG_INFO("rid(%d) OnRoleLogoutTimer unreg", _rid)
    -- 角色登出移除定时器
    RoleTimerLogic:deleteTimerOnRoleLogout( roleTimerSorts, roleTimers, roleRunTimerId, _rid )
    -- 移除恢复行动力定时器
    if actionForceTimers[_rid] then
        actionForceTimers[_rid] = nil
    end

    -- 移除警戒塔血量定时器
    if guardTowerHpTimer[_rid] then
        guardTowerHpTimer[_rid] = nil
    end

    -- 移除限时礼包
    if limitPackageTimer[_rid] then
        limitPackageTimer[_rid] = nil
    end

    -- 移除材料生产
    if produce[_rid] then
        produce[_rid] = nil
    end

    -- 移除金箱子
    if goldFreeTimer[_rid] then
        goldFreeTimer[_rid] = nil
    end

    -- 移除训练
    if trainTimer[_rid] then
        trainTimer[_rid] = nil
    end

    -- 移除训练
    if technology[_rid] then
        technology[_rid] = nil
    end

    -- 移除训练
    if treatment[_rid] then
        treatment[_rid] = nil
    end
end

---@see 恢复行动力恢复定时器
function response.addActionForceTimer( _rid, _interval )
    if not actionForceTimers[_rid] then
        if not _interval then
            local nowTime = os.time()
            RoleLogic:setRole( _rid, { [Enum.Role.lastActionForceTime] = nowTime } )
            -- 通知客户端
            RoleSync:syncSelf( _rid, { [Enum.Role.lastActionForceTime] = nowTime }, true )
            -- 获取恢复一点行动力需要时间
            _interval = RoleLogic:getActionForceRecoveryTime( _rid )
        end
        actionForceTimers[_rid] = RoleTimerLogic:runAfter( roleTimerSorts, roleTimers, _rid, _interval, true, recoverActionForce, _rid )
    end
end

---@see 移除行动力恢复定时器
function response.deleteActionForceTimer( _rid )
    if actionForceTimers[_rid] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, actionForceTimers[_rid] )
        actionForceTimers[_rid] = nil
    end
end

---@see 建筑队列定时器
function response.addBuildTimer( _rid, _interval, _buildingIndex, _queueIndex )
    if not buildTimer[_rid] then
        buildTimer[_rid] = {}
    end

    local timerId = RoleTimerLogic:runAt( roleTimerSorts, roleTimers, _rid, _interval, false, BuildingLogic.upGradeBuildCallBack, BuildingLogic, _rid, _buildingIndex, _queueIndex )
    buildTimer[_rid][timerId] = timerId
    return timerId
end

---@see 移除建筑定时器
function response.deleteBuildTimer( _rid, _timerId )
    if buildTimer[_rid] and buildTimer[_rid][_timerId] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, _timerId )
        buildTimer[_rid][_timerId] = nil
        if table.empty( buildTimer[_rid] ) then
            buildTimer[_rid] = nil
        end
    end
end

---@see 检测建筑定时器是否存在
function response.checkBuildTimer( _rid, _timerId )
    if not buildTimer[_rid] then
        return false
    end
    return buildTimer[_rid][_timerId]
end

---@see 训练队列定时器
function response.addTrainTimer( _rid, _interval, _type, _queueIndex )
    if not trainTimer[_rid] then
        trainTimer[_rid] = {}
    end
    local timerId = RoleTimerLogic:runAt( roleTimerSorts, roleTimers, _rid, _interval, true, ArmyTrainLogic.trainArmyCallBack, ArmyTrainLogic, _rid, _type, _queueIndex )
    trainTimer[_rid][timerId] = timerId
    return timerId
end

---@see 移除训练定时器
function response.deleteTrainTimer( _rid, _timerId )
    if trainTimer[_rid] and trainTimer[_rid][_timerId] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, _timerId )
        trainTimer[_rid][_timerId] = nil
        if table.empty( trainTimer[_rid] ) then
            trainTimer[_rid] = nil
        end
    end
end

---@see 检测训练定时器是否存在
function response.checkTrainTimer( _rid, _timerId )
    if not trainTimer[_rid] then
        return false
    end
    return trainTimer[_rid][_timerId]
end

---@see 科技队列定时器
function response.addTechnologyTimer( _rid, _interval )
    local timerId = 0
    if not technology[_rid] then
        timerId = RoleTimerLogic:runAt( roleTimerSorts, roleTimers, _rid, _interval, true, TechnologyLogic.researchCallBack, TechnologyLogic, _rid )
        technology[_rid] = timerId
    end
    return timerId
end

---@see 移除科技定时器
function response.deleteTechnologyTimer( _rid )
    if technology[_rid] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, technology[_rid] )
        technology[_rid] = nil
    end
end

---@see 检测科技定时器是否存在
function response.checkTechnologyTimer( _rid )
    return technology[_rid]
end

---@see 治疗队列定时器
function response.addTreatmentTimer( _rid, _interval )
    local timerId = 0
    if not treatment[_rid] then
        timerId = RoleTimerLogic:runAt( roleTimerSorts, roleTimers, _rid, _interval, true, HospitalLogic.treatmentCallBack, HospitalLogic, _rid )
        treatment[_rid] = timerId
    end
    return timerId
end

---@see 移除治疗定时器
function response.deleteTreatmentTimer( _rid )
    if treatment[_rid] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, treatment[_rid] )
        treatment[_rid] = nil
    end
end

---@see 检测治疗定时器是否存在
function response.checkTreatmentTimer( _rid )
    return treatment[_rid]
end

---@see 增加一个酒馆金箱子定时器
function response.addGoldFreeTimer( _rid, _interval )
    if goldFreeTimer[_rid] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, goldFreeTimer[_rid] )
    end
    goldFreeTimer[_rid] = RoleTimerLogic:runAt( roleTimerSorts, roleTimers, _rid, _interval, true, BuildingLogic.addGoldFreeCount, BuildingLogic, _rid, 1 )
end

---@see 判断酒馆金箱子次数定时器
function response.getGoldFreeTimer( _rid )
    return goldFreeTimer[_rid]
end


---@see 删除一个酒馆金箱子次数定时器
function response.delCommonFreeTimer( _rid )
    if goldFreeTimer[_rid] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, goldFreeTimer[_rid] )
        goldFreeTimer[_rid] = nil
    end
end

---@see 增加一个城墙燃烧定时器
function response.addWallBurnTimer( _rid, _interval )
    if wallBurnTimer[_rid] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, wallBurnTimer[_rid] )
    end
    wallBurnTimer[_rid] = RoleTimerLogic:runAt( roleTimerSorts, roleTimers, _rid, _interval, false, BuildingLogic.cancelWallHp, BuildingLogic, _rid, false )
end

---@see 判断城墙燃烧定时器
function response.getWallBurnTimer( _rid )
    return wallBurnTimer[_rid]
end


---@see 删除一个城墙燃烧定时器
function response.delWallBurnTimer( _rid )
    if wallBurnTimer[_rid] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, wallBurnTimer[_rid] )
        wallBurnTimer[_rid] = nil
    end
end

---@see 增加城市buff定时器
function response.addCityBuffTimer( _rid, _buffId, _interval )
    if not buffTimer[_rid] then
        buffTimer[_rid] = {}
    end
    if buffTimer[_rid][_buffId] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, buffTimer[_rid][_buffId] )
        buffTimer[_rid][_buffId] = nil
    end
    local timerId = RoleTimerLogic:runAt( roleTimerSorts, roleTimers, _rid, _interval, false, RoleLogic.removeCityBuff, RoleLogic, _rid, _buffId )
    buffTimer[_rid][_buffId] = timerId
    return timerId
end

---@see 删除城市buff定时器
function response.deleteCityBuffTimer( _rid, _buffId )
    if buffTimer[_rid] and buffTimer[_rid][_buffId] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, buffTimer[_rid][_buffId] )
        buffTimer[_rid][_buffId] = nil
    end
end

---@see 检查城市buff定时器
function response.checkCityBuffTimer( _rid, _buffId )
    if not buffTimer[_rid] then
        return false
    end
    return buffTimer[_rid][_buffId]
end

---@see 增加神秘商人定时器
function response.addMysteryStoreTimer( _rid,  _interval, _leave )
    if mysteryStore[_rid] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, mysteryStore[_rid] )
    end
    if _leave then
        mysteryStore[_rid] = RoleTimerLogic:runAt( roleTimerSorts, roleTimers, _rid, _interval, false, RoleLogic.postLeave, RoleLogic, _rid )
    else
        mysteryStore[_rid] = RoleTimerLogic:runAt( roleTimerSorts, roleTimers, _rid, _interval, false, RoleLogic.refreshPost, RoleLogic, _rid )
    end
end

---@see 删除神秘商人定时器
function response.deleteMysteryStoreTimer( _rid )
    if mysteryStore[_rid] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, mysteryStore[_rid] )
        mysteryStore[_rid] = nil
    end
end

---@see 检查神秘商人定时器
function response.checkMysteryStoreTimer( _rid )
    return mysteryStore[_rid]
end

---@see 增加限时礼包定时器
function response.addLimitPackageTimer( _rid, _index, _interval )
    if not limitPackageTimer[_rid] then
        limitPackageTimer[_rid] = {}
    end
    local timerId = RoleTimerLogic:runAt( roleTimerSorts, roleTimers, _rid, _interval, false, RechargeLogic.checkLimitPackage, RechargeLogic, _rid, _index )
    limitPackageTimer[_rid][_index] = timerId
    return timerId
end

---@see 删除限时礼包定时器
function response.deleteLimitPackageTimer( _rid, _index )
    if limitPackageTimer[_rid] and limitPackageTimer[_rid][_index] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, limitPackageTimer[_rid][_index] )
        limitPackageTimer[_rid][_index] = nil
    end
end

---@see 检查限时礼包定时器
function response.checkLimitPackageTimer( _rid, _index )
    if not limitPackageTimer[_rid] then
        return false
    end
    return limitPackageTimer[_rid][_index]
end

---@see 材料生产队列定时器
function response.addProduceTimer( _rid, _interval, _isLogin )
    local timerId
    if produce[_rid] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, produce[_rid] )
    end
    timerId = RoleTimerLogic:runAt( roleTimerSorts, roleTimers, _rid, _interval, true, BuildingLogic.produceMaterialCallBack, BuildingLogic, _rid, _isLogin )
    produce[_rid] = timerId
    return timerId
end

---@see 移除材料生产定时器
function response.deleteProduceTimer( _rid )
    if produce[_rid] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, produce[_rid] )
        produce[_rid] = nil
    end
end

---@see 检测材料生产定时器是否存在
function response.checkProduceTimer( _rid )
    return produce[_rid]
end

---@see 材料生产队列定时器
function response.addExpeditionTimer( _rid, _interval )
    local timerId = 0
    if not expeditionTimer[_rid] then
        timerId = RoleTimerLogic:runAt( roleTimerSorts, roleTimers, _rid, _interval, true, ExpeditionLogic.exitExpedition, ExpeditionLogic, _rid, true )
        expeditionTimer[_rid] = timerId
    end
    return timerId
end

---@see 移除材料生产定时器
function response.deleteExpeditionTimer( _rid )
    if expeditionTimer[_rid] then
        RoleTimerLogic:deleteTimer( roleTimerSorts, roleTimers, roleRunTimerId, _rid, expeditionTimer[_rid] )
        expeditionTimer[_rid] = nil
    end
end

---@see 检测材料生产定时器是否存在
function response.checkExpeditionTimer( _rid )
    return expeditionTimer[_rid]
end
