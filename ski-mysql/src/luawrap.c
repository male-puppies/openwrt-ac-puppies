#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <assert.h>
#include <openssl/sha.h>

#include "lua.h"
#include "lauxlib.h"  
#include "dump.c"

#if LUA_VERSION_NUM < 502 
# define luaL_newlib(L,l) (lua_newtable(L), luaL_register(L,NULL,l))
#endif 

#if LUA_VERSION_NUM > 501
/*
** Lua 5.2
*/
#define lua_strlen lua_rawlen
/* luaL_typerror always used with arg at ndx == NULL */
#define luaL_typerror(L,ndx,str) luaL_error(L,"bad argument %d (%s expected, got nil)",ndx,str)
/* luaL_register used once, so below expansion is OK for this case */
#define luaL_register(L,name,reg) lua_newtable(L);luaL_setfuncs(L,reg,0)
/* luaL_openlib always used with name == NULL */
#define luaL_openlib(L,name,reg,nup) luaL_setfuncs(L,reg,nup)

#if LUA_VERSION_NUM > 502
/*
** Lua 5.3
*/
#define luaL_checkint(L,n)  ((int)luaL_checkinteger(L, (n)))
#endif
#endif

static int l_sha1(lua_State *L) {
	size_t slen;
	const char *s = luaL_checklstring(L, 1, &slen);	assert(slen > 0);
	unsigned char stage1[20];
	SHA1(s, slen, stage1);
	lua_pushlstring(L, stage1, sizeof(stage1));
	return 1;
}

static luaL_Reg reg[] = {
	{ "sha1", 			l_sha1 },
	{ NULL, NULL }
};


LUALIB_API int luaopen_luasha1(lua_State *L) {
	luaL_newlib(L, reg);
	return 1;
}


