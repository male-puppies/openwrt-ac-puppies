/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Wed, 15 Jun 2016 11:15:13 +0800
 */
#ifndef _NOS_H_
#define _NOS_H_
#include <linux/netdevice.h>
#include <linux/kernel.h>
#include <linux/netfilter/ipset/ip_set.h>
#include <linux/netfilter/x_tables.h>
#include <linux/netfilter/xt_set.h>

#define NOS_VERSION "1.0.0"

/* @linux/netfilter/nf_conntrack_common.h
 * ct->status use bits:[31-24] for nos-ct-status
 */
#define IPS_NOS_BYPASS_BIT 30
#define IPS_NOS_BYPASS (1 << IPS_NOS_BYPASS_BIT)
#define IPS_NOS_DROP_BIT 31
#define IPS_NOS_DROP (1 << IPS_NOS_DROP_BIT)

extern unsigned int nos_hook_disable;

static inline int ip_set_test_src_ip(const struct net_device *in, const struct net_device *out, struct sk_buff *skb, ip_set_id_t id)
{
	int ret = 0;
	struct ip_set_adt_opt opt;
	struct xt_action_param par;
	struct net *net = &init_net;
	if (in)
		net = dev_net(in);
	else if (out)
		net = dev_net(out);

	memset(&opt, 0, sizeof(opt));
	opt.family = NFPROTO_IPV4;
	opt.dim = IPSET_DIM_ONE;
	opt.flags = IPSET_DIM_ONE_SRC;
	opt.cmdflags = 0;
	opt.ext.timeout = UINT_MAX;

	par.in = in;
	par.out = out;
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 4, 0)
	par.net = net;
#endif

	ret = ip_set_test(id, skb, &par, &opt);

	return ret;
}

static inline int ip_set_test_dst_ip(const struct net_device *in, const struct net_device *out, struct sk_buff *skb, ip_set_id_t id)
{
	int ret = 0;
	struct ip_set_adt_opt opt;
	struct xt_action_param par;
	struct net *net = &init_net;
	if (in)
		net = dev_net(in);
	else if (out)
		net = dev_net(out);

	memset(&opt, 0, sizeof(opt));
	opt.family = NFPROTO_IPV4;
	opt.dim = IPSET_DIM_ONE;
	opt.flags = 0;
	opt.cmdflags = 0;
	opt.ext.timeout = UINT_MAX;

	par.in = in;
	par.out = out;
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 4, 0)
	par.net = net;
#endif

	ret = ip_set_test(id, skb, &par, &opt);

	return ret;
}

static inline int ip_set_test_src_mac(const struct net_device *in, const struct net_device *out, struct sk_buff *skb, ip_set_id_t id)
{
	int ret = 0;
	struct ip_set_adt_opt opt;
	struct xt_action_param par;
	struct net *net = &init_net;
	if (in)
		net = dev_net(in);
	else if (out)
		net = dev_net(out);

	memset(&opt, 0, sizeof(opt));
	opt.family = NFPROTO_UNSPEC;
	opt.dim = IPSET_DIM_ONE;
	opt.flags = IPSET_DIM_ONE_SRC;
	opt.cmdflags = 0;
	opt.ext.timeout = UINT_MAX;

	par.in = in;
	par.out = out;
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 4, 0)
	par.net = net;
#endif

	ret = ip_set_test(id, skb, &par, &opt);

	return ret;
}

#endif /* _NOS_H_ */
