--[[
* @file : AoiMgr.lua
* @type : service
* @author : linfeng
* @created : Thu Nov 23 2017 14:11:47 GMT+0800 (中国标准时间)
* @department : Arabic Studio
* @brief : AOI 管理服务
* Copyright(C) 2017 IGG, All rights reserved
]]

local snax = require "skynet.snax"
local string = string
local table = table
local aoiCore = require "aoi.core"
local aoiSpacies = {} --{ mapId = aoiSpace }

-- 场景服务对象
local sceneServices = {}

function exit()
	--释放 aoi space指针
	for _,aoiSpace in pairs(aoiSpacies) do
		aoiCore.release(aoiSpace)
	end
	aoiSpacies = {}
end

---@see 初始化aoi对象
---@param  _realMpaId integer 实际的地图ID
---@param  _virtualMapId integer 虚拟地图ID
function response.initMapAoi( _realMpaId, _virtualMapId, _radius )
	if not _radius then
		_radius = Enum.AoiRadius -- 取默认半径
	end
	_virtualMapId = _virtualMapId or _realMpaId
	aoiSpacies[_virtualMapId] = assert(aoiCore.new( _virtualMapId, 50000, _radius ))
	setmetatable(aoiSpacies, { __mode = "k" } )
	sceneServices[_virtualMapId] = assert(snax.newservice("SceneMgr"))
end

---@see 删除一个aoi对象
function response.unInitMapAoi( _virtualMapId )
	local sceneService = sceneServices[_virtualMapId]
	local aoiSpacePtr = aoiSpacies[_virtualMapId]
	if not aoiSpacePtr then
		LOG_WARNING("unInitMapAoi fail, virtualMapId(%d)", _virtualMapId)
		return
	end

	sceneServices[_virtualMapId] = nil
	aoiSpacies[_virtualMapId] = nil

	aoiCore.release( aoiSpacePtr )
	-- 删除场景服务
	snax.kill( sceneService )

	LOG_INFO("unInitMapAoi ok, virtualMapId(%d)", _virtualMapId)
end

---@see 根据地图ID获取场景对象
function response.getSceneMgr( _virtualMapId )
	if sceneServices[_virtualMapId] then
		return sceneServices[_virtualMapId].handle
	end
end

---@see aoi回调函数
---@param aoiMapId integer @AOI地图ID(副本是虚拟地图ID)
---@param ridWatcher integer @观察者,aoi的中心对象
---@param ridMarker integer @被观察者,在watcher aoi范围内的对象
---@param action string @动作
---@param x integer @x坐标
---@param y integer @y坐标
---@param z integer @z坐标
---@param tx integer @tx目标坐标
---@param ty integer @ty目标坐标
---@param tz integer @tz目标坐标
---@param rtype integer @角色类型
local function aoiCallBack( aoiMapId, ridWatcher, ridMarker, action, x, y, z, tx, ty, tz, rtype )
	if sceneServices[aoiMapId] then
		sceneServices[aoiMapId].post.roleSceneMove( ridWatcher, ridMarker, action,
										{ x = x, y = y, z = z }, { x = tx, y = ty, z = tz }, rtype )
	end
end

---@see 更新aoi
local function updateAoi( _virtualMapId, _objectIndex, pos, tpos, mode, rtype )
	if mode == nil then mode = "wm" end
	assert( aoiSpacies[_virtualMapId] ~= nil, tostring(_virtualMapId) )
	aoiCore.update( aoiSpacies[_virtualMapId], _objectIndex, mode, rtype, pos.x, pos.y, ( pos.z or 0 ), tpos.x, tpos.y, ( tpos.z or 0 ) )
	aoiCore.message( aoiSpacies[_virtualMapId], aoiCallBack )
end

---@see 角色更新fd信息
function response.roleUpdateFd( _virtualMapId, _objectIndex )
	if not aoiSpacies[_virtualMapId] then return end
	if sceneServices[_virtualMapId] then
		-- 角色加入场景
		sceneServices[_virtualMapId].req.updateRoleFdSecret( _objectIndex )
	end
end

