#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/list.h>
#include <asm/smp.h>

#include <linux/nos_track.h>
#include <ntrack_context.h>
#include <ntrack_log.h>

context_chk_t nt_cck_fn = NULL;
EXPORT_SYMBOL(nt_cck_fn);

int nt_context_check(struct sk_buff *skb, 
	struct nos_track *nos, 
	struct net_device *indev)
{
	context_chk_t fn = rcu_dereference(nt_cck_fn);
	if(fn) {
		return fn(skb, nos, indev);
	}
	return 0;
}
