#include "nproto_private.h"

#define STAT_HASH_WIDTH_FLOW 	(512)
#define STAT_HASH_WIDTH_USER	(64)
#define STAT_FLUSH_INTV			(7 * HZ)
#define STAT_TIMEOUT_TOUCH		(3 * HZ)
#define STAT_TIMEOUT_ACTIVE		(60 * HZ)

typedef enum {
	STAT_TYPE_FLOW = 0,
	STAT_TYPE_USER,
} __em_stat_node_type_t;

typedef struct {
	rwlock_t *hash_lock;
	struct hlist_head *hash;
	uint32_t hash_width;
} stat_t;

static struct kmem_cache *stat_node_cache __read_mostly;
static stat_t *pStatFlow __read_mostly;
static stat_t *pStatUser __read_mostly;

static rwlock_t flush_lock;
static rwlock_t ghash_lock;
static struct timer_list flush_timer; /* trav timer */

static inline uint32_t grand_realtime(uint64_t now, uint64_t prev, uint32_t elapse)
{
	uint64_t grand;
	uint32_t remainder;
	if(unlikely(now < prev)) {
		grand = (uint64_t)-1 - prev + now;
	} else {
		grand = now - prev;
	}
	remainder = do_div(grand, elapse);
	return grand ? : (remainder ? 1 : 0);
}

static inline uint32_t stat_hash(uint32_t a, uint32_t b, uint32_t w)
{
	return (a * b) % w;
}

static inline rwlock_t* stat_hash_lock(stat_t *ps, int idx)
{
	return ps->hash_lock ? &ps->hash_lock[idx] : &ghash_lock;
}

