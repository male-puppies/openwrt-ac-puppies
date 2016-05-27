#include <linux/module.h>
#include <linux/netfilter.h>
#include <linux/ip.h>
#include <linux/version.h>

#include <linux/netfilter/xt_set.h>

#include <net/ip.h>
#include <net/netfilter/nf_conntrack.h>

#include <linux/nos_track.h>
#include <ntrack_log.h>
#include <ntrack_msg.h>
#include <ntrack_auth.h>
#include <ntrack_comm.h>

#include "ntrack_kapi.h"

#define DRV_VERSION	"0.1.1"
#define DRV_DESC	"ntrack system driver"

int l3filter(struct iphdr* iph)
{
	//TCP, UDP, ICMP, supported.
	if ((iph->protocol != IPPROTO_TCP) 
		&& (iph->protocol != IPPROTO_UDP) 
		&& (iph->protocol != IPPROTO_ICMP)) {
		return 1;
	}

	//loopback, lbcast filter.
	if (ipv4_is_lbcast(iph->saddr) || 
		ipv4_is_lbcast(iph->daddr) ||
			ipv4_is_loopback(iph->saddr) || 
			ipv4_is_loopback(iph->daddr) ||
			ipv4_is_multicast(iph->saddr) ||
			ipv4_is_multicast(iph->daddr) || 
			ipv4_is_zeronet(iph->saddr) ||
			ipv4_is_zeronet(iph->daddr)){
		return 1;
	}

	return 0;
}

#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
static unsigned int ntrack_hook_fw(void *priv, 
		struct sk_buff *skb,
		const struct nf_hook_state *state)
#else
static unsigned int ntrack_hook_fw(const struct nf_hook_ops *ops, 
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out, 
		int (*okfn)(struct sk_buff *))
#endif
{
#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
	struct net_device *in = state->in, *out = state->out;
#endif

	int ret = NF_ACCEPT;
	struct nf_conn *ct;
	struct iphdr *iph;
	struct nos_user_info *ui;
	// struct sk_buff *linear_skb = NULL, *use_skb = NULL;
	enum ip_conntrack_info ctinfo;

	// unsigned int res = NF_ACCEPT;
	struct nos_track* nos;

	ct = nf_ct_get(skb, &ctinfo);
	if (!ct) {
		// nt_debug("null ct.\n");
		return NF_ACCEPT;
	}

	if(nf_ct_is_untracked(ct)) {
		// nt_debug("--------------- untracked ct.\n");
		return NF_ACCEPT;
	}

	if((nos = nf_ct_get_nos(ct)) == NULL) {
		nt_debug("nos untracked.\n");
		return NF_ACCEPT;
	}

	iph = ip_hdr(skb);
	if (l3filter(iph)) {
		return NF_ACCEPT;
	}

	ui = nt_user(nos);
	if (user_need_redirect(ui, skb)) {
		if(auth_check_http(iph, skb)) {
			if(ntrack_redirect(ui, skb, in, out) == 0) {
				/* success redirect, drop this ori link. */
				ret = NF_DROP;
			}
		}
	}

	if (user_timeout(ui)) {
		user_update_timestamp(ui);
		/* user online message: keepalive... */
		if(nt_auth_status(ui) >= AUTH_OK) {
			nt_msghdr_t hdr;
			auth_msg_t auth;

			/* id & magic -> for userspace to find the kernel ui node. */
			auth.id = ui->id;
			auth.magic = ui->magic;

			/* xmit message to userspace. */
			nt_msghdr_init(&hdr, en_MSG_AUTH, sizeof(auth));
			if(nt_msg_enqueue(&hdr, &auth, 0)) {
				nt_debug("skb cap failed.\n");
			}
		}
	}

	/* check the l7/users firewall rules. */
	if(nt_firewall(skb, nos, in, out) == NF_DROP) {
		ret = NF_DROP;
	}

	return ret;
}

