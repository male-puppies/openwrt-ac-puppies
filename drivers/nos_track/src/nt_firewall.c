#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/list.h>
#include <linux/netfilter.h>
#include <asm/smp.h>

#include <linux/nos_track.h>
#include <ntrack_log.h>

int nt_firewall(struct sk_buff *skb, 
	struct nos_track *nos, 
	struct net_device *indev,
	struct net_device *outdev)
{
	return NF_ACCEPT;
}

int nt_statistics(struct sk_buff *skb, 
	struct nos_track *nos, 
	struct net_device *out)
{
	return 0;
}