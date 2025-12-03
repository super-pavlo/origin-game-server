--[[
 * @file : DenseFogLogic.lua
 * @type : lua lib
 * @author : linfeng
 * @created : 2020-05-15 13:12:22
 * @Last Modified time: 2020-05-15 13:12:22
 * @department : Arabic Studio
 * @brief : 迷雾逻辑模块
 * Copyright(C) 2019 IGG, All rights reserved
]]

local RoleLogic = require "RoleLogic"
local RoleSync = require "RoleSync"
local skynet = require "skynet"

local DenseFogLogic = {}

---@see 全开指定区域迷雾
function DenseFogLogic:openAllDenseFog( _rid, _objectIndex, _scoutsIndex, _allDesenFog, _pos )
    if _allDesenFog then
        MSM.DenseFogMgr[_objectIndex].req.openAreaDenseFog( _rid, _allDesenFog, _scoutsIndex )
    end
    -- 斥候回城
    local cityPos = RoleLogic:getRole( _rid, Enum.Role.pos )
    _pos.x = math.floor(_pos.x)
    _pos.y = math.floor(_pos.y)
    MSM.MapMarchMgr[_objectIndex].post.scoutsBackCity( _rid, _objectIndex, { _pos, cityPos } )
end

---@see 判断坐标范围内是否有未开启的迷雾
function DenseFogLogic:checkExistDenseFog( _rid, _pos )
    -- 获取斥候探索范围
    local scoutView = RoleLogic:getRole( _rid, Enum.Role.scoutView )
    -- 计算当前坐标所在迷雾区域块
    local allDesenFog = self:getAllDenseFog( _rid, scoutView, _pos ) or {}
    local exist = false
    for _, rule in pairs(allDesenFog) do
        if rule == 0 then
            exist = true
            break
        end
    end
    -- 返回
    return exist
end


---@see 根据坐标获取迷雾列表
function DenseFogLogic:getAllDenseFog( _rid, _scoutView, _pos, _returnPos, _denseFog )
    if not _scoutView then
        return
    end
    local desenFogSize = Enum.DesenFogSize
    local desenFogHarfSize = math.floor( Enum.DesenFogSize / 2 )
    local desenFogLineSize = math.floor( Enum.MapSize / Enum.DesenFogSize )
    local denseFogAreaSize = _scoutView * desenFogSize
    -- 计算左边边界起始
    local xIndex = math.floor( _pos.x / denseFogAreaSize )
    local denseFogAreaLeft = xIndex * denseFogAreaSize
    if denseFogAreaLeft < 0 then
        denseFogAreaLeft = 0
    end
    -- 计算下边边界起始
    local yIndex = math.floor( _pos.y / denseFogAreaSize )
    local denseFogAreaBottom = yIndex * denseFogAreaSize
    if denseFogAreaBottom < 0 then
        denseFogAreaBottom = 0
    end

    -- 获取范围内的迷雾
    local roleDenseFog = _denseFog or RoleLogic:getRole( _rid, Enum.Role.denseFog )
    local allDesenFog = {}
    local allDesenFogPos = {}
    local denseFogIndex
    for x = denseFogAreaLeft + desenFogHarfSize, denseFogAreaLeft + denseFogAreaSize, desenFogSize do
        for y = denseFogAreaBottom + desenFogHarfSize, denseFogAreaBottom + denseFogAreaSize, desenFogSize do
            -- 计算出迷雾块索引
            xIndex = math.ceil( x / desenFogSize )
            yIndex = math.floor( y / desenFogSize )
            denseFogIndex = xIndex + yIndex * desenFogLineSize
            if denseFogIndex >= 1 then
                -- 获取权限
                allDesenFog[denseFogIndex] = DenseFogLogic:getSmallFogRule( roleDenseFog, denseFogIndex )
                if _returnPos then
                    allDesenFogPos[denseFogIndex] = { x = x, y = y }
                end
            end
        end
    end
    return allDesenFog, allDesenFogPos
end

