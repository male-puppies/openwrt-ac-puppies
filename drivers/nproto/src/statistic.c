#include "nproto_private.h"

#define STAT_HASH_WIDTH 	(1024)
#define STAT_FLUSH_INTV		(5 * HZ)
#define STAT_TIMEOUT_TOUCH	(3 * HZ)
#define STAT_TIMEOUT_ACTIVE	(60 * HZ)

typedef enum {
	STAT_TYPE_FLOW = 0,
	STAT_TYPE_USER,
} __em_stat_node_type_t;

typedef struct {
	rwlock_t hash_lock[STAT_HASH_WIDTH];
	struct hlist_head hash[STAT_HASH_WIDTH];

	struct timer_list timer_flush; /* trav timer */
} stat_t;

typedef struct {
	struct hlist_node hlist;
	struct rcu_head rcu;

	rwlock_t *lock;
	struct hlist_head *head;

	struct timer_list timer_sm;
	uint32_t id, magic;
	int type;
	void *pointer;

	/* last touch stamp, last active stamp */
	uint32_t active_stamp;

	uint64_t recv_pkts, recv_bytes; /* current history */
	uint64_t xmit_pkts, xmit_bytes;
	uint32_t recv_pkts_rt, recv_bytes_rt; /* realtime */
	uint32_t xmit_pkts_rt, xmit_bytes_rt;
} stat_node_t;

static struct kmem_cache *stat_node_cache __read_mostly;
static stat_t *pStatFlow __read_mostly;
static stat_t *pStatUser __read_mostly;

static inline uint64_t grand_realtime(uint64_t now, uint64_t prev, uint32_t elapse)
{
	uint64_t grand;
	if(unlikely(now < prev)) {
		grand = (uint64_t)-1 - prev + now;
	} else {
		grand = now - prev;
	}
	return (grand / elapse) ? : (grand ? 1 : 0);
}

static uint32_t inline stat_hash(uint32_t a, uint32_t b)
{
	return (a * b) % STAT_HASH_WIDTH;
}

static void stat_touch_fn(unsigned long d);
static stat_node_t* stat_node_find(stat_t *pstat, 
			uint32_t id, 
			uint32_t magic, 
			int type, void *ni)
{
	uint32_t idx = stat_hash(id, magic);
	struct hlist_head *head = &pstat->hash[idx];
	rwlock_t *lock = &pstat->hash_lock[idx];
	stat_node_t *node = NULL;
	
	read_lock_bh(lock);
	hlist_for_each_entry_rcu(node, head, hlist) {
		if(id == node->id 
			&& magic == node->magic) {
			break;
		}
	}
	read_unlock_bh(lock);
	if(!node) {
		node = kmem_cache_alloc(stat_node_cache, GFP_ATOMIC);
		if(!node) {
			np_error("not enough memory\n");
			return NULL;
		}
		/* init */
		node->id = id;
		node->magic = magic;
		node->type = type;
		node->pointer = ni;
		node->active_stamp = 0;
		node->head = head;
		node->lock = lock;
		init_timer(&node->timer_sm);
		node->timer_sm.data = (unsigned long)node;
		node->timer_sm.function = stat_touch_fn;

		/* add to hlist */
		write_lock_bh(lock);
		hlist_add_head_rcu(&node->hlist, head);
		write_unlock_bh(lock);
	}
	return node;
}

