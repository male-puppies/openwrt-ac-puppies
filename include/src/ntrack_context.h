#pragma once

#include <linux/skbuff.h>
#include <linux/netdevice.h>

#include <linux/nos_track.h>

typedef int (*context_chk_t)(struct sk_buff *, struct nos_track *, struct net_device *);
extern context_chk_t nt_cck_fn;
