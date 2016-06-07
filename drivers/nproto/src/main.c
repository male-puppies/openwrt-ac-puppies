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
	struct iphdr *iph = ip_hdr(skb);
	flow_info_t *fi = nt_flow(nt);
	user_info_t *ui = nt_user(nt);
	user_info_t *pi = nt_peer(nt);

	pkt->fi = fi;
	pkt->ui = ui;
	pkt->pi = pi;

	/* C->S, S->C. */
	pkt->l4_proto = iph->protocol;
	pkt->dir = nt_flow_dir(&fi->tuple, iph);
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