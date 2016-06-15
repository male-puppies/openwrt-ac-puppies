#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h> 

#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"

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

#include "libencrypt.h"  
//#include "dump.c"

static int l_encode(lua_State *L) {
	size_t len;
	int type, ret;
	const char *s; 
	
	type = luaL_checkinteger(L, 1);
	s = luaL_checklstring(L, 2, (size_t *)&len); 						BUG_ON(!s);
	
	if (len <= 0 || len > 1024*1024*10) {
		lua_pushnil(L);
		lua_pushfstring(L, "invalid len %d", len);
		return 2;
	}
	
	switch (type) {
		case 0:
		case 1:
		{
			int out;
			char *n;
			n = encrypt_encode01(type, s, len, &out);		BUG_ON(!n);
			lua_pushlstring(L, n, out);
			free(n);
			return 1;
		}
		case 2:
		{
			int out;
			char *ns;
			ns = encrypt_encode2(type, s, len, &out);					BUG_ON(!ns); 		 
			lua_pushlstring(L, ns, out); 
			free(ns);		 
			return 1;
		}
		default:
			lua_pushnil(L);
			lua_pushfstring(L, "invalid type %d", type);
			return 2;
	}
	
	return 0;
}

static int l_decode(lua_State *L) {
	size_t slen;
	int ret, htype, hlen;
	const char *s;
	encrypt_header_t h;
	
	s = luaL_checklstring(L, 1, (size_t *)&slen);
	memcpy(&h, s, sizeof(h));
	h = ntohl(h);
	
	encrypt_get_header(&h, &htype, &hlen);
	
	if (slen <= 4 || hlen != slen) {
		lua_pushnil(L);
		lua_pushfstring(L, "invalid len %d %d", slen, hlen);
		return 2;
	}
	
	switch (htype) {
		case 0:
		case 1:
		{
			int out;
			char *n;
			
			n = encrypt_decode01(htype, s, slen, &out); 	BUG_ON(!n);
			
			lua_pushlstring(L, n, out);
			free(n);		
			return 1;
		}
		case 2:
		{
			int out;
			char *n;
			n = encrypt_decode2(htype, s, slen, &out);
			if (!n) {
				lua_pushnil(L);
				lua_pushstring(L, "decode fail");
				return 2;
			}
			
			lua_pushlstring(L, n, out);
			free(n);		
			return 1;
		}
		default:
			lua_pushnil(L);
			lua_pushfstring(L, "invalid type %d", htype);
			return 2;
	}
	
	return 0;
}

static int l_header(lua_State *L) {
	size_t len;
	int hlen, htype;
	const char *s;
	encrypt_header_t h;
	
	s = luaL_checklstring(L, 1, (size_t *)&len);
	if (len < 4) {
		lua_pushnil(L);
		lua_pushfstring(L, "too short %d", len);
		return 2;
	}
	
	memcpy(&h, s, sizeof(h));
	h = ntohl(h);
	
	encrypt_get_header(&h, &htype, &hlen);
	
	lua_pushinteger(L, hlen);
	lua_pushinteger(L, htype);
	return 2;
}

static luaL_Reg reg[] = {
	{ "encode", l_encode }, 
	{ "decode", l_decode }, 
	{ "header", l_header }, 
	{ NULL, NULL }
};

static void create_metatable(lua_State *L, luaL_Reg *reg, const char *mt_name) {
	luaL_newmetatable(L, mt_name);
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");
	luaL_register(L, NULL, reg);
}

#ifdef USE_LUA53
LUALIB_API int luaopen_encrypt53(lua_State *L) {
#else 
LUALIB_API int luaopen_encrypt(lua_State *L) {
#endif 	
	encrypt_init();
	luaL_newlib(L, reg); 	
	return 1;
}
