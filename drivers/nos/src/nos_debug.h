#ifndef _NOS_TBQ_H
#define _NOS_TBQ_H

#include <linux/module.h>
#include <linux/version.h>
#include <linux/kmod.h>

#include <linux/workqueue.h>
#include <linux/skbuff.h>
#include <linux/netlink.h>
#include <linux/kobject.h>

#include <linux/rculist.h>
#include <linux/ratelimit.h>

#include <linux/netfilter.h>
#include <linux/netfilter_ipv4.h>
#include <net/netfilter/nf_queue.h>
#include <net/netfilter/nf_conntrack.h>

#include <linux/nos_track.h>


/* ip session format */
//common defs
#define NIPQUAD(addr) \
	((unsigned char *)&addr)[0], \
	((unsigned char *)&addr)[1], \
	((unsigned char *)&addr)[2], \
	((unsigned char *)&addr)[3]

#define HIPQUAD(addr) \
	((unsigned char *)&addr)[3], \
	((unsigned char *)&addr)[2], \
	((unsigned char *)&addr)[1], \
	((unsigned char *)&addr)[0]
	
#define FMT_FLOW_STR "%u.%u.%u.%u:%u->%u.%u.%u.%u:%u [%u]"

#define FMT_FLOW(flow) HIPQUAD((flow)->tuple.ip_src), ((flow)->tuple.port_src), \
	HIPQUAD((flow)->tuple.ip_dst), ((flow)->tuple.port_dst), ((flow)->tuple.proto)

/* debug utils */
#ifdef __DEBUG
#define NOS_DBG(fmt, args...) \
	do {\
		printk("[dbg: %s,%d] ", __FUNCTION__, __LINE__); \
		printk(fmt, ##args); \
	} while (0)

#define DBG_IF(exp, fmt, args...) \
	do {\
		if((exp)) { \
			NOS_DBG(fmt, ##args); \
		} \
	}while(0)
#else
#define NOS_DBG(fmt, args...) do{}while(0)
#define DBG_IF(exp, fmt, args...) do{}while(0)
#endif

/* printk err/info */
#define logerr(fmt, args...) \
	do {\
		printk("[err: %s,%d] ", __FUNCTION__, __LINE__); \
		printk(fmt, ##args); \
	} while (0)

#define loginfo(fmt, args...) \
	do {\
		printk("[msg: %s,%d] ", __FUNCTION__, __LINE__); \
		printk(fmt, ##args); \
	} while (0)

#endif /* _NOS_TBQ_H */