---@see 角色进入AOI
function response.roleEnter( _virtualMapId, _objectIndex, pos, tpos, _fd, _secret )
	if not aoiSpacies[_virtualMapId] then return end
	if sceneServices[_virtualMapId] then
		-- 角色加入场景
		sceneServices[_virtualMapId].req.roleSceneEnter( _objectIndex, Enum.RoleType.ROLE, _fd, _secret )
	end
	--新的role obj,即使wather,也是masker
	updateAoi( _virtualMapId, _objectIndex, pos, tpos, "w", Enum.RoleType.ROLE )
end

---@see 角色离开AOI
function response.roleLeave( _virtualMapId, _objectIndex, pos )
	if not aoiSpacies[_virtualMapId] then return end
	if sceneServices[_virtualMapId] then
		-- 角色离开场景
		sceneServices[_virtualMapId].req.roleSceneLeave( _objectIndex )
	end
	--删除一个role obj
	updateAoi( _virtualMapId, _objectIndex, pos, { x = -1, y = -1, z = -1 }, "d", Enum.RoleType.ROLE )
end

---@see 角色更新AOI
function accept.roleUpdate( _virtualMapId, _objectIndex, pos, tpos )
	if not aoiSpacies[_virtualMapId] then return end
	--更新role obj的pos,wather
	updateAoi( _virtualMapId, _objectIndex, pos, tpos, "w", Enum.RoleType.ROLE )
end

---@see MONSTER加入AOI
function response.monsterEnter( _virtualMapId, _objectIndex, _pos, _tpos, _monsterInfo )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册对象
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, _monsterInfo.objectType )
	-- 加入动态障碍
	if Common.isServerStart() then
		SM.NavMeshObstracleMgr.post.addObstracle( _objectIndex, _monsterInfo.objectType, _pos, _monsterInfo.monsterId )
	else
		SM.NavMeshObstracleMgr.req.addObstracle( _objectIndex, _monsterInfo.objectType, _pos, _monsterInfo.monsterId )
	end
	-- 增加到怪物管理中
	MSM.SceneMonsterMgr[_objectIndex].req.addMonsterObject( _objectIndex, _monsterInfo, _pos )
	--新的 monster obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", _monsterInfo.objectType )
end

---@see MONSTER离开AOI
function response.monsterLeave( _virtualMapId, _objectIndex, _pos, _roleType )
	if not aoiSpacies[_virtualMapId] then return end
	--删除一个monster obj
	updateAoi( _virtualMapId, _objectIndex, _pos, { x = -1, y = -1, z = -1 }, "d", _roleType or Enum.RoleType.MONSTER )
	-- 移除动态障碍
	SM.NavMeshObstracleMgr.req.delObstracle( _objectIndex )
	-- 注销对象
	MSM.MapObjectTypeMgr[_objectIndex].post.deleteObjectType( _objectIndex )
	-- 从怪物管理移除
	MSM.SceneMonsterMgr[_objectIndex].post.deleteMonsterObject( _objectIndex )
end

---@see MONSTER更新AOI
function accept.monsterUpdate( _virtualMapId, _objectIndex, _pos, _tpos )
	if not aoiSpacies[_virtualMapId] then return end
	--新的 monster obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", Enum.RoleType.MONSTER )
	-- 更新怪物坐标
	MSM.SceneMonsterMgr[_objectIndex].post.updateMonsterPos( _objectIndex, _pos )
end

---@see Army加入AOI
function response.armyEnter( _virtualMapId, _objectIndex, _pos, _tpos, _armyInfo )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册到对象类型服务
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, Enum.RoleType.ARMY, _armyInfo.rid )
	-- 注册到军队管理服务中
	MSM.SceneArmyMgr[_objectIndex].req.addArmyObject( _objectIndex, _armyInfo, _pos )
	-- 添加到场景中
	if sceneServices[_virtualMapId] then
		-- 加入场景
		sceneServices[_virtualMapId].post.mapObjectSceneEnter( _objectIndex )
	end
	--新的 army obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "wm", Enum.RoleType.ARMY )
end