---@see 根据坐标计算所在迷雾的索引和位索引
function DenseFogLogic:getDenseFogIndexByPos( _pos )
    local desenFogSize = Enum.DesenFogSize
    local desenFogLineSize = math.floor( Enum.MapSize / Enum.DesenFogSize )
    local x = _pos.x
    local y = _pos.y
    local int, float = math.modf(_pos.x / desenFogSize)
    if float == 0 then
        if int < desenFogLineSize then
            -- 在边界线上,归属到右边
            x = x + 0.1
        end
    end
    local denseFogIndex = math.ceil( x / desenFogSize ) + math.floor( y / desenFogSize ) * desenFogLineSize
    return denseFogIndex, self:denseFogIndexToBitIndex( denseFogIndex )
end

---@see 判断坐标是否处于迷雾中
---@return true为处于迷雾中,false为不处于迷雾中
function DenseFogLogic:checkPosInDenseFog( _rid, _pos )
    local denseFogIndex = self:getDenseFogIndexByPos( _pos )
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.denseFog, Enum.Role.denseFogOpenFlag } )
    if roleInfo.denseFogOpenFlag then
        return false
    end

    return self:getSmallFogRule( roleInfo.denseFog, denseFogIndex ) == 0
end

---@see 迷雾索引转位索引
function DenseFogLogic:denseFogIndexToBitIndex( _denseFogIndex )
    local bitIndex = _denseFogIndex % 64 - 1
    if bitIndex < 0 then
        bitIndex = 63
    end
    return bitIndex
end

---@see 迷雾索引转存储索引
function DenseFogLogic:denseFogIndexToSaveIndex( _denseFogIndex )
    return math.ceil( _denseFogIndex / 64 )
end

---@see 获取小迷雾权限
function DenseFogLogic:getSmallFogRule( _roleDenseFogInfo, _denseFogIndex )
    local saveIndex = self:denseFogIndexToSaveIndex( _denseFogIndex )
    if saveIndex <= 0 then
        saveIndex = 1
    end
    local rule
    if _roleDenseFogInfo[saveIndex] then
        rule = _roleDenseFogInfo[saveIndex].rule
    else
        rule = 0
    end
    return rule & ( 1 << self:denseFogIndexToBitIndex( _denseFogIndex ) )
end

---@see 关闭指定坐标范围的迷雾
function DenseFogLogic:closeDenseFogInPos( _rid, _pos, _radius )
    local desenFogSize = Enum.DesenFogSize
    local desenFogLineSize = math.floor( Enum.MapSize / Enum.DesenFogSize )
    -- 计算坐标所在的迷雾索引
    local xIndex = math.ceil( _pos.x / desenFogSize )
    if xIndex <= 0 then
        xIndex = 1
    end
    local yIndex = math.floor( _pos.y / desenFogSize )
    if yIndex < 0 then
        yIndex = 0
    end
    local fogSize = math.ceil( _radius / desenFogSize )
    local leftDesenFogIndex = xIndex - fogSize
    local rightDesenFogIndex = xIndex + fogSize
    local bottomDesenFogIndex = yIndex - fogSize
    local topDesenFogIndex = yIndex + fogSize
    -- 判断边界是否越界
    -- 左右必须和中心处于同一行
    if leftDesenFogIndex < 1 then
        -- 修正为最左边
        leftDesenFogIndex = 1
    end
    if rightDesenFogIndex > desenFogLineSize then
        -- 修正为最右边
        rightDesenFogIndex = desenFogLineSize
    end
    -- 上下不能越出地图
    if bottomDesenFogIndex < 0 then
        bottomDesenFogIndex = 0
    end
    if topDesenFogIndex > desenFogLineSize-1 then
        topDesenFogIndex = desenFogLineSize-1
    end

    -- 计算实际小迷雾索引
    local allDenseFog = {}
    for y = bottomDesenFogIndex, topDesenFogIndex do
        for x = leftDesenFogIndex, rightDesenFogIndex do
            table.insert( allDenseFog, x + y * desenFogLineSize )
        end
    end

    -- 转换成角色迷雾数据
    local retDenseFog  = RoleLogic:getRole( _rid, Enum.Role.denseFog )
    local bitIndex, fogRule
    local closeDenseFogIndexs = {}
    for _, denseFogIndex in pairs(allDenseFog) do
        local saveIndex = self:denseFogIndexToSaveIndex( denseFogIndex )
        if retDenseFog[saveIndex] then
            fogRule = self:getSmallFogRule( retDenseFog, denseFogIndex )
            -- 之前处于开启状态
            if fogRule ~= 0 then
                bitIndex = self:denseFogIndexToBitIndex( denseFogIndex )
                retDenseFog[saveIndex].rule = retDenseFog[saveIndex].rule & (~( 1 << bitIndex ))
                -- 从开启变为未开启,需要通知客户端
                table.insert( closeDenseFogIndexs, denseFogIndex )
            end
        end
    end

    -- 保存数据
    RoleLogic:setRole( _rid, Enum.Role.denseFog, retDenseFog )

    -- 自己城市的不能被迷雾覆盖
    local rolePos = RoleLogic:getRole( _rid, Enum.Role.pos )
    local _, openFogIndexs = self:openDenseFogInPos( _rid, rolePos, 2 * Enum.DesenFogSize, true )
    for _, denseFogIndex in pairs(openFogIndexs) do
        table.removevalue( closeDenseFogIndexs, denseFogIndex )
    end

    -- 同步
    Common.syncMsg( _rid, "Map_DenseFogClose", { denseFogIndex = closeDenseFogIndexs } )
