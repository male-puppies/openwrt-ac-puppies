#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/list.h>
#include <asm/smp.h>

#include <linux/nos_track.h>
#include <ntrack_comm.h>
#include <ntrack_context.h>
#include <ntrack_log.h>

extern int nproto_init(void);
extern void nproto_cleanup(void);

int nt_context_chk_fn(struct sk_buff *skb, 
	struct nos_track *nt, 
	struct net_device *indev)
{
	flow_info_t *fi = nt_flow(nt);
	user_info_t *ui = nt_user(nt);

	np_info(FMT_FLOW_STR"\n", FMT_FLOW(fi));
	np_print("\t"FMT_USER_STR"\n", FMT_USER(ui));
	return 0;
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
	klog_fini(nproto_klog_fd);
	return r;
}

static void __exit nproto_module_exit(void)
{
	rcu_assign_pointer(nt_cck_fn, NULL);
	nproto_cleanup();
	
	klog_fini(nproto_klog_fd);
}

module_init(nproto_module_init);
module_exit(nproto_module_exit);

MODULE_DESCRIPTION(DRV_DESC);
MODULE_VERSION(DRV_VERSION);
MODULE_AUTHOR("xxx <ooo@gmail.com>");
MODULE_LICENSE("GPL");