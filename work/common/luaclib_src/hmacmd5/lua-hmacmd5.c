#include <lua.h>
#include <lauxlib.h>
#include "hmac-md5.h"
#include "cmd5.h"

int lhmac_md5(lua_State *L)
{
    size_t keylen;
    char *key = (char *)lua_tolstring(L, 1, &keylen);
    size_t srclen;
    char *src = (char *)lua_tolstring(L, 2, &srclen);
    
    char dest[16] = {0};
    hmac_md5_c(key, keylen, src, srclen, dest);
    char retBuff[32] = {0};
    sprintf(retBuff, "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x"
            ,dest[0] & 0xff, dest[1] & 0xff, dest[2] & 0xff, dest[3] & 0xff
            ,dest[4] & 0xff, dest[5] & 0xff, dest[6] & 0xff, dest[7] & 0xff
            ,dest[8] & 0xff, dest[9] & 0xff, dest[10] & 0xff, dest[11] & 0xff
            ,dest[12] & 0xff, dest[13] & 0xff, dest[14] & 0xff, dest[15] & 0xff
    );

    lua_pushstring(L, retBuff);
    return 1;
}

int lmd5(lua_State *L)
{
    size_t srclen;
    char *src = (char *)lua_tolstring(L, 1, &srclen);
    char dest[32] = {0};
    md5((const uint8_t*)src, srclen, (uint8_t*)dest);
    char retBuff[32] = {0};
    sprintf(retBuff, "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x"
            ,dest[0] & 0xff, dest[1] & 0xff, dest[2] & 0xff, dest[3] & 0xff
            ,dest[4] & 0xff, dest[5] & 0xff, dest[6] & 0xff, dest[7] & 0xff
            ,dest[8] & 0xff, dest[9] & 0xff, dest[10] & 0xff, dest[11] & 0xff
            ,dest[12] & 0xff, dest[13] & 0xff, dest[14] & 0xff, dest[15] & 0xff
    );

    lua_pushstring(L, retBuff);
    return 1;
}

int luaopen_hmacmd5_core(lua_State* L)
{
    luaL_checkversion(L);
    luaL_Reg l[] =
        {
            {"hmac_md5", lhmac_md5},
            {"md5", lmd5},
            {NULL, NULL},
        };
    luaL_newlib(L, l);

    return 1;
}