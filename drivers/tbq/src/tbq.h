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

//#define TBQ_DEBUG_CONTROL_PPS
#define TBQ_LOG_LEVEL			2
#define TBQ_TRACE_FILTER		0
#define TBQ_TRACE_TIMER			0
#define TBQ_TIMER_INTERVAL		1
#define TBQ_TIMER_VEC_MASK		((1 << 8) - 1)
#define TBQ_RULE_NAME_MAX		36
#define TBQ_RULE_COUNT_MAX		32
#define TBQ_IP_RULE_COUNT_MAX	64
#define TBQ_APP_RULE_COUNT_MAX	64
#define TBQ_BYTES_PER_SEC_MAX	(2 * 1000 * 1000 * 1000)
#define TBQ_BACKLOG_PACKETS_MAX	1000000
#define TBQ_LATENCY_SHIFT_MAX	10
#define TBQ_DISABLE_TIMEOUT_MAX	60
#define TBQ_DRR_QUANTUM_SHIFT	11
#define TBQ_DRR_WEIGHT_MAX		255


#define TBQ_NEW(type) \
	TBQ_NEW_N(type, 1)

#define TBQ_NEW_N(type, n) \
	((type *)kzalloc((n) * sizeof(type), GFP_NOWAIT))

#define TBQ_LOG(level, fmt, ...) do { \
	if ((level) <= TBQ_LOG_LEVEL) { \
		pr_info_ratelimited("*TBQ* " fmt, ##__VA_ARGS__); \
	} \
} while (0)

#define TBQ_LOG_IF(level, cond, fmt, ...) do { \
	if ((level) <= TBQ_LOG_LEVEL) { \
		if (cond) { \
			pr_info_ratelimited("*TBQ* " fmt, ##__VA_ARGS__); \
		} \
	} \
} while (0)

#define TBQ_ASSERT(cond, fmt, ...) do { \
	if (unlikely(!(cond))) { \
		printk(fmt, ##__VA_ARGS__); \
		BUG(); \
	} \
} while (0)

#define TBQ_ERROR(...)			TBQ_LOG(0, ##__VA_ARGS__)
#define TBQ_ERROR_IF(cond, ...)	TBQ_LOG_IF(0, cond, ##__VA_ARGS__)

#define TBQ_WARN(...)			TBQ_LOG(1, ##__VA_ARGS__)
#define TBQ_WARN_IF(cond, ...)	TBQ_LOG_IF(1, cond, ##__VA_ARGS__)

#define TBQ_INFO(...)			TBQ_LOG(2, ##__VA_ARGS__)
#define TBQ_INFO_IF(cond, ...)	TBQ_LOG_IF(2, cond, ##__VA_ARGS__)

#define TBQ_DEBUG(...)			TBQ_LOG(3, ##__VA_ARGS__)
#define TBQ_DEBUG_IF(cond, ...)	TBQ_LOG_IF(3, cond, ##__VA_ARGS__)

#define TBQ_TRACE(type, ...)			TBQ_INFO_IF(TBQ_TRACE_##type, ##__VA_ARGS__)
#define TBQ_TRACE_IF(type, cond, ...)	TBQ_INFO_IF(TBQ_TRACE_##type && (cond), ##__VA_ARGS__)

#define TBQ_RULE_MASK_SET(mask, i)	((void)(mask |= 1u << i))
#define TBQ_RULE_MASK_CLR(mask, i)	((void)(mask &= ~(1u << i)))
#define TBQ_RULE_MASK_FOR_EACH(i, mask) \
	for ( ; (i = __builtin_ffs(mask) - 1) != -1; TBQ_RULE_MASK_CLR(mask, i))


struct tbq_dequeue_info {
	struct list_head send;
	struct list_head drop;
	uint32_t nr_send;
	uint32_t nr_drop;
};

struct tbq_token_config {
	int32_t tokens_per_jiffy;
};

