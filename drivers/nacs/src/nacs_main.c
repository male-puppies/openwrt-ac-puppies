#include <linux/err.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/version.h>
#include <ntrack_flow.h>
#include <ntrack_nproto.h>
#include <net/netfilter/nf_conntrack.h>
#include <rule_table.h>
#include "nacs_ipc.h"
#include "nacs_table.h"
#include "nacs_debug.h"

void *nacs_klog_fd = NULL;

#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
static unsigned int nacs_hook_fn(void *priv,
		struct sk_buff *skb,
		const struct nf_hook_state *state)
#else
static unsigned int nacs_hook_fn(const struct nf_hook_ops *ops,
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out,
		int (*okfn)(struct sk_buff *))
#endif
{
#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
	 struct net_device *in = state->in, *out = state->out;
#endif

	struct nf_conn *ct;
	flow_info_t *fi;
	user_info_t *ui, *pi;
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
		NACS_DEBUG("nos untracked.\n");
		return NF_ACCEPT;
	}

	fi = nt_flow(nos);
	ui = nt_user(nos);
	pi = nt_peer(nos);
	if(!fi || !ui || !pi) {
		return NF_ACCEPT;
	}
	do_ac_table_hk(in, out, skb, fi, ui, pi);
	return NF_ACCEPT;
}

static int nacs_nproto_callback(nt_packet_t *pkt, uint32_t proto_crc)
{
	if(!pkt->in || !pkt->out || !pkt->skb || !pkt->fi || !pkt->ui || !pkt->pi)
	{
		return 1;
	}

	if(do_ac_table_cb(pkt->in, pkt->out, pkt->skb,
						pkt->fi, pkt->ui, pkt->pi, proto_crc) != -1)
	{
		if (nt_flow_droped(pkt->fi)) {
			return -1;
		}
	}

	return 0;
}


static struct nf_hook_ops nacs_nf_hook_ops[] = {
	{
#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
		.priv = NULL,
#else
		.owner = THIS_MODULE,
#endif
		.hook = nacs_hook_fn,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_FORWARD,
		.priority = NF_IP_PRI_LAST,
	}

};


static int __init nacs_init(void)
{
	nacs_klog_fd = klog_init("nacs", 0x0e, 0);
	if(!nacs_klog_fd) {
		return -ENOMEM;
	}

	if (nacs_table_init() < 0) {
		NACS_ERROR("nacs_table_init failed\n");
		goto failed;
	}

	if (nacs_ipc_init() < 0) {
		NACS_ERROR("nac_ipc_init failed\n");
		goto failed;
	}

	if (nf_register_hooks(nacs_nf_hook_ops, ARRAY_SIZE(nacs_nf_hook_ops))) {
		goto failed;
	}

	if (np_hook_register(nacs_nproto_callback) < 0) {
		goto failed;
	}

	NACS_INFO("nacs_init success\n");
	return 0;

failed:
	nacs_table_fini();
	if(nacs_klog_fd) {
		klog_fini(nacs_klog_fd);
	}
	NACS_INFO("nacs_init failed\n");
	return -1;
}


static void __exit nacs_fini(void)
{
	NACS_INFO("nacs_fini...\n");
	np_hook_unregister(nacs_nproto_callback);
	nf_unregister_hooks(nacs_nf_hook_ops, ARRAY_SIZE(nacs_nf_hook_ops));
	nacs_ipc_fini();
	nacs_table_fini();
	klog_fini(nacs_klog_fd);
	return;
}

module_init(nacs_init);
module_exit(nacs_fini);

MODULE_DESCRIPTION("nacs");
MODULE_VERSION("1.0");
MODULE_AUTHOR("Ivan <itgb1989@gmail.com>");
MODULE_LICENSE("GPL v2");
