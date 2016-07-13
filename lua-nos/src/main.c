/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Mon, 11 Jul 2016 14:35:31 +0800
 */
#define _GNU_SOURCE
#define __DEBUG

#include <sched.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <fcntl.h>
#include <errno.h>

#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/socket.h>

#include <ntrack_rbf.h>
#include <ntrack_log.h>
#include <ntrack_msg.h>
#include <ntrack_auth.h>

#include "lua.h"
#include "lauxlib.h" 
#include "dump.c"

#if LUA_VERSION_NUM < 502 
# define luaL_newlib(L,l) (lua_newtable(L), luaL_register(L,NULL,l))
#endif 

#if LUA_VERSION_NUM > 501
#define lua_strlen lua_rawlen
#define luaL_typerror(L,ndx,str) luaL_error(L,"bad argument %d (%s expected, got nil)",ndx,str)
#define luaL_register(L,name,reg) lua_newtable(L);luaL_setfuncs(L,reg,0)
#define luaL_openlib(L,name,reg,nup) luaL_setfuncs(L,reg,nup)
#if LUA_VERSION_NUM > 502
#define luaL_checkint(L,n)  ((int)luaL_checkinteger(L, (n)))
#endif
#endif

static ntrack_t ntrack;

static inline void check_uid_magic(lua_State *L, uint32_t *uid, uint32_t *magic) {
	*uid = luaL_checkint(L, 1);
	*magic = luaL_checkint(L, 2);
}

static inline int get_user(lua_State *L, user_info_t **ui) {
	uint32_t uid, magic;
	
	check_uid_magic(L, &uid, &magic);
	*ui = nt_get_user_by_id(&ntrack, uid, magic);
	if(!(*ui)) {
		char buff[32] = {0};
		snprintf(buff, sizeof(buff), "not find user %u-%u", uid, magic);
		lua_pushnil(L);
		lua_pushstring(L, buff);
		return 2;
	}
	
	return 0;
}

static int user_get_rule_id(lua_State *L) {
	user_info_t *ui;
	int r = get_user(L, &ui);
	if (r)
		return r;
		
	lua_pushinteger(L, ui->hdr.rule_idx[0]);
	return 1;
}

static int user_get_status(lua_State *L) {
	user_info_t *ui;
	int r = get_user(L, &ui);
	if (r) 
		return r;
		
	lua_pushinteger(L, ui->hdr.status);
	return 1;
}

static int user_set_status(lua_State *L) {
	user_info_t *ui;
	int r = get_user(L, &ui);
	if (r) 
		return r;
	
	ui->hdr.status = luaL_checkint(L, 3);
	lua_pushboolean(L, 1);
	return 1;
}

static int user_set_gid_ucrc(lua_State *L) {
	user_info_t *ui;
	int r = get_user(L, &ui);
	if (r) 
		return r;
	
	uint32_t gid, ucrc;
	gid = luaL_checkint(L, 3);
	ucrc = luaL_checkint(L, 4);
	
	ui->hdr.u_grp_id = gid;
	ui->hdr.u_usr_crc = ucrc;
	
	lua_pushboolean(L, 1);
	return 1;
}

static int user_get_ip_mac(lua_State *L) {
	user_info_t *ui;
	int r = get_user(L, &ui);
	if (r) 
		return r;
	
	char buff[32] = {0};
	snprintf(buff, sizeof(buff), "%u.%u.%u.%u", NIPQUAD(ui->ip)); 
	lua_pushstring(L, buff);
	snprintf(buff, sizeof(buff), "%02x:%02x:%02x:%02x:%02x:%02x", FMT_MAC(ui->hdr.macaddr));
	lua_pushstring(L, buff);
	return 2;
}

static luaL_Reg reg[] = {
	{ "user_get_rule_id", 		user_get_rule_id },
	{ "user_get_status", 		user_get_status },
	{ "user_set_status", 		user_set_status },
	{ "user_set_gid_ucrc", 		user_set_gid_ucrc },
	{ "user_get_ip_mac", 		user_get_ip_mac },
	{ NULL, NULL }
};

LUALIB_API int luaopen_luanos(lua_State *L) {
	int r = nt_base_init(&ntrack);	
	if (r) {
		fprintf(stderr, "%s %d luaopen_luanos fail\n", __FILE__, __LINE__);
		exit(1);
	}
	luaL_newlib(L, reg);
	return 1;
}
