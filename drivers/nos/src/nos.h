#ifndef __NOS_MODULE_H__
#define __NOS_MODULE_H__

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/ioport.h>
#include <linux/stddef.h>
#include <linux/types.h>
#include <linux/limits.h>
#include <linux/string.h>
#include <linux/fs.h>
#include <linux/io.h>
#include <linux/ioctl.h>
#include <linux/device.h>
#include <linux/cdev.h>
#include <linux/mm.h>
#include <linux/mm_types.h>
#include <linux/smp.h>
#include <linux/vmalloc.h>
#include <linux/sched.h>
#include <linux/rbtree.h>
#include <linux/jhash.h>
#include <linux/ip.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <linux/icmp.h> 
#include <linux/netfilter.h>
#include <linux/kthread.h>
#include <linux/netfilter_bridge.h>

#include <asm/uaccess.h>
#include <asm/cacheflush.h>

#include <net/netfilter/nf_conntrack.h>

#include <linux/nos_track.h>

#include "nos_debug.h"
#define NOS_TIMER_INTERVAL 1000
#define NOS_MAX_USER (1 << 15)
struct policy {
	struct list_head list;
	struct {
		struct list_head units;
		uint32_t ip1;
		uint32_t ip2;
	} pol;
};

struct user_node {
	struct list_head node;
	uint32_t ip;
	uint32_t jf;
	uint32_t status; 	//0 1
	unsigned char mac[ETH_ALEN]; 
};

struct nos_config {
	struct policy pols;
};

struct nos_timer {
	struct timer_list ktimer;
	unsigned long jiffies;
	//unsigned long nr_pending; 
};

enum nos_status {
	NOS_STATUS_STOP,
	NOS_STATUS_RUN,
};

struct nos_global {
	spinlock_t lock; 
	struct nos_timer timer;
	
	enum nos_status status;
	struct nos_config config; 
	
	struct hlist_head users[NOS_MAX_USER];
};

extern struct nos_global g_nos;

static inline void nos_status_set(enum nos_status status)
{
	smp_mb();
	g_nos.status = status;
	smp_mb();
	synchronize_rcu();
}

static inline int nos_status_is(enum nos_status status)
{
	int ret = g_nos.status == status;
	smp_mb();
	return ret;
}

/*
 * 用于节点获取. 
 */
static inline struct nos_track * nos_track_get(struct nf_conn *ct)
{
	return &ct->nos_track;

	// /* flow 的关联链接初始化 */
	// struct nos_flow_info *flow = nos_track_get_flow(nos);
	// if (flow) {
	// 	if (ct->master && flow->master_magic == 0) 
	// 	{	
	// 		//FIXME,magic可能为0是正常值, 这种情况, 多次赋值, 没影响.
	// 		struct nos_flow_info *master;
	// 		master = nos_track_get_flow(&ct->master->nos_track); //parent
	// 		flow->master_magic = master->magic;
	// 		flow->master_id = master->id;
	// 		NOS_DBG("FLOW "FMT_FLOW_STR" expected by "FMT_FLOW_STR"\n",
	// 			FMT_FLOW(flow), FMT_FLOW(master));
	// 	}
	// 	return nos;
	// }

	// return NULL;
}
void nos_global_init(void);
void nos_global_cleanup(void);
int nos_sysfs_register(void);
void nos_sysfs_unregister(void);

#endif //__NOS_MODULE_H__