---@see Army离开AOI
function response.armyLeave( _virtualMapId, _objectIndex, _pos )
	if not aoiSpacies[_virtualMapId] then return end
	--删除一个army obj
	updateAoi( _virtualMapId, _objectIndex, _pos, { x = -1, y = -1, z = -1 }, "d", Enum.RoleType.ARMY )
	-- 从对象类型服务删除
	MSM.MapObjectTypeMgr[_objectIndex].post.deleteObjectType( _objectIndex )
	-- 从军队管理移除
	MSM.SceneArmyMgr[_objectIndex].post.deleteArmyObject( _objectIndex )
	-- 从场景中移除
	if sceneServices[_virtualMapId] then
		-- 离开场景
		sceneServices[_virtualMapId].post.mapObjectSceneLeave( _objectIndex )
	end
end

---@see Army更新AOI
function accept.armyUpdate( _virtualMapId, _objectIndex, _pos, _tpos )
	if not aoiSpacies[_virtualMapId] then return end
	--新的 army obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "wm", Enum.RoleType.ARMY )
	-- 更新军队管理坐标
	MSM.SceneArmyMgr[_objectIndex].post.updateArmyObjectPos( _objectIndex, _pos )
end

---@see 城市进入AOI
function response.cityEnter( _virtualMapId, _objectIndex, _pos, _tpos, cityInfo )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册角色城市索引
	sceneServices[_virtualMapId].req.addRoleCityIndex( cityInfo.rid, _objectIndex )
	-- 注册对象
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, Enum.RoleType.CITY, cityInfo.rid )
	-- 加入动态障碍
	if Common.isServerStart() then
		SM.NavMeshObstracleMgr.post.addObstracle( _objectIndex, Enum.RoleType.CITY, _pos )
	else
		SM.NavMeshObstracleMgr.req.addObstracle( _objectIndex, Enum.RoleType.CITY, _pos )
	end
	-- 增加到城市管理
	MSM.SceneCityMgr[_objectIndex].req.addCityObject( _objectIndex, cityInfo, _pos )
	--新的city obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", Enum.RoleType.CITY )
end

---@see 城市离开AOI
function response.cityLeave( _virtualMapId, _objectIndex, _pos, _rid )
	if not aoiSpacies[_virtualMapId] then return end
	--删除一个city obj
	updateAoi( _virtualMapId, _objectIndex, _pos, { x = -1, y = -1, z = -1 }, "d", Enum.RoleType.CITY )
	-- 移除动态障碍
	SM.NavMeshObstracleMgr.req.delObstracle( _objectIndex )
	-- 注销对象
	MSM.MapObjectTypeMgr[_objectIndex].post.deleteObjectType( _objectIndex )
	-- 从城市管理移除
	MSM.SceneCityMgr[_objectIndex].post.deleteCityObject( _objectIndex )
	-- 删除角色城市索引
	sceneServices[_virtualMapId].post.deleteRoleCityIndex( _rid, _objectIndex )
end

---@see 城市更新AOI
function accept.cityUpdate( _virtualMapId, _objectIndex, _pos, _tpos )
	if not aoiSpacies[_virtualMapId] then return end
	-- 更新城市管理服务
	MSM.SceneCityMgr[_objectIndex].req.updateCityPos( _objectIndex, _pos )
	--更新city obj的pos,被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", Enum.RoleType.CITY )
	-- 更新动态障碍
	SM.NavMeshObstracleMgr.post.updateObstracle( _objectIndex, _pos )
end

---@see 资源点进入AOI
function response.resourceEnter( _virtualMapId, _objectIndex, _pos, _tpos, _resourceInfo, _resourceType )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册对象
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, _resourceType )
	-- 加入动态障碍
	if Common.isServerStart() then
		SM.NavMeshObstracleMgr.post.addObstracle( _objectIndex, _resourceType, _pos )
	else
		SM.NavMeshObstracleMgr.req.addObstracle( _objectIndex, _resourceType, _pos )
	end
	-- 增加到资源管理服务
	MSM.SceneResourceMgr[_objectIndex].req.addResourceObject( _objectIndex, _resourceInfo, _pos, _resourceType )
	-- 新的resource obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", _resourceType )
end

