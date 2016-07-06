#pragma once

#include <linux/nos_track.h>
#include <nproto/build-in.h>

#define NETLINK_NPROTO 29

#ifdef __KERNEL__
#include <linux/skbuff.h>
#include <linux/netdevice.h>

#else /* KERNEL */

#endif
