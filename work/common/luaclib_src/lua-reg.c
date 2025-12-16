#include <sys/types.h>
#include <regex.h>
#include <lua.h>
#include <lauxlib.h>
#include <stdbool.h>

int lmatch(lua_State *L)
{
    regex_t reg;
    char *regstring = (char *)lua_tolstring(L, 1, NULL);
    char *pattern = (char *)lua_tolstring(L, 2, NULL);

    // 编译正则
    int ret = regcomp(&reg, pattern, REG_EXTENDED | REG_NOSUB);
    if(ret != 0)
    {
        char ebuf[1024] = {0};
        regerror(ret, &reg, ebuf, sizeof(ebuf));
        lua_pushboolean(L, false);
        lua_pushstring(L, ebuf);
        return 2;
    }

    // 匹配正则
    regmatch_t pmatch[1];
    int status = regexec(&reg, regstring, 1, pmatch, 0);
    // 默认匹配成功
    bool match = true;
    // 匹配失败
    if(status == REG_NOMATCH)
        match = false;

    // 释放正则
    regfree(&reg);
    
    lua_pushboolean(L, match);
    return 1;
}

int luaopen_reg_core(lua_State* L)
{
    luaL_checkversion(L);
    luaL_Reg l[] =
        {
            {"match", lmatch},
            {NULL, NULL},
        };
    luaL_newlib(L, l);

    return 1;
}