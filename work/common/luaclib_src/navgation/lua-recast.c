/*
 * @file : lua-recast.c
 * @type : c
 * @author : linfeng
 * @created : 2020-04-26 17:19:59
 * @Last Modified time: 2020-04-26 17:19:59
 * @department : Arabic Studio
 * @brief : 寻路导航网格生成
 * Copyright(C) 2019 IGG, All rights reserved
*/

#include <lua.h>
#include <lauxlib.h>
#include <stdbool.h>
#include "recastnavmesh.h"

static int
linitNavMeshObj(lua_State* L)
{
    const char* filepath = lua_tostring(L, 1);
    bool ret = loadMeshObj(filepath);
    void* navMesh = NULL;
    if(ret)
	{
		navMesh = buildMeshObj();
		if(navMesh != NULL)
		{
			lua_pushlightuserdata(L, navMesh);
			return 1;
		}
	}

	return 0;
}

static int
lsaveNavMeshToBin(lua_State* L)
{
	const char* filepath = lua_tostring(L, 1);
	bool ret = saveNavMesh(filepath);
	lua_pushboolean(L, ret);
	return 1;
}

static int
linitObstaclesNavMeshObj(lua_State* L)
{
    const char* filepath = lua_tostring(L, 1);
    bool ret = loadMeshObj(filepath);
    void* navMesh = NULL;
    if(ret)
	{
		navMesh = buildObstaclesNavMesh();
		if(navMesh != NULL)
		{
			lua_pushlightuserdata(L, navMesh);
			return 1;
		}
	}

	return 0;
}

static int
lsaveObstaclesNavMeshToBin(lua_State* L)
{
	const char* filepath = lua_tostring(L, 1);
	bool ret = saveObstaclesNavMesh(filepath);
	lua_pushboolean(L, ret);
	return 1;
}

int luaopen_recast_core(lua_State* L)
{
	luaL_checkversion(L);
	luaL_Reg l[] =
	{
		{ "initNavMeshObj", linitNavMeshObj },
		{ "saveNavMeshToBin", lsaveNavMeshToBin },
		{ "initObstaclesNavMeshObj", linitObstaclesNavMeshObj },
		{ "saveObstaclesNavMeshToBin", lsaveObstaclesNavMeshToBin },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}