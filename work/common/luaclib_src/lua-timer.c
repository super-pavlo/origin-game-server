#include <stdio.h>
#include <sys/time.h>
#include <time.h>
#include <lua.h>
#include <lauxlib.h>

// 微秒
int lgetmicrosecond(lua_State *L)
{
    struct timeval tv;
    gettimeofday(&tv,NULL);
    long microsecond = tv.tv_sec * 1000000 + tv.tv_usec;
    lua_pushnumber(L, microsecond);
    return 1;
}

//毫秒
static int lgetmillisecond(lua_State *L)
{
    struct timeval tv;
    gettimeofday(&tv,NULL);
    long millisecond = (tv.tv_sec * 1000000 + tv.tv_usec) / 1000;
    lua_pushnumber(L, millisecond);
    return 1;
}

int luaopen_timer_core(lua_State* L)
{
    luaL_checkversion(L);
    luaL_Reg l[] =
        {
            {"getmicrosecond", lgetmicrosecond},
            {"getmillisecond", lgetmillisecond},
            {NULL, NULL},
        };
    luaL_newlib(L, l);

    return 1;
}