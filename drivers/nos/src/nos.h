/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Wed, 15 Jun 2016 11:15:13 +0800
 */
#ifndef _NOS_H_
#define _NOS_H_

#define NOS_VERSION "1.0.0"

/* @linux/netfilter/nf_conntrack_common.h
 * ct->status use bits:[31-24] for nos-ct-status
 */
#define IPS_NOS_BYPASS_BIT 30
#define IPS_NOS_BYPASS (1 << IPS_NOS_BYPASS_BIT)
#define IPS_NOS_DROP_BIT 31
#define IPS_NOS_DROP (1 << IPS_NOS_DROP_BIT)

extern unsigned int g_conf_magic;
extern unsigned int nos_hook_disable;

#endif /* _NOS_H_ */
