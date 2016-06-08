#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/list.h>
#include <linux/skbuff.h>
#include <asm/smp.h>

#include <linux/nos_track.h>
#include <ntrack_comm.h>
#include <ntrack_packet.h>
#include <ntrack_nproto.h>
#include <ntrack_log.h>

extern int nproto_init(void);
extern void nproto_cleanup(void);
extern int rules_match(nt_packet_t *pkt);

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

	l4ptr = (((uint8_t *)iph) + iph->ihl * 4);
	l4len = ntohs(iph->tot_len) - (iph->ihl * 4);
	switch(iph->protocol) {
		case IPPROTO_TCP:
			pkt->tcp = (const struct tcphdr*)l4ptr;
			l7len = l4len - (pkt->tcp->doff * 4);
			l7ptr = l4ptr + (pkt->tcp->doff * 4);
		break;
		case IPPROTO_UDP:
			pkt->udp = (const struct udphdr*)l4ptr;
			l7len = l4len - sizeof(struct udphdr);
			l7ptr = l4ptr + sizeof(struct udphdr);
		break;
		default:
			/* icmp ... */
			pkt->generic_l4_ptr = l4ptr;
			l7len = 0;
			l7ptr = l4ptr;
		break;
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

	/* FIXME: tackoff-fixup the sock4/5/http proxy header. */
	n = nproto_pkt_init(skb, nt, &pkt);
	if(n) {
		np_error("packet init failed: %d\n", n);
		return n;
	}

	if(!nproto_finished(nt_flow(nt))) {
		n = rules_match(&pkt);
	}
	return n;
}

void *nproto_klog_fd = NULL;
static int __init nproto_module_init(void)
{
	int r;

	nproto_klog_fd = klog_init("nproto", 0x0e, 0);
	if(!nproto_klog_fd) {
		return -ENOMEM;
	}

	r = nproto_init();
	if(r) {
		np_error("nproto rules init failed.\n");
		goto __error;
	}

	rcu_assign_pointer(nt_cck_fn, nt_context_chk_fn);

__error:
	nproto_cleanup();
	if(nproto_klog_fd)
		klog_fini(nproto_klog_fd);
	return r;
}

static void __exit nproto_module_exit(void)
{
	rcu_assign_pointer(nt_cck_fn, NULL);

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