#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/list.h>
#include <asm/smp.h>

#include <linux/nos_track.h>
#include <ntrack_comm.h>
#include <ntrack_context.h>
#include <ntrack_log.h>

int nt_context_chk_fn(struct sk_buff *skb, 
	struct nos_track *nt, 
	struct net_device *indev)
{
	flow_info_t *fi = nt_flow(nt);
	user_info_t *ui = nt_user(nt);

	nt_info(FMT_FLOW_STR"\n", FMT_FLOW(fi));
	nt_print("\t"FMT_USER_STR"\n", FMT_USER(ui));
	return 0;
}

static int __init nproto_module_init(void)
{
	rcu_assign_pointer(nt_cck_fn, nt_context_chk_fn);

	return 0;
}

static void __exit nproto_module_exit(void)
{
	rcu_assign_pointer(nt_cck_fn, NULL);
}

module_init(nproto_module_init);
module_exit(nproto_module_exit);

MODULE_DESCRIPTION(DRV_DESC);
MODULE_VERSION(DRV_VERSION);
MODULE_AUTHOR("xxx <ooo@gmail.com>");
MODULE_LICENSE("GPL");