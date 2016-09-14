#pragma once

#include <linux/nos_track.h>
#include <ntrack_flow.h>

#define FMT_STAT_STR "%llu %llu %llu %llu %u %u %u %u"
#define FMT_STAT_DATA(x) \
			(uint64_t)(x)->recv_pkts,\
			(uint64_t)(x)->recv_bytes,\
			(uint64_t)(x)->xmit_pkts,\
			(uint64_t)(x)->xmit_bytes,\
			(uint32_t)(x)->recv_pkts_rt,\
			(uint32_t)(x)->recv_bytes_rt,\
			(uint32_t)(x)->xmit_pkts_rt,\
			(uint32_t)(x)->xmit_bytes_rt

typedef struct {
	uint32_t id, magic, type;

	/* last touch stamp, last active stamp */
	uint32_t active_stamp;

	uint64_t recv_pkts, recv_bytes; /* current history */
	uint64_t xmit_pkts, xmit_bytes;
	uint32_t recv_pkts_rt, recv_bytes_rt; /* realtime */
	uint32_t xmit_pkts_rt, xmit_bytes_rt;
} stat_data_t;

typedef struct {
#ifdef __KERNEL__
	struct hlist_node hlist;
	struct rcu_head rcu;

	rwlock_t *lock;
	struct hlist_head *head;

	struct timer_list timer_touch;
	void *pointer;
#else
	/* mie... */
#endif //__KERNEL__
	/* kernel & userspace common. */
	stat_data_t data;
} stat_node_t;

/*
*	share memory statistics struct.
*		num,offset,[flow nodes][user nodes]
*/
typedef struct {
	/* realtime flow statistics. */
	uint32_t nr_active_flow;
	uint32_t offset_stat_flow;
	uint32_t nr_active_user;
	uint32_t offset_stat_user;
	/* data store. */
	stat_data_t data[0];
} stat_info_t;
