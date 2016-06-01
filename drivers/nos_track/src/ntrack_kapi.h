#pragma once

#include <linux/module.h>
#include <linux/netfilter.h>
#include <linux/ip.h>
#include <linux/version.h>
#include <linux/netfilter/xt_set.h>

#include <net/ip.h>
#include <net/netfilter/nf_conntrack.h>

#include <linux/nos_track.h>
#include <ntrack_log.h>

/* conf from userspace, json format. */
int ntrack_conf_init(void);
void ntrack_conf_exit(void);

/* match the user net/hash:ip */
int ntrack_user_match(user_info_t *ui, struct sk_buff *skb);

/* 
* context check interface, 
*	for simple proto such as: 
* 	HTTP, HTTPS, FTP, SMTP, POP3, ...
* 
*/
int nt_context_check(struct sk_buff *skb, 
	struct nos_track *nos, 
	struct net_device *indev);

/* 
* mulit wan route marker.
*/
int nt_mroute_marker(struct sk_buff *skb, 
	struct nos_track *nos, 
	struct net_device *indev);

/* 
* post routing statistics modules.
*/
int nt_statistics(struct sk_buff *skb, 
	struct nos_track *nos, 
	struct net_device *out);

/* 
* forward firewall proto.
*/
int nt_firewall(struct sk_buff *skb, 
	struct nos_track *nos, 
	struct net_device *indev,
	struct net_device *outdev);
