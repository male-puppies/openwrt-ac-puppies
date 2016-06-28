/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Wed, 15 Jun 2016 11:14:08 +0800
 */
#include <linux/ctype.h>
#include <linux/device.h>
#include <linux/if_ether.h>
#include <linux/if_packet.h>
#include <linux/if_arp.h>
#include <linux/init.h>
#include <linux/ip.h>
#include <linux/kernel.h>
#include <linux/mm.h>
#include <linux/module.h>
#include <linux/netdevice.h>
#include <linux/netfilter.h>
#include <linux/skbuff.h>
#include <linux/string.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <linux/version.h>
#include <net/netfilter/nf_conntrack.h>
#include <linux/nos_track.h>
#include <ntrack_comm.h>
#include "nos.h"
#include "nos_log.h"
#include "nos_auth.h"
#include "nos_zone.h"
#include "nos_ipgrp.h"
#include "nos_auth.h"
#include "ntrack_kapi.h"
#include "ntrack_msg.h"

unsigned int g_conf_magic = 1315423911;
unsigned int nos_hook_disable = 0;

#if LINUX_VERSION_CODE < KERNEL_VERSION(3, 13, 0)
static unsigned nos_pre_hook(unsigned int hooknum,
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out,
		int (*okfn)(struct sk_buff *))
{
#elif LINUX_VERSION_CODE < KERNEL_VERSION(4, 1, 0)
static unsigned int nos_pre_hook(const struct nf_hook_ops *ops,
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out,
		int (*okfn)(struct sk_buff *))
{
	unsigned int hooknum = ops->hooknum;
#elif LINUX_VERSION_CODE < KERNEL_VERSION(4, 4, 0)
static unsigned int nos_pre_hook(const struct nf_hook_ops *ops,
		struct sk_buff *skb,
		const struct nf_hook_state *state)
{
	unsigned int hooknum = state->hook;
	const struct net_device *in = state->in;
	const struct net_device *out = state->out;
#else
static unsigned int nos_pre_hook(void *priv,
		struct sk_buff *skb,
		const struct nf_hook_state *state)
{
	//unsigned int hooknum = state->hook;
	//const struct net_device *in = state->in;
	//const struct net_device *out = state->out;
#endif
	enum ip_conntrack_info ctinfo;
	struct nf_conn *ct;
	struct nos_track* nos;

	if (nos_hook_disable) {
		return NF_ACCEPT;
	}
	ct = nf_ct_get(skb, &ctinfo);
	if (!ct) {
		return NF_ACCEPT;
	}
	if (nf_ct_is_untracked(ct)) {
		return NF_ACCEPT;
	}
	if (test_bit(IPS_NOS_DROP_BIT, &ct->status)) {
		//XXX drop? redirect? reset?
		return NF_DROP;
	}
	if (test_bit(IPS_NOS_BYPASS_BIT, &ct->status)) {
		return NF_ACCEPT;
	}
	if ((nos = nf_ct_get_nos(ct)) == NULL) {
		return NF_ACCEPT;
	}

	return NF_ACCEPT;
}

#if LINUX_VERSION_CODE < KERNEL_VERSION(3, 13, 0)
static unsigned nos_fw_hook(unsigned int hooknum,
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out,
		int (*okfn)(struct sk_buff *))
{
#elif LINUX_VERSION_CODE < KERNEL_VERSION(4, 1, 0)
static unsigned int nos_fw_hook(const struct nf_hook_ops *ops,
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out,
		int (*okfn)(struct sk_buff *))
{
	unsigned int hooknum = ops->hooknum;
#elif LINUX_VERSION_CODE < KERNEL_VERSION(4, 4, 0)
static unsigned int nos_fw_hook(const struct nf_hook_ops *ops,
		struct sk_buff *skb,
		const struct nf_hook_state *state)
{
	unsigned int hooknum = state->hook;
	const struct net_device *in = state->in;
	const struct net_device *out = state->out;
#else
static unsigned int nos_fw_hook(void *priv,
		struct sk_buff *skb,
		const struct nf_hook_state *state)
{
	//unsigned int hooknum = state->hook;
	const struct net_device *in = state->in;
	const struct net_device *out = state->out;
#endif
	int ret = NF_ACCEPT;
	enum ip_conntrack_info ctinfo;
	struct nf_conn *ct;
	//struct iphdr *iph;
	struct nos_user_info *ui;
	struct nos_track* nos;

	if (nos_hook_disable) {
		return NF_ACCEPT;
	}
	ct = nf_ct_get(skb, &ctinfo);
	if (!ct) {
		return NF_ACCEPT;
	}
	if (nf_ct_is_untracked(ct)) {
		return NF_ACCEPT;
	}
	if (test_bit(IPS_NOS_BYPASS_BIT, &ct->status)) {
		return NF_ACCEPT;
	}

	if (CTINFO2DIR(ctinfo) != IP_CT_DIR_ORIGINAL) {
		return NF_ACCEPT;
	}
	if ((nos = nf_ct_get_nos(ct)) == NULL) {
		return NF_ACCEPT;
	}
	ui = nt_user(nos);

	if (ui->hdr.rule_magic != g_conf_magic) {
		//slow path
		nos_zone_match(in, ui);
		nos_ipgrp_match(in, out, skb, ui);

		nos_auth_match(in, out, skb, ui);

		ui->hdr.rule_magic = g_conf_magic;
	}

	if (ui->hdr.status == AUTH_NONE) {
		//need web auth
		int data_len;
		unsigned char *data;
		struct tcphdr *tcph;
		struct iphdr *iph = ip_hdr(skb);
		ret = NF_DROP;
		if (iph->protocol == IPPROTO_UDP) {
			struct udphdr *udph = (struct udphdr *)((void *)iph + iph->ihl*4);
			if (udph->dest == __constant_htons(53) ||
					udph->dest == __constant_htons(67)) {
				set_bit(IPS_NOS_BYPASS_BIT, &ct->status);
				ret = NF_ACCEPT;
				goto out;
			}
		}
		if (iph->protocol != IPPROTO_TCP) {
			set_bit(IPS_NOS_DROP_BIT, &ct->status);
			goto out;
		}
		//FIXME skb_make_writable
		tcph = (struct tcphdr *)((void *)iph + iph->ihl * 4);
		data = skb->data + (iph->ihl << 2) + (tcph->doff << 2);
		data_len = ntohs(iph->tot_len) - ((iph->ihl << 2) + (tcph->doff << 2));
		if ((data_len > 4 && strncasecmp(data, "GET ", 4) == 0) ||
				(data_len > 5 && strncasecmp(data, "POST ", 5) == 0)) {
			nos_auth_http_302(in, skb, ui);
			set_bit(IPS_NOS_DROP_BIT, &ct->status);
			ret = NF_DROP;
		} else if (data_len > 0) {
			set_bit(IPS_NOS_DROP_BIT, &ct->status);
			ret = NF_DROP;
		} else if (tcph->ack && !tcph->syn) {
			nos_auth_convert_tcprst(skb);
			ret = NF_ACCEPT;
		}
	} else if (ui->hdr.status == AUTH_OK) {
		if (time_after(jiffies, ui->hdr.time_stamp + 30 * HZ)) {
			nt_msghdr_t hdr;
			auth_msg_t auth;

			ui->hdr.time_stamp = jiffies;
			auth.id = ui->id;
			auth.magic = ui->magic;

			nt_msghdr_init(&hdr, en_MSG_AUTH, sizeof(auth));
			if (nt_msg_enqueue(&hdr, &auth, 0)) {
				nt_debug("skb cap failed.\n");
			}
		}
	}

	//get and match auth rule
	//auth action

out:
	return ret;
}

#if LINUX_VERSION_CODE < KERNEL_VERSION(3, 13, 0)
static unsigned nos_post_hook(unsigned int hooknum,
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out,
		int (*okfn)(struct sk_buff *))
{
#elif LINUX_VERSION_CODE < KERNEL_VERSION(4, 1, 0)
static unsigned int nos_post_hook(const struct nf_hook_ops *ops,
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out,
		int (*okfn)(struct sk_buff *))
{
	unsigned int hooknum = ops->hooknum;
#elif LINUX_VERSION_CODE < KERNEL_VERSION(4, 4, 0)
static unsigned int nos_post_hook(const struct nf_hook_ops *ops,
		struct sk_buff *skb,
		const struct nf_hook_state *state)
{
	unsigned int hooknum = state->hook;
	const struct net_device *in = state->in;
	const struct net_device *out = state->out;
#else
static unsigned int nos_post_hook(void *priv,
		struct sk_buff *skb,
		const struct nf_hook_state *state)
{
	//unsigned int hooknum = state->hook;
	//const struct net_device *in = state->in;
	//const struct net_device *out = state->out;
#endif
	return NF_ACCEPT;
}

static struct nf_hook_ops nos_hooks[] = {
	{
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 4, 0)
		.owner = THIS_MODULE,
#endif
		.hook = nos_pre_hook,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_PRE_ROUTING,
		.priority = NF_IP_PRI_CONNTRACK + 1,
	},
	{
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 4, 0)
		.owner = THIS_MODULE,
#endif
		.hook = nos_fw_hook,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_FORWARD,
		.priority = NF_IP_PRI_LAST,
	},
	{
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 4, 0)
		.owner = THIS_MODULE,
#endif
		.hook = nos_post_hook,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_POST_ROUTING,
		.priority = NF_IP_PRI_LAST,
	},
};

void *ntrack_klog_fd = NULL;

static int __init nos_init(void)
{
	int ret = 0;

	ntrack_klog_fd = klog_init("ntrack", 0x0e, 0);
	if(!ntrack_klog_fd) {
		return -ENOMEM;
	}

	ret = nt_msg_init();
	if (ret != 0)
		goto nt_msg_init_failed;
	ret = nos_zone_init();
	if (ret != 0)
		goto nos_zone_init_failed;
	ret = nos_ipgrp_init();
	if (ret != 0)
		goto nos_ipgrp_init_failed;
	ret = nos_auth_init();
	if (ret != 0)
		goto nos_auth_init_failed;

	need_conntrack();
	ret = nf_register_hooks(nos_hooks, ARRAY_SIZE(nos_hooks));
	if (ret != 0)
		goto nf_register_hooks_failed;

	return 0;

nf_register_hooks_failed:
	nos_auth_exit();
nos_auth_init_failed:
	nos_ipgrp_exit();
nos_ipgrp_init_failed:
	nos_zone_exit();
nos_zone_init_failed:
	nt_msg_cleanup();
nt_msg_init_failed:
	klog_fini(ntrack_klog_fd);

	return ret;
}

static void __exit nos_exit(void)
{
	nf_unregister_hooks(nos_hooks, ARRAY_SIZE(nos_hooks));
	nos_auth_exit();
	nos_ipgrp_exit();
	nos_zone_exit();
	nt_msg_cleanup();
	klog_fini(ntrack_klog_fd);
}

module_init(nos_init);
module_exit(nos_exit);

MODULE_AUTHOR("Q2hlbiBNaW5xaWFuZyA8cHRwdDUyQGdtYWlsLmNvbT4=");
MODULE_VERSION(NOS_VERSION);
MODULE_DESCRIPTION("nos for ac");
MODULE_LICENSE("GPL");
