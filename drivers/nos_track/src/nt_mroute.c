#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/list.h>
#include <asm/smp.h>

#include <linux/nos_track.h>
#include <ntrack_log.h>

int nt_mroute_marker(struct sk_buff *skb, 
	struct nos_track *nos, 
	struct net_device *indev)
{
	return 0;
}