#include <linux/module.h>
#include <linux/netfilter.h>
#include <linux/ip.h>
#include <linux/version.h>

#include <net/ip.h>
#include <net/netfilter/nf_conntrack.h>

#include <linux/nos_track.h>
#include <ntrack_log.h>
#include <ntrack_comm.h>
#include <ntrack_nproto.h>

#define DRV_VERSION	"0.1.1"
#define DRV_DESC	"ntrack layer 7 firewall system driver"

#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
static unsigned int nfw_hook_fn(void *priv, 
		struct sk_buff *skb,
		const struct nf_hook_state *state)
#else
static unsigned int nfw_hook_fn(const struct nf_hook_ops *ops, 
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out, 
		int (*okfn)(struct sk_buff *))
#endif
{
#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
	// struct net_device *in = state->in, *out = state->out;
#endif

	int ret = NF_ACCEPT;
	struct nf_conn *ct;
	flow_info_t *fi;
	user_info_t *ui;
	// struct iphdr *iph;
	// struct sk_buff *linear_skb = NULL, *use_skb = NULL;
	enum ip_conntrack_info ctinfo;
	struct nos_track* nos;

	ct = nf_ct_get(skb, &ctinfo);
	if (!ct) {
		return NF_ACCEPT;
	}

	if(nf_ct_is_untracked(ct)) {
		return NF_ACCEPT;
	}

	if((nos = nf_ct_get_nos(ct)) == NULL) {
		nt_debug("nos untracked.\n");
		return NF_ACCEPT;
	}

	fi = nt_flow(nos);
	ui = nt_user(nos);
	if(!fi || !ui) {
		return NF_ACCEPT;
	}
	
	/* TODO: lookup flow drop flags here */
	if((ret=nt_flow_droped(fi)) !=0 ) {
		/* debug */
		fw_debug(FMT_FLOW_STR " droped by: %x\n", FMT_FLOW(fi), ret);
		ret = NF_DROP;
	}

	return ret;
}

static struct nf_hook_ops ntrack_nf_hook_ops[] = {
	{
#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
		.priv = NULL,
#else
		.owner = THIS_MODULE,
#endif
		.hook = nfw_hook_fn,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_FORWARD,
		.priority = NF_IP_PRI_LAST,
	}
};

static int fw_nproto_hook(flow_info_t *fi, uint16_t proto_new)
{
	/*TODO: check the config rule's, markup fi->flags.*/
	if(/*fw_check_rule(fi, proto_new)*/0) {
		nt_flow_drop_set(fi, FG_FLOW_DROP_L7_FW);
	}
	return 0;
}

void *nfw_klog_fd = NULL;
static int __init ct_modules_init(void)
{
	int ret = 0;

	nfw_klog_fd = klog_init("nfw", 0x0e, 0);
	if(!nfw_klog_fd) {
		return -ENOMEM;
	}

	fw_info("init nf hooks.\n");
	ret = nf_register_hooks(ntrack_nf_hook_ops, ARRAY_SIZE(ntrack_nf_hook_ops));
	if (ret) {
		goto __err;
	}

	np_hook_register(fw_nproto_hook);
	return 0;

__err:
	if(nfw_klog_fd) {
		klog_fini(nfw_klog_fd);
	}
	return ret;
}

static void __exit ct_modules_exit(void)
{
	fw_info("module cleanup.\n");

	np_hook_unregister(fw_nproto_hook);
	nf_unregister_hooks(ntrack_nf_hook_ops, ARRAY_SIZE(ntrack_nf_hook_ops));
	klog_fini(nfw_klog_fd);

	synchronize_rcu();
	return;
}

module_init(ct_modules_init);
module_exit(ct_modules_exit);

MODULE_DESCRIPTION(DRV_DESC);
MODULE_VERSION(DRV_VERSION);
MODULE_AUTHOR("ppp <RRR@gmail.com>");
MODULE_LICENSE("GPL");