---@see 资源点离开AOI
function response.resourceLeave( _virtualMapId, _objectIndex, _pos, _resourceType )
	if not aoiSpacies[_virtualMapId] then return end
	-- 删除一个resource obj
	updateAoi( _virtualMapId, _objectIndex, _pos, { x = -1, y = -1, z = -1 }, "d", _resourceType )
	-- 移除动态障碍
	SM.NavMeshObstracleMgr.req.delObstracle( _objectIndex )
	-- 注销对象
	MSM.MapObjectTypeMgr[_objectIndex].post.deleteObjectType( _objectIndex )
	-- 从资源管理删除
	MSM.SceneResourceMgr[_objectIndex].post.deleteResourceObject( _objectIndex )
end

---@see 资源点更新AOI
function accept.resourceUpdate( _virtualMapId, _objectIndex, _pos, _tpos, _resourceType )
	if not aoiSpacies[_virtualMapId] then return end
	-- 更新resource obj信息,被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", _resourceType )
	-- 更新动态障碍
	SM.NavMeshObstracleMgr.post.updateObstracle( _objectIndex, _pos )
end

---@see 斥候进入
function response.scoutsEnter( _virtualMapId, _objectIndex, _pos, _tpos, _scoutsInfo )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册到对象类型服务
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, Enum.RoleType.SCOUTS )
	-- 增加到城市管理
	MSM.SceneScoutsMgr[_objectIndex].req.addScoutsObject( _objectIndex, _scoutsInfo, _pos )
	--新的city obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", Enum.RoleType.SCOUTS )
end

---@see 斥候退出
function response.scoutsLeave( _virtualMapId, _objectIndex, _pos )
	if not aoiSpacies[_virtualMapId] then return end
	-- 删除一个scouts obj
	updateAoi( _virtualMapId, _objectIndex, _pos, { x = -1, y = -1, z = -1 }, "d", Enum.RoleType.SCOUTS )
	-- 从对象类型服务删除
	MSM.MapObjectTypeMgr[_objectIndex].post.deleteObjectType( _objectIndex )
	-- 从资源管理删除
	MSM.SceneScoutsMgr[_objectIndex].post.deleteScoutsObject( _objectIndex )
end

---@see 斥候更新
function accept.scoutsUpdate( _virtualMapId, _objectIndex, _pos, _tpos )
	if not aoiSpacies[_virtualMapId] then return end
	-- 更新scouts obj信息,被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", Enum.RoleType.SCOUTS )
	-- 更新资源管理
	MSM.SceneScoutsMgr[_objectIndex].post.updateScoutsPos( _objectIndex, _pos )
end

---@see 联盟建筑进入Aoi
function response.guildBuildEnter( _virtualMapId, _objectIndex, _pos, _tpos, _buildInfo, _roleType )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册对象
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, _roleType )
	-- 加入动态障碍
	if Common.isServerStart() then
		SM.NavMeshObstracleMgr.post.addObstracle( _objectIndex, _roleType, _pos )
	else
		SM.NavMeshObstracleMgr.req.addObstracle( _objectIndex, _roleType, _pos )
	end
	-- 增加到联盟建筑管理
	MSM.SceneGuildBuildMgr[_objectIndex].req.addGuildBuildObject( _objectIndex, _buildInfo )
	--新的city obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", _roleType )
end

---@see 联盟建筑退出Aoi
function accept.guildBuildLeave( _virtualMapId, _objectIndex, _pos, _objectType )
	if not aoiSpacies[_virtualMapId] then return end
	-- 删除一个scouts obj
	updateAoi( _virtualMapId, _objectIndex, _pos, { x = -1, y = -1, z = -1 }, "d", _objectType )
	-- 移除动态障碍
	SM.NavMeshObstracleMgr.req.delObstracle( _objectIndex )
	-- 注销对象
	MSM.MapObjectTypeMgr[_objectIndex].post.deleteObjectType( _objectIndex )
	-- 从联盟建筑管理删除
	MSM.SceneGuildBuildMgr[_objectIndex].post.deleteGuildBuildObject( _objectIndex )
end

---@see 运输部队进入
function response.transportEnter( _virtualMapId, _objectIndex, _pos, _tpos, _transportInfo )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册到对象类型服务
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, Enum.RoleType.TRANSPORT )
	-- 增加到运输管理管理
	MSM.SceneTransportMgr[_objectIndex].req.addTransportObject( _objectIndex, _transportInfo, _pos )
	--新的city obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", Enum.RoleType.TRANSPORT )
end