static void stat_realtime(void *ni, int type)
{
	stat_t *ps = NULL;
	stat_node_t *node = NULL;
	flow_info_t *fi = NULL;
	user_info_t *ui = NULL;
	uint32_t elapse, id, magic;
	uint64_t recv_pkts, recv_bytes, xmit_pkts, xmit_bytes;

	switch(type) {
		case STAT_TYPE_FLOW: {
			fi = ni;
			id = fi->id;
			magic = fi->magic;
			ps = pStatFlow;
			nt_flow_stat_set(fi);
		}
		break;
		case STAT_TYPE_USER: {
			ui = ni;
			id = ui->id;
			magic = ui->magic;
			ps = pStatUser;
			nt_user_stat_set(ui);
		}
		break;
		default: BUG();
	}
	node = stat_node_find(ps, id, magic, type, ni);
	if(!node) {
		return;
	}
	/* calc realtime */
	if(node->active_stamp) {
		if(fi) {
			recv_pkts = fi->hdr.recv_pkts;
			recv_bytes = fi->hdr.recv_bytes;
			xmit_pkts = fi->hdr.xmit_pkts;
			xmit_bytes = fi->hdr.xmit_bytes;
		} else if(ui) {
			recv_pkts = ui->hdr.recv_pkts;
			recv_bytes = ui->hdr.recv_bytes;
			xmit_pkts = ui->hdr.xmit_pkts;
			xmit_bytes = ui->hdr.xmit_bytes;
		} 
		elapse = (jiffies - node->active_stamp) / HZ;
		if(!elapse) {
			/* fixup 0 */
			elapse = 1;
		}
		node->recv_pkts_rt = grand_realtime(recv_pkts, node->recv_pkts, elapse);
		node->recv_bytes_rt = grand_realtime(recv_bytes, node->recv_bytes, elapse);
		node->xmit_pkts_rt = grand_realtime(xmit_pkts, node->xmit_pkts, elapse);
		node->xmit_bytes_rt = grand_realtime(xmit_bytes, node->xmit_bytes, elapse);
		if(node->recv_pkts_rt ||
			 node->recv_bytes_rt ||
			 node->xmit_pkts_rt ||
			 node->xmit_bytes_rt) {
			/* update active */
			node->active_stamp = jiffies;
		}
	} else {
		/* init */
		node->active_stamp = jiffies;
	}

	/* update node */
	node->recv_pkts = recv_pkts;
	node->recv_bytes = recv_bytes;
	node->xmit_pkts = xmit_pkts;
	node->xmit_bytes = xmit_bytes;
	mod_timer(&node->timer_sm, jiffies + STAT_TIMEOUT_TOUCH);
	return;
}

inline void stat_flow(flow_info_t *fi, 
		int16_t dir, int16_t nbytes)
{
	flow_hdr_t *hdr = &fi->hdr;
	if(dir) {
		hdr->recv_pkts ++;
		hdr->recv_bytes += nbytes;
	} else {
		hdr->xmit_pkts ++;
		hdr->xmit_bytes += nbytes;
	}

	if(!nt_flow_stat(fi)) {
		stat_realtime(fi, STAT_TYPE_FLOW);
	}
}

inline void stat_user(
		user_info_t *ui, 
		user_info_t *pi,
		int16_t dir, int16_t nbytes)
{
	user_hdr_t *uh = &ui->hdr;
	user_hdr_t *ph = &pi->hdr;
	if(dir) {
		uh->xmit_pkts ++;
		uh->xmit_bytes += nbytes;
		ph->recv_pkts ++;
		ph->recv_bytes += nbytes;
	} else {
		ph->xmit_pkts ++;
		ph->xmit_bytes += nbytes;
		uh->recv_pkts ++;
		uh->recv_bytes += nbytes;
	}

	if(!nt_user_stat(ui)) {
		stat_realtime(ui, STAT_TYPE_USER);
	}

	if(!nt_user_stat(pi)) {
		stat_realtime(pi, STAT_TYPE_USER);
	}
}

static void destroy_nodes_rcu_fn(struct rcu_head *head)
{
	stat_node_t *node = container_of(head, stat_node_t, rcu);

	np_print("%p - %u, %u\n", node, node->id, node->magic);
	kmem_cache_free(stat_node_cache, node);
}

static void stat_node_release(stat_node_t *node)
{
	write_lock_bh(node->lock);
	hlist_del(&node->hlist);
	write_unlock_bh(node->lock);

	del_timer_sync(&node->timer_sm);
	call_rcu_bh(&node->rcu, destroy_nodes_rcu_fn);
}

