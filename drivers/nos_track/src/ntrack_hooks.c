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

#define DRV_VERSION	"0.1.1"
#define DRV_DESC	"content track system driver"

#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
static unsigned int ntrack_hook_fn(void *priv, 
		struct sk_buff *skb,
		const struct nf_hook_state *state)
#else
static unsigned int ntrack_hook_fn(const struct nf_hook_ops *ops, 
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
	flow_info_t *fi;
	user_info_t *ui;
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

	if(!nt_flow_track(fi)) {
		return NF_ACCEPT;
	}

	iph = ip_hdr(skb);
	if(iph) {
		nt_msghdr_t hdr;
		pkt_cap_t pcap;

		/* id & magic -> for userspace to find the kernel ui node. */
		pcap.id = fi->id;
		pcap.magic = fi->magic;
		memcpy(pcap->data, (uint8_t*)iph, dlen);

		/* xmit message to userspace. */
		nt_msghdr_init(&hdr, en_MSG_PCAP, sizeof(pcap));
		if(nt_msg_enqueue(&hdr, &pcap, 0)) {
			nt_debug("skb capture failed.\n");
		}
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
		.hook = ntrack_hook_fn,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_FORWARD,
		.priority = NF_IP_PRI_LAST,
	}
};

void *ct_klog_fd = NULL;
static int __init ct_modules_init(void)
{
	int ret = 0;

	ct_klog_fd = klog_init("ntrack", 0x0e, 0);
	if(!ct_klog_fd) {
		return -ENOMEM;
	}

	nt_info("init nf hooks.\n");
	ret = nf_register_hooks(ntrack_nf_hook_ops, ARRAY_SIZE(ntrack_nf_hook_ops));
	if (ret) {
		goto __err;
	}

	return 0;
__err:
	if(ct_klog_fd) {
		klog_fini(ct_klog_fd);
	}
	return ret;
}

static void __exit ct_modules_exit(void)
{
	nt_info("module cleanup.\n");

	nf_unregister_hooks(ntrack_nf_hook_ops, ARRAY_SIZE(ntrack_nf_hook_ops));
	klog_fini(ct_klog_fd);

	synchronize_rcu();
	return;
}

module_init(ct_modules_init);
module_exit(ct_modules_exit);

MODULE_DESCRIPTION(DRV_DESC);
MODULE_VERSION(DRV_VERSION);
MODULE_AUTHOR("ppp <RRR@gmail.com>");
MODULE_LICENSE("GPL");