---@see 运输马车退出
function response.transportLeave( _virtualMapId, _objectIndex, _pos )
	if not aoiSpacies[_virtualMapId] then return end
	-- 删除一个scouts obj
	updateAoi( _virtualMapId, _objectIndex, _pos, { x = -1, y = -1, z = -1 }, "d", Enum.RoleType.TRANSPORT )
	-- 从对象类型服务删除
	MSM.MapObjectTypeMgr[_objectIndex].post.deleteObjectType( _objectIndex )
	-- 从资源管理删除
	MSM.SceneTransportMgr[_objectIndex].post.deleteTransportObject( _objectIndex )
end

---@see 运输车更新
function accept.transportUpdate( _virtualMapId, _objectIndex, _pos, _tpos )
	if not aoiSpacies[_virtualMapId] then return end
	-- 更新scouts obj信息,被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", Enum.RoleType.TRANSPORT )
	-- 更新资源管理
	MSM.SceneTransportMgr[_objectIndex].post.updateScoutsPos( _objectIndex, _pos )
end

---@see 野蛮人城寨加入AOI
function response.monsterCityEnter( _virtualMapId, _objectIndex, _pos, _tpos, _monsterCityInfo )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册对象
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, Enum.RoleType.MONSTER_CITY )
	-- 加入动态障碍
	if Common.isServerStart() then
		SM.NavMeshObstracleMgr.post.addObstracle( _objectIndex, Enum.RoleType.MONSTER_CITY, _pos )
	else
		SM.NavMeshObstracleMgr.req.addObstracle( _objectIndex, Enum.RoleType.MONSTER_CITY, _pos )
	end
	-- 增加到怪物管理中
	MSM.SceneMonsterCityMgr[_objectIndex].req.addMonsterCityObject( _objectIndex, _monsterCityInfo, _pos )
	--新的 monster obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", Enum.RoleType.MONSTER_CITY )
end

---@see 野蛮人城寨离开AOI
function response.monsterCityLeave( _virtualMapId, _objectIndex, _pos )
	if not aoiSpacies[_virtualMapId] then return end
	--删除一个monster obj
	updateAoi( _virtualMapId, _objectIndex, _pos, { x = -1, y = -1, z = -1 }, "d", Enum.RoleType.MONSTER_CITY )
	-- 移除动态障碍
	SM.NavMeshObstracleMgr.req.delObstracle( _objectIndex )
	-- 注销对象
	MSM.MapObjectTypeMgr[_objectIndex].post.deleteObjectType( _objectIndex )
	-- 从怪物管理移除
	MSM.SceneMonsterCityMgr[_objectIndex].post.deleteMonsterCityObject( _objectIndex )
end

---@see 圣地守护者加入AOI
function response.guardHolyLandEnter( _virtualMapId, _objectIndex, _pos, _tpos, _monsterInfo )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册对象
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, Enum.RoleType.GUARD_HOLY_LAND )
	-- 加入动态障碍
	if Common.isServerStart() then
		SM.NavMeshObstracleMgr.post.addObstracle( _objectIndex, Enum.RoleType.GUARD_HOLY_LAND, _pos, _monsterInfo.monsterId )
	else
		SM.NavMeshObstracleMgr.req.addObstracle( _objectIndex, Enum.RoleType.GUARD_HOLY_LAND, _pos, _monsterInfo.monsterId )
	end
	-- 增加到圣地守护者管理中
	MSM.SceneMonsterMgr[_objectIndex].req.addMonsterObject( _objectIndex, _monsterInfo, _pos )
	-- 更新 圣地守护者 obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", Enum.RoleType.GUARD_HOLY_LAND )
end

---@see 圣地守护者离开AOI
function response.guardHolyLandLeave( _virtualMapId, _objectIndex, _pos )
	if not aoiSpacies[_virtualMapId] then return end
	--删除一个 圣地守护者 obj
	updateAoi( _virtualMapId, _objectIndex, _pos, { x = -1, y = -1, z = -1 }, "d", Enum.RoleType.GUARD_HOLY_LAND )
	-- 移除动态障碍
	SM.NavMeshObstracleMgr.req.delObstracle( _objectIndex )
	-- 注销对象
	MSM.MapObjectTypeMgr[_objectIndex].post.deleteObjectType( _objectIndex )
	-- 从圣地守护者管理移除
	MSM.SceneMonsterMgr[_objectIndex].post.deleteMonsterObject( _objectIndex )
