#pragma once

#include <linux/nos_track.h>
#include <nproto/build-in.h>

#define NETLINK_NPROTO 29

#ifdef __KERNEL__
#include <linux/skbuff.h>
#include <linux/netdevice.h>

typedef int (*context_chk_t)(struct sk_buff *, struct nos_track *, struct net_device *);
extern context_chk_t nt_cck_fn;
#else /* KERNEL */

#endif

static inline int nproto_finished(const flow_info_t *fi)
{
	return fi->hdr.proto > NP_INNER_RULE_MAX;
}