end

---@see 开启指定坐标范围内的迷雾
function DenseFogLogic:openDenseFogInPos( _rid, _pos, _radius, _noSync, _isCreate )
    local desenFogSize = Enum.DesenFogSize
    local desenFogLineSize = math.floor( Enum.MapSize / Enum.DesenFogSize )
    -- 计算坐标所在的迷雾索引
    local xIndex = math.ceil( _pos.x / desenFogSize )
    if xIndex <= 0 then
        xIndex = 1
    end
    local yIndex = math.floor( _pos.y / desenFogSize )
    if yIndex < 0 then
        yIndex = 0
    end
    local fogSize = math.ceil( _radius / desenFogSize )
    local leftDesenFogIndex = xIndex - fogSize
    local rightDesenFogIndex = xIndex + fogSize
    local bottomDesenFogIndex = yIndex - fogSize
    local topDesenFogIndex = yIndex + fogSize
    -- 判断边界是否越界
    -- 左右必须和中心处于同一行
    if leftDesenFogIndex < 1 then
        -- 修正为最左边
        leftDesenFogIndex = 1
    end
    if rightDesenFogIndex > desenFogLineSize then
        -- 修正为最右边
        rightDesenFogIndex = desenFogLineSize
    end
    -- 上下不能越出地图
    if bottomDesenFogIndex < 0 then
        bottomDesenFogIndex = 0
    end
    if topDesenFogIndex > desenFogLineSize-1 then
        topDesenFogIndex = desenFogLineSize-1
    end

    -- 计算实际小迷雾索引
    local allDenseFog = {}
    for y = bottomDesenFogIndex, topDesenFogIndex do
        for x = leftDesenFogIndex, rightDesenFogIndex do
            table.insert( allDenseFog, x + y * desenFogLineSize )
        end
    end

    -- 转换成角色迷雾数据
    local retDenseFog = {}
    if not _isCreate then
        -- 非创角
        retDenseFog = RoleLogic:getRole( _rid, Enum.Role.denseFog )
    end
    local bitIndex
    local openDenseFogIndexs = {}

    for _, denseFogIndex in pairs(allDenseFog) do
        local saveIndex = self:denseFogIndexToSaveIndex( denseFogIndex )
        if saveIndex >= 1 and saveIndex <= 2500 then
            if not retDenseFog[saveIndex] then
                retDenseFog[saveIndex] = { index = saveIndex, rule = 0 }
            end
            bitIndex = self:denseFogIndexToBitIndex( denseFogIndex )
            local syncClient = self:getSmallFogRule( retDenseFog, denseFogIndex ) == 0
            retDenseFog[saveIndex].rule = retDenseFog[saveIndex].rule | ( 1 << bitIndex )
            if syncClient then
                -- 从未开启变为开启,需要通知客户端
                table.insert( openDenseFogIndexs, denseFogIndex )
            end
        end
    end

    if not _noSync and not table.empty( openDenseFogIndexs ) then
        Common.syncMsg( _rid, "Map_DenseFogOpen", { denseFogIndex = openDenseFogIndexs } )
    end

    if not _isCreate and not table.empty( openDenseFogIndexs ) then
        -- 保存数据
        RoleLogic:setRole( _rid, Enum.Role.denseFog, retDenseFog )
    end

    return retDenseFog, openDenseFogIndexs