struct tbq_token_ctrl {
	struct tbq_bucket *bucket;
	int32_t tokens;
	unsigned long jiffies;
	struct tbq_token_config config;
	struct list_head list;
	struct {
		struct list_head units;
		uint32_t octets;
		uint32_t weight;
	} backlog;
};

struct tbq_ip_rule {
	uint32_t min;
	uint32_t max;
	uint32_t weight;
};

struct tbq_token_rule {
	struct tbq_token_config global;
	struct tbq_token_config user;
};

struct tbq_rule {
	char *name;
	uint8_t *wan_rules;
	uint32_t nr_wan_rule;
	struct tbq_ip_rule *ip_rules;
	uint32_t nr_ip_rule;
	uint16_t *app_rules;
	uint32_t nr_app_rule;
	struct tbq_token_rule token_rules[2];
};

#define TBQ_MAX_IFACE_COUNT (16)
#define TBQ_MAX_IFNAME_SIZE (32)
struct tbq_iface_item {
	char name[TBQ_MAX_IFNAME_SIZE];
};

struct tbq_iface {
	uint32_t cur;
	char ifname[TBQ_MAX_IFNAME_SIZE][TBQ_MAX_IFACE_COUNT];
	//struct tbq_iface_item ifaces[TBQ_MAX_IFACE_COUNT];
};

struct tbq_config {
	struct tbq_rule *rules;
	uint32_t nr_rule;
	uint32_t max_backlog_packets;
	uint32_t latency_shift;
	uint32_t disable_timeout;
	struct tbq_iface lan;
	struct tbq_iface wan;
};

struct tbq_user {
	struct tbq_user_sched *sched;
	struct tbq_token_ctrl tc;
	struct tbq_backlog backlog;
};

struct tbq_user_sched {
	uint32_t ip;
	uint32_t inactive_mask;
	struct tbq_user users[TBQ_RULE_COUNT_MAX];
};

struct tbq_user_track {
	struct nos_user_track *ut;
	struct list_head list;
	struct tbq_user_sched sched[2];
	uint32_t rule_mask;
};

struct tbq_bucket {
	const char *name;
	int pkt_dir;
	struct tbq_bucket_sched *sched;
	struct tbq_token_ctrl tc;
	struct tbq_token_config user_tc_config;
};

struct tbq_bucket_sched {
	uint32_t inactive_mask;
	struct tbq_bucket buckets[TBQ_RULE_COUNT_MAX];
};

enum tbq_status {
	TBQ_STATUS_RUNNING,
	TBQ_STATUS_STOPPED,
	TBQ_STATUS_STOPPING,
	TBQ_STATUS_WAITING_STOP,
	TBQ_STATUS_COUNT
};

struct tbq_timer {
	struct timer_list ktimer;
	unsigned long jiffies;
	unsigned long nr_pending;
	struct list_head vec[TBQ_TIMER_VEC_MASK + 1];
};

struct tbq_global {
	struct tbq_config config;
	struct list_head users;
	struct list_head flows;
	struct tbq_bucket_sched sched[2];
	uint32_t backlog_packets;
	spinlock_t lock;
	enum tbq_status status;
	struct completion disable_done;
	struct tbq_timer timer;
};


extern struct tbq_global tbq;


static inline void tbq_status_set(enum tbq_status status)
{
	smp_mb();
	tbq.status = status;
	smp_mb();
	synchronize_rcu();
}

static inline int tbq_status_is(enum tbq_status status)
{
	int ret = tbq.status == status;
	smp_mb();
	return ret;
}

uint32_t tbq_app_match(uint16_t app, uint32_t all_mask, uint8_t *weight);
void tbq_config_cleanup(struct tbq_config *config);
void tbq_global_set_config(struct tbq_config *config);
int tbq_sysfs_register(void);
void tbq_sysfs_unregister(void);


#endif /* _NOS_TBQ_H */