static void stat_touch_fn(unsigned long d);
static stat_node_t* stat_node_find(stat_t *ps,
			uint32_t id,
			uint32_t magic,
			int type, void *ni)
{
	uint32_t idx = stat_hash(id, magic, ps->hash_width);
	rwlock_t *lock = stat_hash_lock(ps, idx);
	struct hlist_head *head = &ps->hash[idx];
	stat_node_t *node = NULL;

	read_lock_bh(lock);
	hlist_for_each_entry_rcu(node, head, hlist) {
		if(id == node->data.id
			&& magic == node->data.magic) {
			// np_print("-- found node: %u,%u\n", id, magic);
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
		node->data.id = id;
		node->data.magic = magic;
		node->data.type = type;
		node->data.active_stamp = 0;

		node->pointer = ni;
		node->head = head;
		node->lock = lock;
		init_timer(&node->timer_touch);
		node->timer_touch.data = (unsigned long)node;
		node->timer_touch.function = stat_touch_fn;

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
	stat_data_t *data = NULL;
	flow_info_t *fi = NULL;
	user_info_t *ui = NULL;
	uint32_t elapse, id, magic;
	uint64_t recv_pkts = 0, recv_bytes = 0, xmit_pkts = 0, xmit_bytes = 0;

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
	data = &node->data;
	if(data->active_stamp) {
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
		elapse = (jiffies - data->active_stamp) / HZ;
		if(!elapse) {
			/* fixup 0 */
			elapse = 1;
		}
		data->recv_pkts_rt = grand_realtime(recv_pkts, data->recv_pkts, elapse);
		data->recv_bytes_rt = grand_realtime(recv_bytes, data->recv_bytes, elapse);
		data->xmit_pkts_rt = grand_realtime(xmit_pkts, data->xmit_pkts, elapse);
		data->xmit_bytes_rt = grand_realtime(xmit_bytes, data->xmit_bytes, elapse);
		if(data->recv_pkts_rt ||
			 data->recv_bytes_rt ||
			 data->xmit_pkts_rt ||
			 data->xmit_bytes_rt) {
			/* update active */
			data->active_stamp = jiffies;
		}
	} else {
		/* init */
		data->active_stamp = jiffies;
	}

	/* update data */
	data->recv_pkts = recv_pkts;
	data->recv_bytes = recv_bytes;
	data->xmit_pkts = xmit_pkts;
	data->xmit_bytes = xmit_bytes;
	mod_timer(&node->timer_touch, jiffies + STAT_TIMEOUT_TOUCH);
	return;
}

void stat_flow(flow_info_t *fi,
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

void stat_user(
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

	np_debug("%p - %u, %u\n", node, node->data.id, node->data.magic);
	kmem_cache_free(stat_node_cache, node);
}

static void stat_node_release_nolock(stat_node_t *node)
{
	write_lock_bh(node->lock);
	hlist_del(&node->hlist);
	write_unlock_bh(node->lock);

	del_timer_sync(&node->timer_touch);
	call_rcu_bh(&node->rcu, destroy_nodes_rcu_fn);
}

static void stat_touch_fn(unsigned long d)
{
	stat_node_t *node = (stat_node_t *)d;

	/* timeout */
	if(time_after_eq(jiffies, (unsigned long)node->data.active_stamp + STAT_TIMEOUT_ACTIVE)) {
		/* bye, del node && cleanup */
		// np_print("on timer suicide %p.\n", node);
		stat_node_release_nolock(node);
		return;
	} else {
		/* setup suicide timer. */
		mod_timer(&node->timer_touch, jiffies + STAT_TIMEOUT_ACTIVE);
	}

	/* setup stat flag,
	* 	if packages come-in,
	* 		the timer updated TOUCH_TIMEOUT.
	* 	else
	*		the timer timeout by ACTIVE_TIMEOUT.
	*/
	switch(node->data.type) {
		case STAT_TYPE_FLOW: {
			flow_info_t *fi = node->pointer;
			if(!(fi->id == node->data.id &&
					fi->magic == node->data.magic)) {
				np_warn("not found %u.%u - %u.%u\n", fi->id, fi->magic, node->data.id, node->data.magic);
				stat_node_release_nolock(node);
				return;
			}
			nt_flow_stat_clr(fi);
		}
		break;
		case STAT_TYPE_USER: {
			user_info_t *ui = node->pointer;
			if(!(ui->id == node->data.id &&
					ui->magic == node->data.magic)) {
				np_warn("not found %u.%u - %u.%u\n", ui->id, ui->magic, node->data.id, node->data.magic);
				stat_node_release_nolock(node);
				return;
			}
			nt_user_stat_clr(ui);
		}
		break;
		default: BUG();
	}
}

static void trav_node_locked_call(stat_t *ps, void *data, int (*cb)(void *, stat_node_t *))
{
	int i;
	stat_node_t *node;

	/* trav all node, flush stat to reserved mem. */
	for (i = 0; i < ps->hash_width; ++i) {
		struct hlist_head *head = &ps->hash[i];
		rwlock_t *lock = stat_hash_lock(ps, i);
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
	int idx = 0;
	stat_info_t *info = d;
	static int type_prev = -1;

	/* detect the type change. */
	if(type_prev >= 0 && type_prev != node->data.type) {
		/* store the offset */
		if(info->nr_active_user) {
			if(info->nr_active_flow) {
				BUG();
			}
			info->offset_stat_user = 0;
			info->offset_stat_flow = info->nr_active_user;
		} else if(info->nr_active_flow) {
			if(info->nr_active_user) {
				BUG();
			}
			info->offset_stat_flow = 0;
			info->offset_stat_user = info->nr_active_flow;
		}
	}
	type_prev = node->data.type;

	/* flush data. */
	switch(node->data.type) {
		case STAT_TYPE_FLOW: {
			idx = info->offset_stat_flow + info->nr_active_flow;
			info->nr_active_flow ++;
		}break;
		case STAT_TYPE_USER: {
			idx = info->offset_stat_user + info->nr_active_user;
			info->nr_active_user ++;
		}break;
		default: BUG(); break;
	}
	np_debug("info_base: %p, node: %p %d\n"
		"\t"FMT_STAT_STR"\n",
		info, node, node->data.type, FMT_STAT_DATA((&node->data)));

	info->data[idx] = node->data;
	return 0;
}

static int trav_destroy_nodes_fn(void *d, stat_node_t *node)
{
	hlist_del(&node->hlist);

	del_timer_sync(&node->timer_touch);
	call_rcu_bh(&node->rcu, destroy_nodes_rcu_fn);
	return 0;
}

static void nodes_destroy(stat_t *ps)
{
	write_lock_bh(&flush_lock);
	trav_node_locked_call(ps, NULL, trav_destroy_nodes_fn);
	write_unlock_bh(&flush_lock);
}

static void stat_flush_fn(unsigned long d)
{
	// np_info("collect unode & flow\n");

	write_lock_bh(&flush_lock);
	memset(nos_stat_info_base, 0, sizeof(stat_info_t));
	trav_node_locked_call(pStatUser, nos_stat_info_base, trav_flush_nodes_fn);
	trav_node_locked_call(pStatFlow, nos_stat_info_base, trav_flush_nodes_fn);
	write_unlock_bh(&flush_lock);

	mod_timer(&flush_timer, jiffies + STAT_FLUSH_INTV);
}

static void stat_flusher_start(void)
{
	struct timer_list *timer = &flush_timer;

	init_timer(timer);
	timer->data = 0L;
	timer->function = stat_flush_fn;

	mod_timer(timer, jiffies + STAT_FLUSH_INTV);
}

static void stat_flusher_stop(void)
{
	del_timer_sync(&flush_timer);
}

static int stat_open(struct inode *inode, struct file *file)
{
	return 0;
}

static int stat_release(struct inode *inode, struct file *file)
{
	return 0;
}

static const struct file_operations flush_lockfs = {
	.owner		= THIS_MODULE,
	.open		= stat_open,
	.release	= stat_release,
};

static void stat_destroy(stat_t *ps)
{
	BUG_ON(!ps);

	if(ps->hash_lock) {
		vfree(ps->hash_lock);
		ps->hash_lock = NULL;
	}
	if(ps->hash) {
		vfree(ps->hash);
		ps->hash = NULL;
	}
	kfree(ps);
}

static stat_t * stat_create(int hash_width)
{
	int i;

	stat_t *ps = kmalloc(sizeof(stat_t), GFP_KERNEL);
	if(ZERO_OR_NULL_PTR(ps)) {
		np_error("not enough mem.\n");
		return NULL;
	}
	memset(ps, 0, sizeof(stat_t));

	if(sizeof(rwlock_t)) {
		/*shit: mips one core, sizeof(rwlock_t) == 0 */
		ps->hash_lock = vmalloc((sizeof(rwlock_t) * hash_width));
		if(!ps->hash_lock) {
			np_error("not enough mem for hash lock[%d]s. width: %d\n", sizeof(rwlock_t), hash_width);
			goto __err_nomem;
		}
	}
	ps->hash = vmalloc(sizeof(struct hlist_head) * hash_width);
	if(!ps->hash) {
		np_error("not enough mem for hash head. width: %d\n", hash_width * sizeof(struct hlist_head));
		goto __err_nomem;
	}

	ps->hash_width = hash_width;
	for (i = 0; i < ps->hash_width; ++i) {
		INIT_HLIST_HEAD(&ps->hash[i]);
		rwlock_init(&ps->hash_lock[i]);
	}
	return ps;

__err_nomem:
	stat_destroy(ps);
	return NULL;
}

int stat_init(void)
{
	struct proc_dir_entry *lockfs;

	pStatFlow = stat_create(STAT_HASH_WIDTH_FLOW);
	pStatUser = stat_create(STAT_HASH_WIDTH_USER);
	if(!pStatFlow || !pStatUser) {
		goto __err_nomem;
	}

	stat_node_cache = kmem_cache_create("stat_node",
		sizeof(stat_node_t), 0, SLAB_HWCACHE_ALIGN, NULL);
	if(!stat_node_cache) {
		goto __err_nomem;
	}

	if(!nproto_proc_dir) {
		np_error("init nproto procfs first.\n");
		BUG();
	}

	lockfs = proc_create_data(PROC_file_stat, 655, nproto_proc_dir, &flush_lockfs, NULL);
	if(!lockfs) {
		np_error("create lock proc file failed.\n");
		goto __err_nomem;
	}

	memset(nos_stat_info_base, 0, sizeof(stat_info_t));
	rwlock_init(&flush_lock);
	rwlock_init(&ghash_lock);
	stat_flusher_start();
	np_info("statistics init ok.\n");
	return 0;

__err_nomem:
	np_error("alloc failed.\n");
	if(pStatFlow) {
		stat_destroy(pStatFlow);
	}
	if(pStatUser) {
		stat_destroy(pStatUser);
	}
	return -ENOMEM;
}

void stat_exit(void)
{
	stat_flusher_stop();

	nodes_destroy(pStatFlow);
	nodes_destroy(pStatUser);

	if(nproto_proc_dir) {
		remove_proc_entry(PROC_file_stat, nproto_proc_dir);
	}
	synchronize_rcu();
	kmem_cache_destroy(stat_node_cache);
	stat_destroy(pStatFlow);
	stat_destroy(pStatUser);
	np_info("statistics cleanup ok.\n");
	return;
}
