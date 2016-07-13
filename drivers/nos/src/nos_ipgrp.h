/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Thu, 16 Jun 2016 10:32:40 +0800
 */
#ifndef _NOS_IPGRP_H_
#define _NOS_IPGRP_H_
#include <linux/ctype.h>
#include <asm/types.h>
#include <linux/netdevice.h>
#include <linux/kernel.h>
#include <ntrack_comm.h>

extern uint16_t g_ipgrp_conf_magic;

struct ip_grp_t {
	unsigned int id;
	unsigned int ipset_id;
	struct ip_set *ipset_set;
};

struct ipgrp_conf {
#define MAX_IPGRP 64
	unsigned int num;
	struct ip_grp_t ipgrp[MAX_IPGRP];
};

int nos_ipgrp_init(void);
void nos_ipgrp_exit(void);

uint64_t nos_ipgrp_match_src(const struct net_device *in, const struct net_device *out, struct sk_buff *skb);
uint64_t nos_ipgrp_match_dst(const struct net_device *in, const struct net_device *out, struct sk_buff *skb);

#endif /* _NOS_IPGRP_H_ */
