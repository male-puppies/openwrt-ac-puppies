/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Wed, 15 Jun 2016 11:14:16 +0800
 */
#ifndef _NOS_AUTH_H_
#define _NOS_AUTH_H_
#include <linux/ctype.h>
#include <asm/types.h>

struct auth_rule_t {
	int id;
	int src_zone_id;
	int src_ipgrp_id;
	int auth_type;
};

struct auth_conf {
	int num;
#define MAX_AUTH 16
	struct auth_rule_t auth[MAX_AUTH];
};

int nos_auth_init(void);
void nos_auth_exit(void);

#endif /* _NOS_AUTH_H_ */
