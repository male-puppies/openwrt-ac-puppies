#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/list.h>
#include <linux/skbuff.h>
#include <linux/version.h>

#include <net/netfilter/nf_conntrack.h>

#include "nproto_private.h"

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
	} else {
		np_info(FMT_FLOW_STR" l7: %d\n", FMT_FLOW(fi), nt_flow_nproto(fi));
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

static np_hook_t np_hooks[NP_HOOK_MAX];
int np_hook_register(np_hook_t fn)
{
	int i = 0;
	for (; i < NP_HOOK_MAX; ++i) {
		np_hook_t hk = np_hooks[i];
		if(!hk) {
			np_hooks[i] = fn;
			break;
		} 
		if (hk == fn) {
			np_error("re-register hook fn\n");
			return -EINVAL;
		}
	}
	if(i == NP_HOOK_MAX) {
		np_error("np hook list overflow.\n");
		return -NP_HOOK_MAX;
	}
	return i;
}
int np_hook_unregister(np_hook_t fn)
{
	int i=0;

	for (; i < NP_HOOK_MAX; ++i) {
		if(np_hooks[i] && np_hooks[i] == fn) {
			int j = i;
			for(; j < NP_HOOK_MAX - 1; j++) {
				np_hooks[j] = np_hooks[j+1];
				if(!np_hooks[j]) {
					break;
				}
			}
			break;
		}
	}
	if(i == NP_HOOK_MAX) {
		np_error("np hook %p not found\n", fn);
		return -EINVAL;
	}

	return 0;
}
EXPORT_SYMBOL(np_hook_register);
EXPORT_SYMBOL(np_hook_unregister);

void nproto_update(nt_packet_t *pkt, np_rule_t *rule)
{
	int i;
	flow_info_t *fi = pkt->fi;
	uint16_t proto_new = rule->ID;

	NP_ASSERT(fi != NULL);

	if(fi->hdr.proto != proto_new) {
		for (i = 0; i < NP_HOOK_MAX; ++i) {
			np_hook_t fn = np_hooks[i];
			if(!fn) {
				break;
			}
			fn(pkt, rule->crc);
		}
	} else {
		np_warn(FMT_FLOW_STR"-NOT changed proto: %d\n", FMT_FLOW(fi), proto_new);
		return;
	}
	fi->hdr.proto = proto_new;
}

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

	nproto_proc_init();
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
	nproto_proc_exit();
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
MODULE_AUTHOR("1767ff8829cfe9e30f1a3170427e9b10 <@gmail.com>");
MODULE_LICENSE("GPL");