#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
static unsigned int ntrack_hook_pre(void *priv,
	struct sk_buff *skb, 
	const struct nf_hook_state *state) {

	struct net_device *in = state->in;
#else
static unsigned int ntrack_hook_pre(const struct nf_hook_ops *ops, 
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out, 
		int (*okfn)(struct sk_buff *)) {
#endif
	
	struct nf_conn *ct;
	struct nos_track *nos;
	enum ip_conntrack_info ctinfo;

	ct = nf_ct_get(skb, &ctinfo);
	if (!ct) {
		// nt_debug("null ct.\n");
		return NF_ACCEPT;
	}

	if(nf_ct_is_untracked(ct)) {
		return NF_ACCEPT;
	}

	if((nos = nf_ct_get_nos(ct)) == NULL) {
		nt_debug("nos untracked.\n");
		return NF_ACCEPT;
	}

	/* FIXME: context check kernel handle here. */
	nt_context_check(skb, nos, in);

	/* FIXME: mulit route line marker here. */
	nt_mroute_marker(skb, nos, in);

	return NF_ACCEPT;
}

#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
static unsigned int ntrack_hook_post(void *priv,
	struct sk_buff *skb, 
	const struct nf_hook_state *state) {

	struct net_device *out = state->out;
#else
static unsigned int ntrack_hook_post(const struct nf_hook_ops *ops, 
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out, 
		int (*okfn)(struct sk_buff *)) {
#endif

	struct nf_conn *ct;
	struct nos_track *nos;
	enum ip_conntrack_info ctinfo;

	ct = nf_ct_get(skb, &ctinfo);
	if (!ct) {
		// nt_debug("null ct.\n");
		return NF_ACCEPT;
	}

	if(nf_ct_is_untracked(ct)) {
		return NF_ACCEPT;
	}

	if((nos = nf_ct_get_nos(ct)) == NULL) {
		nt_debug("nos untracked.\n");
		return NF_ACCEPT;
	}

	/* statistics */
	nt_statistics(skb, nos, out);

	return NF_ACCEPT;
}

static struct nf_hook_ops ntrack_nf_hook_ops[] = {
	{
#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
		.priv = NULL,
#else
		.owner = THIS_MODULE,
#endif
		.hook = ntrack_hook_fw,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_FORWARD,
		.priority = NF_IP_PRI_LAST,
	},
	{
#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
		.priv = NULL,
#else
		.owner = THIS_MODULE,
#endif
		.hook = ntrack_hook_pre,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_PRE_ROUTING,
		.priority = NF_IP_PRI_NAT_DST + 1,
	},
	{
#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
		.priv = NULL,
#else
		.owner = THIS_MODULE,
#endif
		.hook = ntrack_hook_post,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_POST_ROUTING,
		.priority = NF_IP_PRI_NAT_SRC - 1,
	}
};

void *ntrack_klog_fd = NULL;
static int __init ntrack_modules_init(void)
{
	int ret = 0;

	ntrack_klog_fd = klog_init("ntrack", 0x0e, 0);
	if(!ntrack_klog_fd) {
		return -ENOMEM;
	}

	nt_info("init netlink conf io.\n");
	ret = ntrack_conf_init();
	if (ret) {
		goto __err;
	}

	nt_info("ntrack cap init.\n");
	ret = nt_msg_init();
	if(ret) {
		goto __err;
	}

	nt_info("init nf hooks.\n");
	ret = nf_register_hooks(ntrack_nf_hook_ops, ARRAY_SIZE(ntrack_nf_hook_ops));
	if (ret) {
		goto __err;
	}

	/* setup user identify hook */
	rcu_assign_pointer(nos_user_match_fn, ntrack_user_match);
	return 0;

__err:
	nt_msg_cleanup();
	if(ntrack_klog_fd) {
		klog_fini(ntrack_klog_fd);
	}
	ntrack_conf_exit();
	return ret;
}

static void __exit ntrack_modules_exit(void)
{
	nt_info("module cleanup.\n");

	/* cleanup user identify hook */
	rcu_assign_pointer(nos_user_match_fn, NULL);

	nf_unregister_hooks(ntrack_nf_hook_ops, ARRAY_SIZE(ntrack_nf_hook_ops));
	nt_msg_cleanup();
	ntrack_conf_exit();
	klog_fini(ntrack_klog_fd);

	synchronize_rcu();
	return;
}

module_init(ntrack_modules_init);
module_exit(ntrack_modules_exit);

MODULE_DESCRIPTION(DRV_DESC);
MODULE_VERSION(DRV_VERSION);
MODULE_AUTHOR("ppp <RRR@gmail.com>");
MODULE_LICENSE("GPL");