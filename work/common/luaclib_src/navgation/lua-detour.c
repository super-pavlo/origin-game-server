/*
 * @file : lua-detour.c
 * @type : c
 * @author : linfeng
 * @created : 2019-12-16 13:45:24
 * @Last Modified time: 2019-12-16 13:45:24
 * @department : Arabic Studio
 * @brief : 寻路相关
 * Copyright(C) 2019 IGG, All rights reserved
*/

#include <lua.h>
#include <lauxlib.h>
#include "detour.h"

static int
lnewNavMeshQuery(lua_State* L)
{
	void* navQuery = newNavMeshQuery();
	lua_pushlightuserdata(L, navQuery);
	return 1;
}

static int
lfreeNavMeshQuery(lua_State* L)
{
	void* navQuery = (void*)lua_touserdata(L, 1);
	if(navQuery != NULL)
		freeNavMeshQuery(navQuery);
	return 0;
}

static int
lnewTileCache(lua_State* L)
{
	void* tileCache = newTileCache();
	lua_pushlightuserdata(L, tileCache);
	return 1;
}

static int
lfreeTileCache(lua_State* L)
{
	void* tileCache = (void*)lua_touserdata(L, 1);
	if(tileCache != NULL)
		freeTileCache(tileCache);
	return 0;
}

static int
linitMapMesh(lua_State* L)
{
	void* navQuery = (void*)lua_touserdata(L, 1);
	if(navQuery != NULL)
	{
		const char* filepath = lua_tostring(L, 2);
		lua_pushboolean(L, initMesh(navQuery, filepath));
		return 1;
	}
	return 0;
}

static int
lfindStraightPath(lua_State* L)
{
	void* navQuery = (void*)lua_touserdata(L, 1);
	if(navQuery != NULL)
	{
		float spos[3] = {0, 0, 0};
		float epos[3] = {0, 0, 0};
		spos[0] = -lua_tointeger(L, 2) / 100.0f;
		spos[1] = lua_tointeger(L, 3) / 100.0f;
		spos[2] = lua_tointeger(L, 4) / 100.0f;
		epos[0] = -lua_tointeger(L, 5) / 100.0f;
		epos[1] = lua_tointeger(L, 6) / 100.0f;
		epos[2] = lua_tointeger(L, 7) / 100.0f;

		int nstraightPathCount = 0;
		float* path = findStraightPathImpl(navQuery, spos, epos, &nstraightPathCount);
		if(nstraightPathCount > 0 && path != NULL)
		{
			lua_newtable(L); // 生成table,放在栈顶
			for (size_t i = 0; i < nstraightPathCount; i++)
			{
				lua_pushinteger(L, i+1); // table key 一级表
				lua_newtable(L); // table value 一级表

				lua_pushstring(L, "x"); // 二级表 table key
				lua_pushinteger(L, -path[i*3] * 100); // 二级表 table value
				lua_settable(L, -3); // 弹出key,value 设置到二级table
				/*
				lua_pushstring(L, "y"); // 二级表 table key
				lua_pushinteger(L, path[i*3+1] * 100); // 二级表 table value
				lua_settable(L, -3); // 弹出key,value 设置到二级table
				*/
				lua_pushstring(L, "y"); // 二级表 table key
				lua_pushinteger(L, path[i*3+2] * 100); // 二级表 table value
				lua_settable(L, -3); // 弹出key,value 设置到二级table

				lua_settable(L, -3); // 弹出key,value 设置到一级table
			}
			return 1;
		}

		return 0;
	}
    return 0;
}

static int
lfindPloyByPos(lua_State* L)
{
	void* navQuery = (void*)lua_touserdata(L, 1);
	if(navQuery != NULL)
	{
		float pos[3] = {0, 0, 0};
		pos[0] = -lua_tointeger(L, 2) / 100.0f;
		pos[1] = lua_tointeger(L, 3) / 100.0f;
		pos[2] = lua_tointeger(L, 4) / 100.0f;
		unsigned int ref;
		if(findPloyByPos(navQuery, pos, &ref))
		{
			lua_pushinteger(L, ref);
			return 1;
		}
		else
			return 0;
	}
	return 0;
}

