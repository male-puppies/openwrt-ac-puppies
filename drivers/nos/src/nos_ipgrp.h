/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Thu, 16 Jun 2016 10:32:40 +0800
 */
#ifndef _NOS_IPGRP_H_
#define _NOS_IPGRP_H_
#include <linux/ctype.h>
#include <asm/types.h>

struct ip_grp_t {
	int id;
	int ipset_id;
#define MAX_IPSET_NAME 64
	char ipset_name[MAX_IPSET_NAME];
};

struct ipgrp_conf {
#define MAX_IPGRP 64
	int num;
	struct ip_grp_t ipgrp[MAX_IPGRP];
};

int nos_ipgrp_init(void);
void nos_ipgrp_exit(void);

#endif /* _NOS_IPGRP_H_ */
