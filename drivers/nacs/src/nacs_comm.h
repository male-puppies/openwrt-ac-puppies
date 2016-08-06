#ifndef _NACS_COMM_H
#define _NACS_COMM_H
#include <linux/timer.h>
#define KERNEL_VERSION(a,b,c) (a+b+c)
#define LINUX_VERSION_CODE  8
/*dpi result*/
struct dpi_proto {
	__u32 proto_id;		/*eg.crc(shopwebsite)*/
	__u32 sub_proto_id;	/*eg.crc(taobao.com)*/
	__u32 type;			/*app or url*/
};

struct dpi_flow {
	__u32 src_ip;
	__u32 dst_ip;
	unsigned char src_mac[ETH_ALEN];
	unsigned char dst_mac[ETH_ALEN];
	__u8 src_zone, dst_zone;
	__u64 src_ipgrp_bits, dst_ipgrp_bits;
};

struct nac_check_req {
	__u8 rule_type;
	struct dpi_proto proto;
	struct dpi_flow  flow;
};

enum ac_rule_sub_type {
	RULE_SUB_TYPE_SET = 0,
	RULE_SUB_TYPE_RULE = 1,
	/*new type add here*/
	RULE_SUB_TYPE_MAX
};

struct user_info {
	__u32 src_ip;
	__u32 dst_ip;
	char src_mac[ETH_ALEN];
	char dst_mac[ETH_ALEN];
};

/**check result*/
struct ac_check_result {
	int rule_type;
	int rule_sub_type;	/*rule or set*/
	union {
		struct {
			struct dpi_proto proto;
		}rule;

		struct {
			int set_type;	/*whitemac,whiteip,blackmac,blackip*/
		}set;

	}u;
	struct user_info user;
	struct timeval tv;		/*time of this event*/
	unsigned int action;	/*flags of target*/
};

int do_ac_table(	
	const struct net_device *in,
	const struct net_device *out,
	struct sk_buff *skb);

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

#endif