static void stat_touch_fn(unsigned long d)
{
	stat_node_t *node = (stat_node_t *)d;

	/* timeout */
	if(time_after_eq(jiffies, (unsigned long)node->active_stamp + STAT_TIMEOUT_ACTIVE)) {
		/* bye, del node && cleanup */
		np_print("on timer suicide %p.\n", node);
		stat_node_release(node);
		return;
	} else {
		/* setup suicide timer. */
		mod_timer(&node->timer_sm, jiffies + STAT_TIMEOUT_ACTIVE);
	}

	/* setup stat flag */
	switch(node->type) {
		case STAT_TYPE_FLOW: {
			flow_info_t *fi = node->pointer;
			if(!(fi->id == node->id && 
					fi->magic == node->magic)) {
				np_warn("not found %u.%u - %u.%u\n", fi->id, fi->magic, node->id, node->magic);
				stat_node_release(node);
				return;
			}
			nt_flow_stat_clr(fi);
		}
		break;
		case STAT_TYPE_USER: {
			user_info_t *ui = node->pointer;
			if(!(ui->id == node->id &&
					ui->magic == node->magic)) {
				np_warn("not found %u.%u - %u.%u\n", ui->id, ui->magic, node->id, node->magic);
				stat_node_release(node);
				return;
			}
			nt_user_stat_clr(ui);
		}
		break;
		default: BUG();
	}
}

static void trav_node_call(stat_t *ps, void *data, int (*cb)(void *, stat_node_t *))
{
	int i;
	stat_node_t *node;

	/* trav all node, flush stat to reserved mem. */
	for (i = 0; i < STAT_HASH_WIDTH; ++i) {
		struct hlist_head *head = &ps->hash[i];
		rwlock_t *lock = &ps->hash_lock[i];
		write_lock_bh(lock);
		hlist_for_each_entry_rcu(node, head, hlist) {
			/* flush out */
			if(cb && cb(data, node)) {
				break;
			}
		}
		write_unlock_bh(lock);
	}
}

static int trav_flush_nodes_fn(void *d, stat_node_t *node)
{

	return 0;
}

static int trav_destroy_nodes_fn(void *d, stat_node_t *node)
{
	hlist_del(&node->hlist);
	call_rcu_bh(&node->rcu, destroy_nodes_rcu_fn);
	return 0;
}

static void destroy_nodes(stat_t *ps)
{
	trav_node_call(ps, NULL, trav_destroy_nodes_fn);
}

static void stat_flush_fn(unsigned long d)
{
	trav_node_call((stat_t *)d, NULL, trav_flush_nodes_fn);
}

void stat_lock_init(stat_t *p)
{
	int i;

	for (i = 0; i < STAT_HASH_WIDTH; ++i) {
		rwlock_init(&p->hash_lock[i]);
	}
}

void stat_timer_start(stat_t *p)
{
	struct timer_list *timer = &p->timer_flush;

	init_timer(timer);
	timer->data = (unsigned long )p;
	timer->function = stat_flush_fn;

	mod_timer(timer, jiffies + STAT_FLUSH_INTV);
}

void stat_timer_stop(stat_t *p)
{
	del_timer_sync(&p->timer_flush);
}

/* hash table - active nodes.
* 	pkg -> stat_flag -> update-ht
* 		
* 	timer -> 1s -> trav -> stat_flag -> timeout-cleanup-flag
* 								-> timeout-cleanup-node
* 											-> flush-store
*/ 
int stat_init(void)
{
	pStatFlow = kmalloc(sizeof(stat_t), GFP_KERNEL);
	if(!pStatFlow) {
		goto __err_nomem;
	}
	pStatUser = kmalloc(sizeof(stat_t), GFP_KERNEL);
	if(!pStatUser) {
		goto __err_nomem;
	}
	stat_node_cache = kmem_cache_create("stat_node",
		sizeof(stat_node_t), 0, SLAB_HWCACHE_ALIGN, NULL);
	if(!stat_node_cache) {
		goto __err_nomem;
	}

	stat_lock_init(pStatFlow);
	stat_lock_init(pStatUser);
	stat_timer_start(pStatFlow);
	stat_timer_start(pStatUser);

	return 0;

__err_nomem:
	if(pStatFlow) {
		kfree(pStatFlow);
	}
	if(pStatUser) {
		kfree(pStatUser);
	}
	return -ENOMEM;
}

void stat_exit(void)
{
	stat_timer_stop(pStatFlow);
	stat_timer_stop(pStatUser);
	destroy_nodes(pStatFlow);
	destroy_nodes(pStatUser);

	synchronize_rcu();
	kmem_cache_destroy(stat_node_cache);
	kfree(pStatFlow);
	kfree(pStatUser);
	return;
}
