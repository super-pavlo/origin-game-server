/*
* @Author: linfeng
* @Date:   2017-06-08 16:39:41
 * @Last Modified by: linfeng
 * @Last Modified time: 2020-09-04 12:20:51
*/

#include <stdio.h>
#include <stdbool.h>
#include <assert.h>
#include <lua.h>
#include <lauxlib.h>

#include "aoi.h"

static int lnew(lua_State* L)
{
	float radius = lua_tonumber(L, 3);
	struct aoi_space* space = aoi_new(radius);
	if(space == NULL)
		return 0;
	space->aoiMapId = lua_tointeger(L, 1);
	space->pair_hash = NULL;
	space->maxAoiCount = lua_tointeger(L, 2);
	lua_pushlightuserdata(L, space);
	return 1;
}

static int lrelease(lua_State* L)
{
	luaL_checktype(L ,1, LUA_TLIGHTUSERDATA);
	struct aoi_space* space = lua_touserdata(L, -1);
	HASH_CLEAR(hh, space->pair_hash);
	aoi_release(space);
	space = NULL;
	lua_pushboolean(L, true);
	return 1;
}

static void aoi_cb(void *ud, uint32_t aoiMapId, uint32_t watcher, uint32_t marker,
				   const char *action, float pos[3], float tpos[3], uint32_t rtype)
{
	lua_State *L = (lua_State *)ud;
	lua_rawgetp(L, LUA_REGISTRYINDEX, aoi_cb);
	lua_pushinteger(L, aoiMapId);
	lua_pushinteger(L, watcher);
	lua_pushinteger(L, marker);
	lua_pushstring(L, action);
	lua_pushinteger(L, (int)pos[0]);
	lua_pushinteger(L, (int)pos[1]);
	lua_pushinteger(L, (int)pos[2]);
	lua_pushinteger(L, (int)tpos[0]);
	lua_pushinteger(L, (int)tpos[1]);
	lua_pushinteger(L, (int)tpos[2]);
	lua_pushinteger(L, rtype);

	int r = lua_pcall(L, 11, 0, 0);
	if (r != LUA_OK)
		fprintf(stderr, "aoi_cb error:%s\n", lua_tostring(L, -1));
}

static int lupdate(lua_State* L)
{
	if(lua_gettop(L) != 10)
	{
		lua_pushboolean(L, false);
		return 1;
	}
	struct aoi_space* space = lua_touserdata(L, 1);
	int id = lua_tointeger(L, 2);
	const char* mode = lua_tostring(L, 3);
	int rtype = lua_tointeger(L, 4);
	float pos[3] = {0.0}, tpos[3] = {0.0};
	pos[0] = lua_tonumber(L, 5);
	pos[1] = lua_tonumber(L, 6);
	pos[2] = lua_tonumber(L, 7);
	tpos[0] = lua_tonumber(L, 8);
	tpos[1] = lua_tonumber(L, 9);
	tpos[2] = lua_tonumber(L, 10);

	aoi_update(space, id, mode, rtype, pos, tpos, aoi_cb, L);
	lua_pushboolean(L, true);
	return 1;
}

static int lmessage(lua_State* L)
{
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	luaL_checktype(L ,2, LUA_TFUNCTION);
	lua_rawsetp(L, LUA_REGISTRYINDEX, aoi_cb);
	struct aoi_space* space = lua_touserdata(L, -1);
	aoi_message(space, aoi_cb, L);
	return 0;
}

int luaopen_aoi_core(lua_State* L)
{
	luaL_checkversion(L);
	luaL_Reg l[] =
	{
		{ "new", lnew },
		{ "release", lrelease },
		{ "update", lupdate },
		{ "message", lmessage },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}