end

---@see 圣地守护者更新AOI
function accept.guardHolyLandUpdate( _virtualMapId, _objectIndex, _pos, _tpos )
	if not aoiSpacies[_virtualMapId] then return end
	-- 更新 圣地守护者 obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", Enum.RoleType.GUARD_HOLY_LAND )
	-- 更新圣地守护者坐标
	MSM.SceneMonsterMgr[_objectIndex].post.updateMonsterPos( _objectIndex, _pos )
end

---@see 圣地加入AOI
function response.holyLandEnter( _virtualMapId, _objectIndex, _pos, _tpos, _holyLandInfo, _objectType )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册对象
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, _objectType )
	-- 加入动态障碍
	if Common.isServerStart() then
		SM.NavMeshObstracleMgr.post.addObstracle( _objectIndex, _objectType, _pos, _holyLandInfo.strongHoldId )
	else
		SM.NavMeshObstracleMgr.req.addObstracle( _objectIndex, _objectType, _pos, _holyLandInfo.strongHoldId )
	end
	-- 增加到圣地管理中
	MSM.SceneHolyLandMgr[_objectIndex].req.addHolyLandObject( _objectIndex, _holyLandInfo, _pos )
	-- 更新 圣地 obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", _objectType )
end

---@see 圣地离开AOI
function response.holyLandLeave( _virtualMapId, _objectIndex, _pos, _objectType )
	if not aoiSpacies[_virtualMapId] then return end
	--删除一个 圣地 obj
	updateAoi( _virtualMapId, _objectIndex, _pos, { x = -1, y = -1, z = -1 }, "d", _objectType )
	-- 移除动态障碍
	SM.NavMeshObstracleMgr.req.delObstracle( _objectIndex )
	-- 注销对象
	MSM.MapObjectTypeMgr[_objectIndex].post.deleteObjectType( _objectIndex )
	-- 从圣地管理移除
	MSM.SceneHolyLandMgr[_objectIndex].post.deleteHolyLandObject( _objectIndex )
end

---@see 符文加入AOI
function response.runeEnter( _virtualMapId, _objectIndex, _pos, _tpos, _runeInfo )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册对象
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, Enum.RoleType.RUNE )
	-- 加入动态障碍
	if Common.isServerStart() then
		SM.NavMeshObstracleMgr.post.addObstracle( _objectIndex, Enum.RoleType.RUNE, _pos )
	else
		SM.NavMeshObstracleMgr.req.addObstracle( _objectIndex, Enum.RoleType.RUNE, _pos )
	end
	-- 增加到符文管理中
	MSM.SceneRuneMgr[_objectIndex].req.addRuneObject( _objectIndex, _runeInfo, _pos )
	-- 更新 符文 obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", Enum.RoleType.RUNE )
end

---@see 符文离开AOI
function response.runeLeave( _virtualMapId, _objectIndex, _pos )
	if not aoiSpacies[_virtualMapId] then return end
	--删除一个 符文 obj
	updateAoi( _virtualMapId, _objectIndex, _pos, { x = -1, y = -1, z = -1 }, "d", Enum.RoleType.RUNE )
	-- 移除动态障碍
	SM.NavMeshObstracleMgr.req.delObstracle( _objectIndex )
	-- 注销对象
	MSM.MapObjectTypeMgr[_objectIndex].post.deleteObjectType( _objectIndex )
	-- 从符文管理服务移除
	MSM.SceneRuneMgr[_objectIndex].post.deleteRuneObject( _objectIndex )
end

---@see 联盟资源点加入AOI
function response.guildResourcePointEnter( _virtualMapId, _objectIndex, _pos, _tpos, _resourcePointInfo )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册对象
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, _resourcePointInfo.objectType )
	-- 加入动态障碍
	if Common.isServerStart() then
		SM.NavMeshObstracleMgr.post.addObstracle( _objectIndex, _resourcePointInfo.objectType, _pos )
	else
		SM.NavMeshObstracleMgr.req.addObstracle( _objectIndex, _resourcePointInfo.objectType, _pos )
	end
	-- 增加到联盟资源点管理中
	MSM.SceneGuildResourcePointMgr[_objectIndex].req.addGuildResourcePointObject( _objectIndex, _resourcePointInfo )
	-- 更新 联盟资源点 obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", _resourcePointInfo.objectType )
