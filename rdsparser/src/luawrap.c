#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <assert.h>

#include "lua.h"
#include "lauxlib.h" 
#include "rdsparser.h"
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


#define MODULE_RDS_PARSER 	"rdsparser"
#define META_RDS_PARSER 	"meta_rds_parser"

struct rds_parser {
	rdsst *rds;
};

static int l_rds_encode(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	
	size_t count = lua_objlen(L, 1); 	//lua_rawlen(L, 1);
	if (count == 0) {
		luaL_error(L, "empty table");
	}
	
	const char *s;
	int idx = 0, len;
	rds_str *arr = (rds_str *)malloc(sizeof(rds_str) * count); 	assert(arr);
	
	lua_pushnil(L);
	while (lua_next(L, -2)) {
		if (!lua_isstring(L, -1)) {
			free(arr);
			luaL_error(L, "param %d is not string", idx);
		}
		size_t tlen;
		arr[idx].p = (char *)lua_tolstring(L, -1, &tlen);
		arr[idx].len = tlen;
		lua_pop(L, 1);
		idx++;
	}
	
	char *nstr = rds_encode(arr, count, &len);	
	free(arr);
	
	if (!nstr) {
		lua_pushnil(L);
		lua_pushstring(L, "rds_encode fail");
		return 2;
	}
	
	lua_pushlstring(L, nstr, len);
	free(nstr);
	return 1;
}

static int l_new(lua_State *L) { 
	struct rds_parser *ins = (struct rds_parser *)lua_newuserdata(L, sizeof(struct rds_parser));
	luaL_getmetatable(L, META_RDS_PARSER);
	lua_setmetatable(L, -2);
	ins->rds = rds_new(); 	assert(ins->rds);
	return 1;
}

static int l_gc(lua_State *L) { 
	struct rds_parser *ins = (struct rds_parser *)luaL_checkudata(L, 1, META_RDS_PARSER);
	if (ins->rds) {
		rds_free(ins->rds);
		ins->rds = NULL;
	}
	return 0;
}

static int l_empty(lua_State *L) { 
	struct rds_parser *ins = (struct rds_parser *)luaL_checkudata(L, 1, META_RDS_PARSER);
	lua_pushboolean(L, rds_empty(ins->rds));
	return 1;
}

static int l_decode(lua_State *L) { 
	struct rds_parser *ins = (struct rds_parser *)luaL_checkudata(L, 1, META_RDS_PARSER);
	
	size_t len;
	int idx, ret, i;
	const char *s = luaL_checklstring(L, 2, &len); 	assert(s);
	
	lua_newtable(L);  
	for (idx = 1; ; idx++) {
		rds_result rds_res;
		ret = rds_decode(ins->rds, s, len, &rds_res);
		s = NULL;
		
		if (ret < 0) {
			lua_pop(L, 1);
			lua_pushnil(L);
			lua_pushstring(L, "rds_decode fail");
			return 2;
		}
		
		if (ret > 0) {
			return 1;
		}
		
		lua_newtable(L);
		for (i = 0; i < rds_res.res_count; i++) {
			lua_pushlstring(L, rds_res.res_arr[i].p, rds_res.res_arr[i].len); 
			lua_rawseti(L, -2, i + 1); 	
		}
		rds_result_free(&rds_res);
		lua_rawseti(L, -2, idx); 	
	}
	
	return 1;
}

static int l_hex(lua_State *L) { 
	size_t len;
	unsigned const char *s;
	
	s = luaL_checklstring(L, 1, &len);
	
	int i;
	unsigned int hash = 1315423911;
	for (i = 0; i < len; i++) {
		hash ^= ((hash << 5)  +  s[i] + (hash >> 2));
	}
	
	char buff[16] = {0};
	snprintf(buff, sizeof(buff), "%08x", hash);
	lua_pushstring(L, buff);
	return 1;
}

static luaL_Reg reg[] = {
	{ "encode", 		l_rds_encode },
	{ "decode_new", 	l_new },
	{ "hex", 			l_hex },
	{ NULL, NULL }
};

static luaL_Reg fns[] = {  
	{ "__gc", 			l_gc },  
	{ "decode_free", 	l_gc },  
	{ "decode", 		l_decode },  
	{ "empty", 			l_empty },  
	{ NULL, NULL }
};

static void create_metatable(lua_State *L, luaL_Reg *reg, const char *mt_name) {
	luaL_newmetatable(L, mt_name);
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");
	luaL_openlib(L, NULL, reg, 0); 	//luaL_setfuncs(L, reg, 0);
}

LUALIB_API int luaopen_rdsparser(lua_State *L) {
	create_metatable(L, fns, META_RDS_PARSER);
	luaL_newlib(L, reg);
	return 1;
}


