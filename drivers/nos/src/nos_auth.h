/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Wed, 15 Jun 2016 11:14:16 +0800
 */
#ifndef _NOS_AUTH_H_
#define _NOS_AUTH_H_
#include <linux/ctype.h>
#include <asm/types.h>

struct auth_rule_t {
	int src_zone_id;
	int src_ipgrp_id;
};



#endif /* _NOS_AUTH_H_ */
