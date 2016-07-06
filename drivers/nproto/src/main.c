#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/list.h>
#include <linux/skbuff.h>
#include <linux/version.h>

#include <asm/smp.h>

#include <net/netfilter/nf_conntrack.h>

#include <linux/nos_track.h>
#include <ntrack_comm.h>
#include <ntrack_packet.h>
#include <ntrack_nproto.h>
#include <ntrack_log.h>

extern int test_init(void);
extern void test_exit(void);
extern int nproto_init(void);
extern void nproto_cleanup(void);
extern int nproto_rules_match(nt_packet_t *pkt);

static int nproto_pkt_init(struct sk_buff *skb, struct nos_track *nt, nt_packet_t *pkt)
{
	int l4len, l7len;
	int dlen = skb->len;
	uint8_t *l4ptr = NULL, *l7ptr = NULL;
	struct iphdr *iph = ip_hdr(skb);
	nt_pkt_nproto_t *np = nt_skb_nproto(skb, pkt);

	flow_info_t *fi = nt_flow(nt);
	user_info_t *ui = nt_user(nt);
	user_info_t *pi = nt_peer(nt);

	/* check skb length > (iphdr+udp/tcp) */
	if(!(iph->version == 4 && iph->ihl >= 5)) {
		np_debug("not ip proto, or length < 20.\n");
		return -EINVAL;
	}

	if((dlen < (iph->ihl * 4)) || 
		(dlen < ntohs(iph->tot_len)) || 
		(ntohs(iph->tot_len) < (iph->ihl * 4)) || 
		((iph->frag_off & htons(0x1FFF)) != 0)) 
	{
		np_debug("frame length error: %d\n", dlen);
		return -EINVAL;
	}

	l4ptr = ((uint8_t *)iph + (iph->ihl * 4));
	l4len = ntohs(iph->tot_len) - (iph->ihl * 4);
	switch(iph->protocol) {
		case IPPROTO_TCP: {
			pkt->tcp = (const struct tcphdr*)l4ptr;
			l7len = l4len - (pkt->tcp->doff * 4);
			l7ptr = l4ptr + (pkt->tcp->doff * 4);
		} break;
		case IPPROTO_UDP: {
			pkt->udp = (const struct udphdr*)l4ptr;
			l7len = l4len - sizeof(struct udphdr);
			l7ptr = l4ptr + sizeof(struct udphdr);
		} break;
		default: {
			/* icmp ... */
			pkt->generic_l4_ptr = l4ptr;
			l7len = 0;
			l7ptr = l4ptr;
		} break;
	}

	if(l7len<=0) {
		// np_debug("no l7 payload data.\n");
		return -EINVAL;
	}

	/* data length & ptr's */
	pkt->iph = iph;
	pkt->l3_len = dlen;
	pkt->l4_proto = iph->protocol;
	pkt->l4_len = l4len;

	/* payload */
	pkt->l7_len = l7len;
	pkt->l7_ptr = l7ptr;

	/* ntrack nodes. */
	pkt->fi = fi;
	pkt->ui = ui;
	pkt->pi = pi;

	/* C->S, S->C. */
	pkt->dir = nt_flow_dir(&fi->tuple, iph);
	/* init the packet parser. */
	memset(np, 0, sizeof(nt_pkt_nproto_t));
	return 0;
}

int nt_context_chk_fn(struct sk_buff *skb, struct nos_track *nt, struct net_device *indev)
{
	int n;
	nt_packet_t pkt;
	flow_info_t *fi = nt_flow(nt);

	/* FIXME: tackoff-fixup the sock4/5/http proxy header. */
	n = nproto_pkt_init(skb, nt, &pkt);
	if(n) {
		// np_debug("packet init failed: %d\n", n);
		return n;
	}

	/* update proto as match'ed fn. */
	if(!nt_flow_nproto_fin(fi)) {
		n = nproto_rules_match(&pkt);
	}
	return n;
}

#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
static unsigned int nproto_hook_fn(void *priv,
	struct sk_buff *skb, 
	const struct nf_hook_state *state) {

	struct net_device *in = state->in;
#else
static unsigned int nproto_hook_fn(const struct nf_hook_ops *ops, 
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
		// np_debug("null ct.\n");
		return NF_ACCEPT;
	}

	if(nf_ct_is_untracked(ct)) {
		return NF_ACCEPT;
	}

	if((nos = nf_ct_get_nos(ct)) == NULL) {
		np_debug("nos untracked.\n");
		return NF_ACCEPT;
	}

	/* FIXME: context check kernel handle here. */
	nt_context_chk_fn(skb, nos, in);
	return NF_ACCEPT;
}

static struct nf_hook_ops nproto_nf_hook_ops[] = {
	{
#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
		.priv = NULL,
#else
		.owner = THIS_MODULE,
#endif
		.hook = nproto_hook_fn,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_FORWARD,
		.priority = 0,
	},
};

void *nproto_klog_fd = NULL;
static int __init nproto_module_init(void)
{
	int r;

	nproto_klog_fd = klog_init("nproto", 0x0e, 0);
	if(!nproto_klog_fd) {
		printk("klog init failed.\n");
		return -ENOMEM;
	}
	np_info("klog init ok.\n");

	r = nproto_init();
	if(r) {
		np_error("nproto rules init failed.\n");
		goto __error;
	}

	r = test_init();
	if(r) {
		np_error("test init failed.\n");
		goto __error;
	}

	r = nf_register_hooks(nproto_nf_hook_ops, ARRAY_SIZE(nproto_nf_hook_ops));
	if (r) {
		np_error("nf hook register failed.\n");
		goto __error;
	}

	// rcu_assign_pointer(nt_cck_fn, nt_context_chk_fn);
	return 0;

__error:
	test_exit();
	nproto_cleanup();
	if(nproto_klog_fd)
		klog_fini(nproto_klog_fd);
	return r;
}

static void __exit nproto_module_exit(void)
{
	nf_unregister_hooks(nproto_nf_hook_ops, ARRAY_SIZE(nproto_nf_hook_ops));
	// rcu_assign_pointer(nt_cck_fn, NULL);

	test_exit();
	nproto_cleanup();
	if(nproto_klog_fd)
		klog_fini(nproto_klog_fd);
}

module_init(nproto_module_init);
module_exit(nproto_module_exit);

MODULE_DESCRIPTION(DRV_DESC);
MODULE_VERSION(DRV_VERSION);
MODULE_AUTHOR("xxx <ooo@gmail.com>");
MODULE_LICENSE("GPL");