end

---@see 远征对象加入AOI
function response.expeditionObjectEnter( _virtualMapId, _objectIndex, _pos, _tpos, _objectInfo )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册到对象类型服务
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, _objectInfo.objectType, _objectInfo.rid or 0 )
	-- 增加到怪物管理中
	MSM.SceneExpeditionMgr[_objectIndex].req.addExpeditionObject( _objectIndex, _objectInfo, _pos )
	--新的 monster obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", _objectInfo.objectType )
end

---@see 远征对象离开AOI
function response.expeditionObjectLeave( _virtualMapId, _objectIndex, _pos, _roleType )
	if not aoiSpacies[_virtualMapId] then return end
	--删除一个monster obj
	updateAoi( _virtualMapId, _objectIndex, _pos, { x = -1, y = -1, z = -1 }, "d", _roleType or Enum.RoleType.EXPEDITION )
	-- 从对象类型服务删除
	MSM.MapObjectTypeMgr[_objectIndex].post.deleteObjectType( _objectIndex )
	-- 从怪物管理移除
	MSM.SceneExpeditionMgr[_objectIndex].req.deleteExpeditionObject( _objectIndex )
end

---@see 远征对象更新AOI
function accept.expeditionObjectUpdate( _virtualMapId, _objectIndex, _pos, _tpos )
	if not aoiSpacies[_virtualMapId] then return end
	--新的 monster obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", Enum.RoleType.EXPEDITION )
	-- 更新怪物坐标
	MSM.SceneExpeditionMgr[_objectIndex].post.updateExpeditionPos( _objectIndex, _pos )
end

---@see 召唤怪物加入AOI
function response.summonMonsterEnter( _virtualMapId, _objectIndex, _pos, _tpos, _monsterInfo )
	if not aoiSpacies[_virtualMapId] then return end
	-- 注册对象
	MSM.MapObjectTypeMgr[_objectIndex].req.addObjectType( _objectIndex, _monsterInfo.objectType )
	-- 加入动态障碍
	if Common.isServerStart() then
		SM.NavMeshObstracleMgr.post.addObstracle( _objectIndex, _monsterInfo.objectType, _pos, _monsterInfo.monsterId )
	else
		SM.NavMeshObstracleMgr.req.addObstracle( _objectIndex, _monsterInfo.objectType, _pos, _monsterInfo.monsterId )
	end
	-- 增加到召唤怪物管理中
	MSM.SceneMonsterMgr[_objectIndex].req.addMonsterObject( _objectIndex, _monsterInfo, _pos )
	-- 更新 召唤怪物 obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", _monsterInfo.objectType )
end

---@see 召唤怪物离开AOI
function response.summonMonsterLeave( _virtualMapId, _objectIndex, _pos, _objectType )
	if not aoiSpacies[_virtualMapId] then return end
	--删除一个 召唤怪物 obj
	updateAoi( _virtualMapId, _objectIndex, _pos, { x = -1, y = -1, z = -1 }, "d", _objectType )
	-- 移除动态障碍
	SM.NavMeshObstracleMgr.req.delObstracle( _objectIndex )
	-- 注销对象
	MSM.MapObjectTypeMgr[_objectIndex].post.deleteObjectType( _objectIndex )
	-- 从召唤怪物管理移除
	MSM.SceneMonsterMgr[_objectIndex].post.deleteMonsterObject( _objectIndex )
end

---@see 召唤怪物更新AOI
function accept.summonMonsterUpdate( _virtualMapId, _objectIndex, _pos, _tpos, _objectType )
	if not aoiSpacies[_virtualMapId] then return end
	-- 更新 召唤怪物 obj, 被观察者masker
	updateAoi( _virtualMapId, _objectIndex, _pos, _tpos, "m", _objectType )
	-- 更新召唤怪物坐标
	MSM.SceneMonsterMgr[_objectIndex].post.updateMonsterPos( _objectIndex, _pos )
end