static int
linitObstaclesMapMesh(lua_State* L)
{
	void* navQuery = (void*)lua_touserdata(L, 1);
	void* tileCache = (void*)lua_touserdata(L, 2);
	if(navQuery != NULL && tileCache != NULL)
	{
		const char* filepath = lua_tostring(L, 3);
		lua_pushboolean(L, initObstraclesMesh(navQuery, tileCache, filepath));
		return 1;
	}
	return 0;
}

static int
laddObstacles(lua_State* L)
{
	void* navQuery = (void*)lua_touserdata(L, 1);
	void* tileCache = (void*)lua_touserdata(L, 2);
	float pos[3] = {0};
	pos[0] = -lua_tointeger(L, 3) / 100.0f;
	pos[1] = lua_tointeger(L, 4) / 100.0f;
	pos[2] = lua_tointeger(L, 5) / 100.0f;
	float radius = lua_tonumber(L, 6);
	bool delayUpate = lua_toboolean(L, 7);
	if(navQuery != NULL && tileCache != NULL)
	{
		unsigned int ref = 0;
		bool status = addObstraclesObject(navQuery, tileCache, pos, radius, &ref, delayUpate);
		lua_pushboolean(L, status);
		lua_pushinteger(L, ref);
		return 2;
	}
	return 0;
}

static int
lremoveObstacles(lua_State* L)
{
	void* navQuery = (void*)lua_touserdata(L, 1);
	void* tileCache = (void*)lua_touserdata(L, 2);
	unsigned int ref = lua_tointeger(L, 3);
	if(navQuery != NULL && tileCache != NULL)
	{
		lua_pushboolean(L, removeObsttaclesObject(navQuery, tileCache, ref));
		return 1;
	}
	return 0;
}

static int
ltickUpdate(lua_State* L)
{
	void* navQuery = (void*)lua_touserdata(L, 1);
	void* tileCache = (void*)lua_touserdata(L, 2);
	if(navQuery != NULL && tileCache != NULL)
		tickUpdate(navQuery, tileCache);
	return 0;
}

static int
lcheckIdlePos(lua_State* L)
{
	void* navQuery = (void*)lua_touserdata(L, 1);
	if(navQuery != NULL)
	{
		float c[3] = {0, 0, 0};
		c[0] = -lua_tonumber(L, 2) / 100.0f;
		c[1] = lua_tonumber(L, 3) / 100.0f;
		c[2] = lua_tonumber(L, 4) / 100.0f;

		float p[3] = {0, 0, 0};
		p[0] = -lua_tonumber(L, 5) / 100.0f;
		p[1] = lua_tonumber(L, 6) / 100.0f;
		p[2] = lua_tonumber(L, 7) / 100.0f;

		bool isIdle = checkPosIdle(navQuery, c, p);
		lua_pushboolean(L, isIdle);
		return 1;
	}
	return 0;
}

int luaopen_detour_core(lua_State* L)
{
	luaL_checkversion(L);
	luaL_Reg l[] =
	{
		{ "initMapMesh", linitMapMesh },
		{ "newNavMeshQuery", lnewNavMeshQuery },
		{ "freeNavMeshQuery", lfreeNavMeshQuery },
		{ "newTileCache", lnewTileCache },
		{ "freeTileCache", lfreeTileCache },
		{ "findStraightPath", lfindStraightPath },
		{ "findPloyByPos", lfindPloyByPos },
		{ "initObstaclesMapMesh", linitObstaclesMapMesh },
		{ "addObstacles", laddObstacles },
		{ "removeObstacles", lremoveObstacles },
		{ "tickUpdate", ltickUpdate },
		{ "checkIdlePos", lcheckIdlePos },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}