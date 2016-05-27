#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/workqueue.h>
#include <linux/slab.h>
#include <linux/list.h>
#include <asm/smp.h>

#include <linux/nos_track.h>
#include <ntrack_rbf.h>
#include <ntrack_msg.h>

#define KEY_TO_CORE(k) 	((k) % nr_cpu_ids)
#define NCAP_MAX_COUNT 	(2048)

typedef struct {
	struct list_head head;

	uint32_t buff_size;
	uint8_t buff[RBF_NODE_SIZE];
} nmsg_node_t;

typedef struct {
	struct list_head list;
	spinlock_t lock;
	uint64_t count;
	struct work_struct wq_msg;
	rbf_t* rbfp;
} nt_mqueue_t;

static struct workqueue_struct *nmsg_wq = NULL;
static nt_mqueue_t nmsg_cpus[NR_CPUS];

static inline nt_mqueue_t * nmsg_target_cpu(uint32_t cpu)
{
	/* FIXME: hash user node. */
	return &nmsg_cpus[cpu];
}

static void nmsg_wq_dequeue_func(struct work_struct *wq);

/* save in kernel sysctl par */
extern uint32_t nt_cap_block_sz;

int nt_msg_init(void)
{
	uint32_t size, i;

	nt_assert(nos_track_cap_base != NULL);
	nt_assert((nos_track_cap_size / nr_cpu_ids) >= RBF_NODE_SIZE * 32);

	nmsg_wq = alloc_workqueue("nmsg", 
		WQ_FREEZABLE | WQ_HIGHPRI | WQ_CPU_INTENSIVE, nr_cpu_ids);
	if(!nmsg_wq) {
		nt_error("alloc workqueue nmsg.\n");
		return -ENOMEM;
	}

	memset(nos_track_cap_base, 0, nos_track_cap_size);
	/* sizeof percpu's message buffer */
	size = nos_track_cap_size / nr_cpu_ids;
	for(i=0; i<nr_cpu_ids; i++) {
		nt_mqueue_t *nmsg = nmsg_target_cpu(i);
		nmsg->count = 0;
		spin_lock_init(&nmsg->lock);
		INIT_LIST_HEAD(&nmsg->list);
		nmsg->rbfp = rbf_init((void*)(nos_track_cap_base + size * i), size);
		INIT_WORK(&nmsg->wq_msg, nmsg_wq_dequeue_func);
		/* test call */
		queue_work_on(i, nmsg_wq, &nmsg->wq_msg);
	}
	nt_cap_block_sz = size;

	return 0;
}

void nt_msg_cleanup(void)
{
	if(nmsg_wq) {
		destroy_workqueue(nmsg_wq);
	}
}

int nt_msg_enqueue(nt_msghdr_t *hdr, void *buf_in, uint32_t key)
{
	uint32_t size = hdr->data_len;
	nmsg_node_t *node;
	nt_mqueue_t *cur_msgq = nmsg_target_cpu(KEY_TO_CORE(key));

	nt_assert(cur_msgq);
	if(cur_msgq->count > NCAP_MAX_COUNT) {
		nt_debug("queue list full.\n");
		return -ENOMEM;
	}

	if(size + sizeof(*hdr) > RBF_NODE_SIZE) {
		nt_error("too big message frame. %d\n", size);
		return -EINVAL;
	}

	node = kmalloc(sizeof(nmsg_node_t), GFP_ATOMIC);
	if(!node) {
		nt_error("not enough mem.\n");
		return -ENOMEM;
	}
	spin_lock_bh(&cur_msgq->lock);
	cur_msgq->count ++;
	list_add(&node->head, &cur_msgq->list);
	spin_unlock_bh(&cur_msgq->lock);


	node->buff_size = size + sizeof(*hdr);
	memcpy(node->buff, hdr, sizeof(*hdr));
	memcpy(node->buff + sizeof(*hdr), buf_in, size);

	/* raise the wq */
	queue_work_on(KEY_TO_CORE(key), nmsg_wq, &cur_msgq->wq_msg);
	return 0;
}

static int nmsg_fill_buffer(rbf_t *rbfp, nmsg_node_t *node)
{
	void *p = rbf_get_buff(rbfp);
	if (!p) {
		nt_debug("message ring full...\n");
		rbf_dump(rbfp);
		return -ENOMEM;
	}
	memcpy(p, node->buff, node->buff_size);
	rbf_release_buff(rbfp);
	return 0;
}

static int nmsg_dequeue(void)
{
	nt_mqueue_t *cur_msgq = nmsg_target_cpu(smp_processor_id());
	nmsg_node_t *node;

	if (list_empty(&cur_msgq->list)) {
		return -1;
	}

	spin_lock_bh(&cur_msgq->lock);
	if ((node = list_first_entry_or_null(&cur_msgq->list, nmsg_node_t, head)) != NULL) {
		nmsg_fill_buffer(cur_msgq->rbfp, node);
		cur_msgq->count --;
		list_del(&node->head);
		kfree(node);
	}
	spin_unlock_bh(&cur_msgq->lock);
	return 0;
}

static void nmsg_wq_dequeue_func(struct work_struct *wq)
{
	int count = 0;

	while(nmsg_dequeue() == 0) {
		count ++;
	}

	if(count > 1) {
		nt_debug("[%d] - dequeue %d messages.\n", smp_processor_id(), count);
	}
}
