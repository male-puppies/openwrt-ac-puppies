#pragma once

#include <linux/nos_track.h>
#include <ntrack_packet.h>
#include <nproto/build-in.h>

#define NETLINK_NPROTO 29
#define NP_HOOK_MAX 8

/*
*  np_hook_t callback function,
	before proto change, be called by nproto.
*/
typedef int (*np_hook_t)(flow_info_t *fi, uint32_t proto_crc);
int np_hook_register(np_hook_t fn);
int np_hook_unregister(np_hook_t fn);

#ifdef __KERNEL__
#include <linux/skbuff.h>
#include <linux/netdevice.h>

#else /* KERNEL */

#endif /* end KERNEL */