end

---@see 根据迷雾索引获取迷雾所在坐标
function DenseFogLogic:getPosByDenseFogIndex( _denseFogIndex )
    local desenFogSize = Enum.DesenFogSize
    local x = ( _denseFogIndex % 64 - 1 ) * desenFogSize + ( desenFogSize / 2 )
    local y = math.floor( _denseFogIndex / 64 ) * desenFogSize + ( desenFogSize / 2 )
    return { x = x, y = y }
end

---@see 开启指定位置的一块大迷雾
function DenseFogLogic:openNearDenseFog( _rid, _pos )
    -- 判断玩家迷雾是否全开了
    local roleInfo = RoleLogic:getRole( _rid, { Enum.Role.denseFogOpenFlag, Enum.Role.pos, Enum.Role.denseFog } )
    if roleInfo.denseFogOpenFlag then
        return false
    end

    if _pos then
        -- 开启迷雾
        local radius = CFG.s_UnitView:Get( Enum.MapUnitViewType.KINGDOM_MAP )
        if radius then
            radius = radius.viewRange * 2 * 100 / Enum.DesenFogSize
            local allDesenFog = self:getAllDenseFog( _rid, radius, _pos )
            -- 未开启的迷雾直接开启
            local openDenseFogIndexs = {}
            for denseFogIndex in pairs(allDesenFog) do
                if self:getSmallFogRule( roleInfo.denseFog, denseFogIndex ) == 0 then
                    -- 未开启
                    table.insert( openDenseFogIndexs, denseFogIndex )
                    local saveIndex = self:denseFogIndexToSaveIndex( denseFogIndex )
                    if saveIndex <= 2500 then
                        local bitIndex = self:denseFogIndexToBitIndex( denseFogIndex )
                        if not roleInfo.denseFog[saveIndex] then
                            roleInfo.denseFog[saveIndex] = { index = saveIndex, rule = 0 }
                        end
                        roleInfo.denseFog[saveIndex].rule = roleInfo.denseFog[saveIndex].rule | ( 1 << bitIndex )
                    end
                end
            end
            if not table.empty(openDenseFogIndexs) then
                Common.syncMsg( _rid, "Map_PreDenseFogOpen", { denseFogIndex = openDenseFogIndexs, pos = _pos } )
                RoleLogic:setRole( _rid, Enum.Role.denseFog, roleInfo.denseFog )
                -- 增加迷雾任务开启数量
                local TaskLogic = require "TaskLogic"
                TaskLogic:addTaskStatisticsSum( _rid, Enum.TaskType.FOG_EXPLORE, Enum.TaskArgDefault, #openDenseFogIndexs )
                local addNum
                if RoleLogic:getRole( _rid, Enum.Role.denseFogOpenFlag ) then
                    -- 迷雾全开, 不需要判断迷雾探索个数
                    addNum = 160000
                else
                    local taskStatistics = RoleLogic:getRole( _rid, Enum.Role.taskStatisticsSum )
                    addNum = TaskLogic:getStatisticsNum( taskStatistics, Enum.TaskType.FOG_EXPLORE )
                end
                MSM.ActivityRoleMgr[_rid].req.setActivitySchedule( _rid, Enum.ActivityActionType.SCOUT_MIST, addNum, nil, nil, true, nil )
            end
        end
    end

    return true
end

---@see 迷雾全开.纪念碑事件
function DenseFogLogic:onMonumentOpenAllDenseFog()
    local nowTime = os.time()
    local onlines = SM.OnlineMgr.req.getAllOnlineRid()
    for _, rid in pairs(onlines) do
        -- 先检查角色是否已经全部手动探索完
        self:checkDenseFogOnRoleLogin( rid )
        -- 没有探索完，更新纪念碑完成的迷雾全开信息
        if not RoleLogic:getRole( rid, Enum.Role.denseFogOpenFlag ) then
            RoleLogic:setRole( rid, { [Enum.Role.denseFog] = {}, [Enum.Role.denseFogOpenFlag] = true, [Enum.Role.denseFogOpenTime] = nowTime } )
            RoleSync:syncSelf( rid, { [Enum.Role.denseFog] = {}, [Enum.Role.denseFogOpenFlag] = true }, true )
        end
    end
    -- 更新所有地图斥候对象迷雾探索信息
    local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or Enum.DEFUALT_SNAX_SERVICE_NUM
    for i = 1, multiSnaxNum do
        MSM.MapMarchMgr[i].post.updateDenseFogOpenFlag()
    end
end

---@see 登陆时候判断迷雾是否要全开
function DenseFogLogic:onRoleLoginCheckOpenAllDenseFog( _rid )
    local MonumentLogic = require "MonumentLogic"
    if MonumentLogic:checkMonumentStatus( CFG.s_Config:Get("allDenseFogMileStone") )
        and ( RoleLogic:getRole( _rid, Enum.Role.denseFogOpenTime ) or 0 ) <= 0 then
        RoleLogic:setRole( _rid, { [Enum.Role.denseFog] = {}, [Enum.Role.denseFogOpenFlag] = true, [Enum.Role.denseFogOpenTime] = os.time() } )
    end
end

---@see 角色加入联盟开迷雾
function DenseFogLogic:onRoleJoinGuild( _guildId, _rid )
    local allPos = {}
    local joinRoleInfo = RoleLogic:getRole( _rid, { Enum.Role.pos, Enum.Role.denseFogOpenFlag } )
    if joinRoleInfo.denseFogOpenFlag then
        -- 迷雾已经全开了
        return
    end

    local GuildLogic = require "GuildLogic"
    -- 获取所有联盟成员的坐标
    local members = GuildLogic:getGuild( _guildId, Enum.Guild.members )
    local memberInfo = {}
    local roleInfo
    for rid in pairs(members) do
        roleInfo = RoleLogic:getRole( rid, { Enum.Role.online, Enum.Role.pos } )
        table.insert( allPos, roleInfo.pos )
        memberInfo[rid] = ( roleInfo.online or false )
    end

    -- 获取所有联盟建筑的坐标
    local guildBuilds = SM.c_guild_building.req.Get( _guildId ) or {}
    for _, guildBuild in pairs(guildBuilds) do
        table.insert( allPos, guildBuild.pos )
    end

    -- 获取所有联盟圣地的坐标
    local holyLandBuilds = MSM.GuildHolyLandMgr[_guildId].req.getGuildHolyLand( _guildId ) or {}
    for _, holyLandBuild in pairs(holyLandBuilds) do
        table.insert( allPos, holyLandBuild.pos )
    end

    local radius = CFG.s_UnitView:Get( Enum.MapUnitViewType.CITY )
    radius = radius.viewRange * 100
    -- 开启迷雾
    for _, pos in pairs(allPos) do
        self:openDenseFogInPos( _rid, pos, radius )
    end

    -- 通知联盟其他成员
    for rid, online in pairs(memberInfo) do
        if rid ~= _rid then
            self:openDenseFogInPos( rid, joinRoleInfo.pos, radius, not online )
        end
    end
end

---@see 角色退出联盟开迷雾
function DenseFogLogic:onRoleExitGuild( _guildId, _rid, _disban )
    local allPos = {}
    local exitRoleInfo
    if not _disban then
        exitRoleInfo = RoleLogic:getRole( _rid, { Enum.Role.pos, Enum.Role.denseFogOpenFlag } )
        if exitRoleInfo.denseFogOpenFlag then
            -- 迷雾已经全开了
            return
        end
    end

    local GuildLogic = require "GuildLogic"
    -- 获取所有联盟成员的坐标
    local members = GuildLogic:getGuild( _guildId, Enum.Guild.members )
    local memberInfo = {}
    local roleInfo
    for rid in pairs(members) do
        roleInfo = RoleLogic:getRole( rid, { Enum.Role.online, Enum.Role.pos } )
        table.insert( allPos, roleInfo.pos )
        memberInfo[rid] = roleInfo.online
    end

    -- 获取所有联盟建筑的坐标
    local guildBuilds = SM.c_guild_building.req.Get( _guildId ) or {}
    for _, guildBuild in pairs(guildBuilds) do
        table.insert( allPos, guildBuild.pos )
    end

    -- 获取所有联盟圣地的坐标
    local holyLandBuilds = MSM.GuildHolyLandMgr[_guildId].req.getGuildHolyLand( _guildId ) or {}
    local HolyLandLogic = require "HolyLandLogic"
    for _, holyLandBuild in pairs(holyLandBuilds) do
        -- 纪念碑事件结束时,圣地不能关闭
        if not HolyLandLogic:checkHolyLandMileStoneFinish( holyLandBuild.strongHoldId ) then
            table.insert( allPos, holyLandBuild.pos )
        end
    end

    local radius = CFG.s_UnitView:Get( Enum.MapUnitViewType.CITY )
    radius = radius.viewRange * 100

    if not _disban then
        -- 关闭迷雾
        for _, pos in pairs(allPos) do
            self:closeDenseFogInPos( _rid, pos, radius )
        end

        -- 通知联盟其他成员
        for rid, online in pairs(memberInfo) do
            if rid ~= _rid then
                local denseFogOpenFlag = RoleLogic:getRole( rid, Enum.Role.denseFogOpenFlag )
                -- 迷雾没有全开了
                if not denseFogOpenFlag then
                    self:closeDenseFogInPos( rid, exitRoleInfo.pos, radius, not online )
                end
            end
        end
    else
        for _, exitRid in pairs(_rid) do
            local denseFogOpenFlag = RoleLogic:getRole( exitRid, Enum.Role.denseFogOpenFlag )
            -- 迷雾没有全开了
            if not denseFogOpenFlag then
                -- 关闭迷雾
                for _, pos in pairs(allPos) do
                    self:closeDenseFogInPos( exitRid, pos, radius )
                end
            end
        end
    end
end

---@see 判断迷雾是否全开
function DenseFogLogic:checkRoleDenseFogAllOpen( _rid )
    return RoleLogic:getRole( _rid, Enum.Role.denseFogOpenFlag ) or false
end

---@see 角色登录判断迷雾是否已经全部探索完
function DenseFogLogic:checkDenseFogOnRoleLogin( _rid, _noSync )
    local denseFog = RoleLogic:getRole( _rid, Enum.Role.denseFog ) or {}

    for i = 1, 2500 do
        if not denseFog[i] or denseFog[i].rule ~= -1 then
            return
        end
    end

    RoleLogic:setRole( _rid, { [Enum.Role.denseFog] = {}, [Enum.Role.denseFogOpenFlag] = true } )

    if not _noSync then
        RoleSync:syncSelf( _rid, { [Enum.Role.denseFog] = {}, [Enum.Role.denseFogOpenFlag] = true }, true )
    end
end

return DenseFogLogic