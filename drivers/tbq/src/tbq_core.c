#include "tbq.h"

#define DRV_VERSION	"0.1.1"
#define DRV_DESC	"tolken buffer queue driver"

struct tbq_global tbq;


void tbq_timer_func(unsigned long data);


static void tbq_backlog_init(struct tbq_backlog *tb, uint8_t weight)
{
	INIT_LIST_HEAD(&tb->list);
	tb->tc = NULL;
	tb->octets = 0;
	tb->weight = weight;
}

static int tbq_backlog_empty(struct tbq_backlog *tb)
{
	if (list_empty(&tb->list)) {
		BUG_ON(tb->tc != NULL);
		BUG_ON(tb->octets != 0);
		return 1;
	}
	BUG_ON(tb->tc == NULL);
	BUG_ON(tb->octets == 0);
	return 0;
}

static void tbq_flow_backlog_init(
	struct tbq_flow_backlog *fb,
	struct tbq_flow_track *tf)
{
	tbq_backlog_init(&fb->base, 0);
	INIT_LIST_HEAD(&fb->packets);
	fb->tf = tf;
}

static int tbq_flow_backlog_empty(struct tbq_flow_backlog *fb)
{
	if (tbq_backlog_empty(&fb->base)) {
		BUG_ON(!list_empty(&fb->packets));
		return 1;
	}
	BUG_ON(list_empty(&fb->packets));
	return 0;
}

static void tbq_flow_track_init(struct tbq_flow_track *tf)
{
	struct nos_track *nos = container_of(tf, struct nos_track, tbq);
	TBQ_DEBUG("flow track init: %d %pI4h:%hu => %pI4h:%hu\n",
		(int)nos->flow->tuple.proto,
		&nos->flow->tuple.ip_src, nos->flow->tuple.port_src,
		&nos->flow->tuple.ip_dst, nos->flow->tuple.port_dst);

	list_add(&tf->list, &tbq.flows);
	tf->app_id = 0;
	tf->rule_mask = 0;
	memset(tf->weight, 0, sizeof(tf->weight));
	tbq_flow_backlog_init(&tf->backlog[0], tf);
	tbq_flow_backlog_init(&tf->backlog[1], tf);
}

static void tbq_flow_track_cleanup(struct tbq_flow_track *tf)
{
	struct nos_track *nos = container_of(tf, struct nos_track, tbq);
	TBQ_DEBUG("flow track cleanup: %d %pI4h:%hu => %pI4h:%hu\n",
		(int)nos->flow->tuple.proto,
		&nos->flow->tuple.ip_src, nos->flow->tuple.port_src,
		&nos->flow->tuple.ip_dst, nos->flow->tuple.port_dst);

	list_del(&tf->list);
	BUG_ON(!tbq_flow_backlog_empty(&tf->backlog[0]));
	BUG_ON(!tbq_flow_backlog_empty(&tf->backlog[1]));
	memset(tf, 0, sizeof(struct tbq_flow_track));
}

static inline int match_iface(const char *name, struct tbq_iface *iface) {
	int i = 0;

	BUG_ON(!name);
	for (; i < iface->cur; i++) {
		if (!strcmp(iface->ifname[i], name))
			return 1;
	}

	return 0;
}

static inline int tbq_get_packet_dir(
	const struct sk_buff *skb,
	const struct net_device *in,
	const struct net_device *out)
{
	int lan_in, lan_out;

// #ifdef CONFIG_BRIDGE_NETFILTER
// 	if (skb->nf_bridge) {
// 		in = skb->nf_bridge->physindev;
// 		out = skb->nf_bridge->physoutdev;
// 	}
// #endif

	lan_in = match_iface(in->name, &tbq.config.lan);
	if (lan_in) {
		lan_out = match_iface(out->name, &tbq.config.wan);
		if (lan_out)
			return 0; 	// LAN TO WAN
		/*
		lan_out = match_iface(out->name, &tbq.config.lan); // TODO
		if (lan_out)
			return -1;	// LAN TO LAN
		printk("miss match %s -> %s\n", in->name, out->name);
		*/
		return -1;
	}

	// WAN -> ?
	lan_out = match_iface(out->name, &tbq.config.lan);
	if (lan_out)
		return 1; 	// WAN TO LAN

	/*
	lan_in = match_iface(out->name, &tbq.config.wan);
	if (lan_in)
		return -1; 	// WAN TO WAN

	printk("miss match 2 %s -> %s\n", in->name, out->name);
	*/
	return -1;
	/*
	lan_in = strncmp(in->name, "br", 2) == 0;
	lan_out = strncmp(out->name, "br", 2) == 0;
	if (lan_in) {
		if (lan_out)
			return -1;	// LAN TO LAN
		return 0;		// LAN TO WAN
	} else {
		if (lan_out)
			return 1;	// WAN TO LAN
		return -1;		// WAN TO WAN
	}
	return -1;
	*/
}

static inline uint32_t tbq_get_packet_length(const struct sk_buff *skb)
{
#ifdef TBQ_DEBUG_CONTROL_PPS
	return 1;
#elif 1
	return skb->len;
#else
	uint32_t pkt_len;
	struct tcphdr *tcph;
	struct iphdr *iph = ip_hdr(skb);
	uint32_t iphdr_len = iph->ihl << 2;
	switch (iph->protocol){
	case IPPROTO_TCP:
		tcph = (struct tcphdr *)((char *)iph + iphdr_len);
		pkt_len = skb->len - iphdr_len - (tcph->doff << 2);
		break;
	case IPPROTO_UDP:
		pkt_len = skb->len - iphdr_len - sizeof(struct udphdr);
		break;
	default:
		pkt_len = 0;
	}
	// TODO
	return pkt_len != 0 ? pkt_len : 1;
#endif
}

static inline struct tbq_user *tbq_token_ctrl_user(struct tbq_token_ctrl *tc)
{
	if (unlikely(tc == &tc->bucket->tc))
		return NULL;
	return container_of(tc, struct tbq_user, tc);
}

void tbq_token_ctrl_init(
	struct tbq_token_ctrl *tc,
	struct tbq_bucket *bucket,
	struct tbq_token_config *config)
{
	tc->bucket = bucket;
	tc->tokens = 0;
	tc->jiffies = jiffies;
	tc->config = *config;
	INIT_LIST_HEAD(&tc->list);
	INIT_LIST_HEAD(&tc->backlog.units);
	tc->backlog.octets = 0;
	tc->backlog.weight = 0;
}

void tbq_token_ctrl_assert_unused(struct tbq_token_ctrl *tc)
{
	BUG_ON(!list_empty(&tc->list));
	BUG_ON(!list_empty(&tc->backlog.units));
	BUG_ON(tc->backlog.octets != 0);
	BUG_ON(tc->backlog.weight != 0);
}

static void tbq_token_ctrl_dump(struct tbq_token_ctrl *tc)
{
	printk("~~~~~ TC DUMP: %p@[%s] ~~~~~\n"
		"tokens:          %d\n"
		"bytes per jiffy: %d\n"
		"pending:         %d\n"
		"backlog empty:   %d\n"
		"backlog octets:  %u\n"
		"backlog weight:  %u\n"
		"~~~~~ TC DUMP END ~~~~~\n",
		tc, tc->bucket->name,
		tc->tokens,
		tc->config.tokens_per_jiffy,
		!list_empty(&tc->list),
		list_empty(&tc->backlog.units),
		tc->backlog.octets,
		tc->backlog.weight);
}

void tbq_timer_assert_unused(struct tbq_timer *timer)
{
	int i;

	for (i = 0; i <= TBQ_TIMER_VEC_MASK; i++) {
		BUG_ON(!list_empty(timer->vec + i));
	}

	BUG_ON(timer->nr_pending != 0);
}

void tbq_timer_init(struct tbq_timer *timer)
{
	int i;

	for (i = 0; i <= TBQ_TIMER_VEC_MASK; i++) {
		INIT_LIST_HEAD(timer->vec + i);
	}

	timer->jiffies = jiffies;
	timer->nr_pending = 0;

	setup_timer(&timer->ktimer, tbq_timer_func, 0);
	mod_timer(&timer->ktimer, jiffies + TBQ_TIMER_INTERVAL);
}

void tbq_timer_cleanup(struct tbq_timer *timer)
{
	tbq_timer_assert_unused(timer);
	del_timer_sync(&timer->ktimer);
}

static void tbq_timer_mod(
	struct tbq_timer *timer,
	struct tbq_token_ctrl *tc,
	unsigned long expire_jiffies)
{
	struct list_head *vec_list;

	vec_list = timer->vec + (expire_jiffies & TBQ_TIMER_VEC_MASK);

	list_add_tail(&tc->list, vec_list);
	timer->nr_pending++;
}

static void tbq_timer_del(
	struct tbq_timer *timer,
	struct tbq_token_ctrl *tc)
{
	BUG_ON(tc->tokens < 0);
	BUG_ON(list_empty(&tc->list));

	// remove tc from tbq_timer
	list_del_init(&tc->list);
	timer->nr_pending--;
}

void tbq_token_ctrl_deactivate(struct tbq_token_ctrl *tc)
{
	int32_t tokens_per_jiffy;
	unsigned long expire_jiffies;
	unsigned long active_jiffies;

	BUG_ON(tc->tokens >= 0);
	BUG_ON(!list_empty(&tc->list));
	//BUG_ON(!list_empty(&tc->backlog.units));

	tokens_per_jiffy = tc->config.tokens_per_jiffy;
	expire_jiffies = (-tc->tokens + tokens_per_jiffy - 1) / tokens_per_jiffy;
	active_jiffies = jiffies + expire_jiffies;

	tc->tokens += expire_jiffies * tokens_per_jiffy;
	tc->jiffies = active_jiffies;

	tbq_timer_mod(&tbq.timer, tc, active_jiffies);
}

int tbq_token_ctrl_feed(struct tbq_token_ctrl *tc)
{
	unsigned long current_jiffies;
	unsigned long feed_jiffies;
	int32_t feed_tokens;
	int32_t tokens_after_feed;

	BUG_ON(tc->tokens >= 0);

	current_jiffies = jiffies;

	feed_jiffies = current_jiffies - tc->jiffies;

	// TODO: just ignore the rarely case of jiffies wrapping ?
	if (feed_jiffies == 0)
		return 0;

	if (feed_jiffies > HZ)
		feed_jiffies = HZ;

	feed_tokens = tc->config.tokens_per_jiffy * feed_jiffies;
	BUG_ON(feed_tokens <= 0);

	tokens_after_feed = tc->tokens + feed_tokens;
	if (tokens_after_feed < 0)
		return 0;

	tc->tokens = tokens_after_feed;
	tc->jiffies = current_jiffies;
	return 1;
}

int tbq_token_ctrl_consume(
	struct tbq_token_ctrl *tc,
	uint32_t pkt_len)
{
	BUG_ON(tc->tokens < 0);
	BUG_ON(!list_empty(&tc->list));
	tc->tokens -= pkt_len;
	return tc->tokens >= 0 || tbq_token_ctrl_feed(tc);
}

void tbq_user_init(
	struct tbq_user *user,
	struct tbq_user_sched *sched,
	struct tbq_bucket *bucket,
	uint8_t weight)
{
	TBQ_DEBUG("user init: %pI4h@[%s], bpj: %d, weight: %u\n",
		&sched->ip, bucket->name,
		bucket->user_tc_config.tokens_per_jiffy, (uint32_t)weight);
	BUG_ON(weight == 0);
	user->sched = sched;
	tbq_token_ctrl_init(&user->tc, bucket, &bucket->user_tc_config);
	tbq_backlog_init(&user->backlog, weight);
}

void tbq_user_cleanup(struct tbq_user *user)
{
	tbq_token_ctrl_assert_unused(&user->tc);
	BUG_ON(!tbq_backlog_empty(&user->backlog));
}

void tbq_user_sched_init(
	struct tbq_user_sched *us,
	struct tbq_bucket_sched *bs,
	uint32_t ip,
	uint32_t rule_mask,
	uint8_t *weight)
{
	int i;

	us->ip = ip;
	us->inactive_mask = 0;

	TBQ_RULE_MASK_FOR_EACH(i, rule_mask) {
		tbq_user_init(&us->users[i], us, &bs->buckets[i], weight[i]);
	}
}

void tbq_user_sched_cleanup(
	struct tbq_user_sched *us,
	uint32_t rule_mask)
{
	int i;

	if (us->inactive_mask != 0) {
		TBQ_DEBUG("user unclean: %pI4h, inactive_mask: %08X\n", &us->ip, us->inactive_mask);
		TBQ_RULE_MASK_FOR_EACH(i, us->inactive_mask) {
			tbq_timer_del(&tbq.timer, &us->users[i].tc);
		}
	}

	BUG_ON(us->inactive_mask != 0);

	TBQ_RULE_MASK_FOR_EACH(i, rule_mask) {
		tbq_user_cleanup(&us->users[i]);
	}
}

static int tbq_rule_match_ip(const struct tbq_rule *rule, uint32_t ip)
{
	int i;

	if (rule->nr_ip_rule == 0)
		return 1;

	for (i = 0; i < rule->nr_ip_rule; i++) {
		struct tbq_ip_rule *ip_rule = &rule->ip_rules[i];
		if (ip >= ip_rule->min && ip <= ip_rule->max) {
			return ip_rule->weight;
		}
	}

	return 0;
}

static uint32_t tbq_user_match(struct nos_user_track *ut, uint8_t *weight)
{
	uint32_t rule_mask = 0;
	int i;

	for (i = 0; i < tbq.config.nr_rule; i++) {
		const struct tbq_rule *rule = &tbq.config.rules[i];
		weight[i] = tbq_rule_match_ip(rule, ut->ip);
		if (weight[i] != 0) {
			TBQ_RULE_MASK_SET(rule_mask, i);
		}
	}

	return rule_mask;
}

struct tbq_user_track *tbq_user_track_alloc(struct nos_user_track *ut)
{
	struct tbq_user_track *tu;
	uint8_t weight[TBQ_RULE_COUNT_MAX];

	tu = TBQ_NEW(struct tbq_user_track);
	if (tu == NULL) {
		TBQ_ERROR("out of tbq_user_track\n");
		return NULL;
	}

	ut->tbq = tu;
	tu->ut = ut;
	list_add_tail(&tu->list, &tbq.users);
	tu->rule_mask = tbq_user_match(ut, weight);
	tbq_user_sched_init(&tu->sched[0], &tbq.sched[0], ut->ip, tu->rule_mask, weight);
	tbq_user_sched_init(&tu->sched[1], &tbq.sched[1], ut->ip, tu->rule_mask, weight);
	TBQ_DEBUG("add user: %pI4h, rule_mask: %08X\n", &ut->ip, tu->rule_mask);
	return tu;
}

void tbq_user_track_free(struct tbq_user_track *tu)
{
	TBQ_DEBUG("del user: %pI4h, rule_mask: %08X\n", &tu->ut->ip, tu->rule_mask);
	BUG_ON(tu->ut->tbq != tu);
	tu->ut->tbq = NULL;
	list_del(&tu->list);
	tbq_user_sched_cleanup(&tu->sched[0], tu->rule_mask);
	tbq_user_sched_cleanup(&tu->sched[1], tu->rule_mask);
	kfree(tu);
}

static inline int tbq_bucket_index(struct tbq_bucket *bucket)
{
	int index = bucket - bucket->sched->buckets;
	BUG_ON(index < 0);
	BUG_ON(index >= tbq.config.nr_rule);
	return index;
}

void tbq_bucket_init(
	struct tbq_bucket *bucket,
	const char *name,
	int pkt_dir,
	struct tbq_bucket_sched *sched,
	struct tbq_token_rule *token_rule)
{
	TBQ_DEBUG("init bucket [%s]\n", name);

	bucket->name = name;
	bucket->pkt_dir = pkt_dir;
	bucket->sched = sched;

	tbq_token_ctrl_init(&bucket->tc, bucket, &token_rule->global);

	bucket->user_tc_config = token_rule->user;
}

void tbq_bucket_cleanup(struct tbq_bucket *bucket)
{
	TBQ_DEBUG("cleanup bucket [%s]\n", bucket->name);

	tbq_token_ctrl_assert_unused(&bucket->tc);
}

void tbq_user_consume(struct tbq_user *user, uint32_t pkt_len)
{
	struct tbq_bucket *bucket = user->tc.bucket;
	int bucket_index = tbq_bucket_index(bucket);
	int active;

	active = tbq_token_ctrl_consume(&bucket->tc, pkt_len);
	if (!active) {
		TBQ_RULE_MASK_SET(bucket->sched->inactive_mask, bucket_index);
		tbq_token_ctrl_deactivate(&bucket->tc);
	}

	active = tbq_token_ctrl_consume(&user->tc, pkt_len);
	if (!active) {
		TBQ_RULE_MASK_SET(user->sched->inactive_mask, bucket_index);
		tbq_token_ctrl_deactivate(&user->tc);
	}
}

void tbq_user_backlog_update(struct tbq_user *user, int32_t pkt_len, int weight)
{
	struct tbq_bucket *bucket = user->tc.bucket;

	bucket->tc.backlog.octets += pkt_len;

	if (user->tc.backlog.octets == 0) {
		BUG_ON(user->tc.backlog.weight != 0);
		BUG_ON(weight <= 0);
		BUG_ON(pkt_len <= 0);
		bucket->tc.backlog.weight += user->backlog.weight;
	}

	user->tc.backlog.octets += pkt_len;
	user->tc.backlog.weight += weight;

	if (user->tc.backlog.octets == 0) {
		BUG_ON(user->tc.backlog.weight != 0);
		BUG_ON(weight >= 0);
		BUG_ON(pkt_len >= 0);
		bucket->tc.backlog.weight -= user->backlog.weight;
	}
}

void tbq_packet_ctrl_backlog_update(
	struct tbq_packet_ctrl *pc,
	int32_t pkt_len,
	struct tbq_flow_backlog *fb)
{
	uint32_t rule_mask = pc->rule_mask;
	int i;

	TBQ_RULE_MASK_FOR_EACH(i, rule_mask) {
		struct tbq_user *user = &pc->user_sched->users[i];
		int weight = 0;
		if (fb != NULL) {
			weight = fb->tf->weight[i];
			if (pkt_len < 0)
				weight = -weight;
		}
		tbq_user_backlog_update(user, pkt_len, weight);
	}
}

struct tbq_user *tbq_packet_ctrl_consume(struct tbq_packet_ctrl *pc)
{
	uint32_t rule_mask = pc->rule_mask;
	uint32_t pending_mask;
	int i;

	pending_mask = pc->bucket_sched->inactive_mask & rule_mask;
	if (pending_mask != 0)
		goto pending;

	pending_mask = pc->user_sched->inactive_mask & rule_mask;
	if (pending_mask != 0)
		goto pending;

	TBQ_RULE_MASK_FOR_EACH(i, rule_mask) {
		struct tbq_user *user = &pc->user_sched->users[i];
		tbq_user_consume(user, pc->pkt_len);
	}

	return NULL;

pending:
	return &pc->user_sched->users[__builtin_ffs(pending_mask) - 1];
}

int tbq_filter_packet(struct sk_buff *skb, struct nos_track *nos, int pkt_dir)
{
	struct nos_user_track *ut;
	struct tbq_user_track *tu;
	struct tbq_flow_track *tf;
	struct tbq_packet_ctrl *pc;
	struct tbq_flow_backlog *fb;

	ut = nos_get_user_track(nos);
	tu = ut->tbq;
	tf = &nos->tbq;

	if (tu == NULL) {
		tu = tbq_user_track_alloc(ut);
		if (tu == NULL)
			return NF_ACCEPT;
	}

	if (tf->list.next == NULL) {
		tbq_flow_track_init(tf);
	}

	if (tf->app_id != nos->flow->tuple.proto) {
		tf->app_id = nos->flow->tuple.proto;
		tf->rule_mask = tbq_app_match(tf->app_id, tu->rule_mask, tf->weight);
		TBQ_DEBUG("flow track: %p, app_id: %hu, rule_mask: %u\n",
			tf, tf->app_id, tf->rule_mask);
	}

	if (tf->rule_mask == 0) {
		return NF_ACCEPT;
	}

	pc = tbq_packet_ctrl_get(skb);
	pc->bucket_sched = &tbq.sched[pkt_dir];
	pc->user_sched = &tu->sched[pkt_dir];
	pc->rule_mask = tf->rule_mask;
	pc->pkt_len = tbq_get_packet_length(skb);

	fb = &tf->backlog[pkt_dir];
	if (tbq_flow_backlog_empty(fb)) {
		if (tbq_packet_ctrl_consume(pc) == NULL) {
			return NF_ACCEPT;
		}
	}

	if (tbq.backlog_packets >= tbq.config.max_backlog_packets) {
		TBQ_TRACE(FILTER, "drop: %pI4h, len: %u, rule_mask: %08X, dir: %d, backlog: %u/%u\n",
			&nos->ui_src->ip, pc->pkt_len, pc->rule_mask, pkt_dir,
			tbq.backlog_packets, tbq.config.max_backlog_packets);
		return NF_DROP;
	}

	return NF_QUEUE;
}


#if LINUX_VERSION_CODE < KERNEL_VERSION(3, 13, 0)
static unsigned tbq_nf_hook(unsigned int hooknum,
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out,
		int (*okfn)(struct sk_buff *))
{
#elif LINUX_VERSION_CODE < KERNEL_VERSION(4, 1, 0)
static unsigned int tbq_nf_hook(const struct nf_hook_ops *ops,
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out,
		int (*okfn)(struct sk_buff *))
{
	//unsigned int hooknum = ops->hooknum;
#elif LINUX_VERSION_CODE < KERNEL_VERSION(4, 4, 0)
static unsigned int tbq_nf_hook(const struct nf_hook_ops *ops,
		struct sk_buff *skb,
		const struct nf_hook_state *state)
{
	//unsigned int hooknum = state->hook;
	const struct net_device *in = state->in;
	const struct net_device *out = state->out;
#else
static unsigned int tbq_nf_hook(void *priv,
		struct sk_buff *skb,
		const struct nf_hook_state *state)
{
	//unsigned int hooknum = state->hook;
	const struct net_device *in = state->in;
	const struct net_device *out = state->out;
#endif
	struct nf_conn *ct = (struct nf_conn *)skb->nfct;
	struct nos_track *nos;
	int ret = NF_ACCEPT;
	int pkt_dir;

	if (ct == NULL) {
		TBQ_DEBUG("ct is NULL, protocol: %d\n", (int)ip_hdr(skb)->protocol);
		return NF_ACCEPT;
	}

	if (nf_ct_is_untracked(ct)) {
		TBQ_DEBUG("untracked ct, protocol: %d\n", (int)ip_hdr(skb)->protocol);
		return NF_ACCEPT;
	}

	switch (ip_hdr(skb)->protocol) {
	case IPPROTO_ICMP:
	case IPPROTO_TCP:
	case IPPROTO_UDP:
		break;
	default:
		TBQ_DEBUG("unsupported protocol: %d, ct: %p\n", (int)ip_hdr(skb)->protocol, ct);
		return NF_ACCEPT;
	}

	if ((nos = nf_ct_get_nos(ct)) == NULL) {
		return NF_ACCEPT;
	}

	if (nt_flow(nos) == NULL) {
		TBQ_DEBUG("nos_track is NULL\n");
		return NF_ACCEPT;
	}

	rcu_read_lock();
	if (tbq_status_is(TBQ_STATUS_RUNNING)) {
		pkt_dir = tbq_get_packet_dir(skb, in, out);
		if (pkt_dir != -1) {
			spin_lock_bh(&tbq.lock);
			ret = tbq_filter_packet(skb, nos, pkt_dir);
			spin_unlock_bh(&tbq.lock);
		}
	}
	rcu_read_unlock();

	return ret;
}

static int tbq_backlog_attached(struct tbq_backlog *tb)
{
	if (tb->tc != NULL) {
		BUG_ON(list_empty(&tb->list));
		return 1;
	}
	BUG_ON(!list_empty(&tb->list));
	return 0;
}

static uint32_t tbq_backlog_max_octets(
	struct tbq_backlog *tb,
	uint32_t parent_ceiling)
{
	uint32_t total_ceiling;
	uint32_t latency_ceiling;

	BUG_ON(!tbq_backlog_attached(tb));

	latency_ceiling = (tb->tc->config.tokens_per_jiffy << tbq.config.latency_shift);
	total_ceiling = min(parent_ceiling, latency_ceiling);

	return total_ceiling / tb->tc->backlog.weight * tb->weight +
		total_ceiling % tb->tc->backlog.weight * tb->weight / tb->tc->backlog.weight;
}

static void tbq_backlog_attach(struct tbq_backlog *tb, struct tbq_token_ctrl *tc)
{
	if (!tbq_backlog_attached(tb)) {
		BUG_ON(tc == NULL);
		list_add_tail(&tb->list, &tc->backlog.units);
		tb->tc = tc;
		tb->drr_deficit = tb->weight << TBQ_DRR_QUANTUM_SHIFT;
	}
}

static void tbq_backlog_detach(struct tbq_backlog *tb)
{
	if (tbq_backlog_attached(tb)) {
		tb->tc = NULL;
		list_del_init(&tb->list);
	}
}

static void tbq_backlog_enqueue(struct tbq_backlog *tb, uint32_t octets)
{
	tb->octets += octets;
}

static void tbq_backlog_dequeue(struct tbq_backlog *tb, uint32_t octets)
{
	BUG_ON(tb->octets < octets);

	tb->octets -= octets;

	if (tb->octets == 0) {
		tbq_backlog_detach(tb);
	}
}

static void tbq_backlog_drr_schedule(
	struct tbq_backlog *tb,
	uint32_t pkt_len)
{
	if (!tbq_backlog_attached(tb))
		return;

	tb->drr_deficit -= pkt_len;

	if (tb->drr_deficit < 0) {
		tb->drr_deficit += tb->weight << TBQ_DRR_QUANTUM_SHIFT;
		//BUG_ON(tb->drr_deficit < 0);
		if (tb->drr_deficit < 0 && net_ratelimit()) {
			TBQ_WARN("WARR: too length pkt: %d\n", pkt_len);
		}
		list_move_tail(&tb->list, &tb->tc->backlog.units);
	}
}

void tbq_flow_backlog_drr_schedule(
	struct tbq_flow_backlog *fb,
	uint32_t pkt_len)
{
	struct tbq_user *user;

	user = container_of(fb->base.tc, struct tbq_user, tc);
	tbq_backlog_drr_schedule(&user->backlog, pkt_len);
	tbq_backlog_drr_schedule(&fb->base, pkt_len);
}

void tbq_flow_backlog_attach(
	struct tbq_flow_backlog *fb,
	struct tbq_user *user)
{
	struct tbq_bucket *bucket = user->tc.bucket;

	BUG_ON(tbq_backlog_attached(&fb->base));

	if (!list_empty(&bucket->tc.list))
		goto attach_to_bucket;
	if (!list_empty(&user->tc.list))
		goto attach_to_user;

	BUG();

attach_to_bucket:
	tbq_backlog_attach(&user->backlog, &bucket->tc);
attach_to_user:
	tbq_backlog_enqueue(&user->backlog, fb->base.octets);
	tbq_backlog_attach(&fb->base, &user->tc);
	fb->base.weight = fb->tf->weight[tbq_bucket_index(bucket)];
}

void tbq_flow_backlog_detach(struct tbq_flow_backlog *fb)
{
	struct tbq_user *user;

	BUG_ON(!tbq_backlog_attached(&fb->base));

	user = container_of(fb->base.tc, struct tbq_user, tc);
	tbq_backlog_dequeue(&user->backlog, fb->base.octets);
	if (tbq_backlog_attached(&user->backlog)) {
		TBQ_INFO("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n");
	}
	//tbq_backlog_detach(&user->backlog);
	tbq_backlog_detach(&fb->base);
}

void tbq_flow_backlog_enqueue(
	struct tbq_flow_backlog *fb,
	struct nf_queue_entry *pkt,
	uint32_t pkt_len)
{
	struct tbq_user *user;

	BUG_ON(!tbq_backlog_attached(&fb->base));

	user = container_of(fb->base.tc, struct tbq_user, tc);
	tbq_backlog_enqueue(&user->backlog, pkt_len);
	tbq_backlog_enqueue(&fb->base, pkt_len);
	list_add_tail(&pkt->list, &fb->packets);
}

void tbq_flow_backlog_dequeue(
	struct tbq_flow_backlog *fb,
	struct nf_queue_entry *pkt,
	uint32_t pkt_len)
{
	struct tbq_user *user;

	BUG_ON(!tbq_backlog_attached(&fb->base));

	user = container_of(fb->base.tc, struct tbq_user, tc);
	tbq_backlog_dequeue(&user->backlog, pkt_len);
	tbq_backlog_dequeue(&fb->base, pkt_len);
	list_del(&pkt->list);
}

uint32_t tbq_flow_backlog_max_octets(struct tbq_flow_backlog *fb)
{
	uint32_t bucket_ceiling = ~0u;
	uint32_t user_ceiling = bucket_ceiling;
	struct tbq_user *user;

	user = container_of(fb->base.tc, struct tbq_user, tc);
	if (tbq_backlog_attached(&user->backlog)) {
		user_ceiling = tbq_backlog_max_octets(&user->backlog, bucket_ceiling);
	}

	return tbq_backlog_max_octets(&fb->base, user_ceiling);
}

void tbq_flow_backlog_drop(
	struct tbq_flow_backlog *fb,
	struct tbq_dequeue_info *dq)
{
	struct nf_queue_entry *pkt;
	struct tbq_packet_ctrl *pc;
	uint32_t max_octets;
	int flow_detach;

	max_octets = tbq_flow_backlog_max_octets(fb);
	//BUG_ON(max_octets == 0);

	while (fb->base.octets > max_octets) {
		pkt = list_entry(fb->packets.prev, struct nf_queue_entry, list);
		pc = tbq_packet_ctrl_get(pkt->skb);

		tbq_flow_backlog_dequeue(fb, pkt, pc->pkt_len);

		flow_detach = fb->base.octets == 0;
		tbq_packet_ctrl_backlog_update(pc, -(int32_t)pc->pkt_len, flow_detach ? fb : NULL);

		list_add_tail(&pkt->list, &dq->drop);
		dq->nr_drop++;
	}
}

int tbq_enqueue(struct nf_queue_entry *pkt, unsigned int queuenum)
{
	int ret = 0;
	int flow_attach = 0;
	int pkt_dir;
	struct nos_track *nos;
	struct tbq_packet_ctrl *pc;
	struct tbq_flow_backlog *fb;
	struct tbq_dequeue_info dq;
	struct tbq_user *pending_user;

	rcu_read_lock();

	if (!tbq_status_is(TBQ_STATUS_RUNNING)) {
		rcu_read_unlock();
		return -ECANCELED;
	}

	INIT_LIST_HEAD(&dq.send);
	INIT_LIST_HEAD(&dq.drop);
	dq.nr_send = 0;
	dq.nr_drop = 0;

	spin_lock_bh(&tbq.lock);

	nos = &((struct nf_conn *)pkt->skb->nfct)->nos_track;
	pc = tbq_packet_ctrl_get(pkt->skb);
	pkt_dir = pc->bucket_sched - tbq.sched;

	fb = &nos->tbq.backlog[pkt_dir];
	if (tbq_flow_backlog_empty(fb)) {
		pending_user = tbq_packet_ctrl_consume(pc);
		if (pending_user == NULL) {
			ret = -ECANCELED;
			goto out;
		}
		tbq_flow_backlog_attach(fb, pending_user);
		flow_attach = 1;
	} else {
		tbq_flow_backlog_drop(fb, &dq);
		if (dq.nr_drop != 0) {
			struct nf_queue_entry *pkt_next;
			tbq.backlog_packets -= dq.nr_drop;
			spin_unlock_bh(&tbq.lock);
			TBQ_TRACE(FILTER, "drop %d packets\n", dq.nr_drop);
			list_for_each_entry_safe(pkt, pkt_next, &dq.drop, list) {
				nf_reinject(pkt, NF_DROP);
			}
			rcu_read_unlock();
			return -EINVAL;
		}
	}

	tbq_flow_backlog_enqueue(fb, pkt, pc->pkt_len);
	tbq_packet_ctrl_backlog_update(pc, (int32_t)pc->pkt_len, flow_attach ? fb : NULL);
	tbq.backlog_packets++;

	TBQ_TRACE(FILTER, "enqueue: %pI4h, len: %u, rule_mask: %08X, dir: %d, backlog: %u/%u\n",
		&nos->ui_src->ip, pc->pkt_len, pc->rule_mask, pkt_dir,
		tbq.backlog_packets, tbq.config.max_backlog_packets);

out:
	spin_unlock_bh(&tbq.lock);
	rcu_read_unlock();
	return ret;
}

void tbq_flow_backlog_try_dequeue(
	struct tbq_flow_backlog *fb,
	struct tbq_dequeue_info *dq)
{
	int flow_detach;
	int pkt_dir;
	struct nf_queue_entry *pkt;
	struct nos_track *nos;
	struct tbq_packet_ctrl *pc;
	struct tbq_user *pending_user;

	BUG_ON(tbq_flow_backlog_empty(fb));

	tbq_flow_backlog_drop(fb, dq);
	if (tbq_flow_backlog_empty(fb)) {
		return;
	}

	pkt = list_first_entry(&fb->packets, struct nf_queue_entry, list);
	nos = &((struct nf_conn *)pkt->skb->nfct)->nos_track;
	pc = tbq_packet_ctrl_get(pkt->skb);
	pkt_dir = pc->bucket_sched - tbq.sched;

	BUG_ON(fb != &nos->tbq.backlog[pkt_dir]);
	BUG_ON(!list_empty(&fb->base.tc->list));

	pending_user = tbq_packet_ctrl_consume(pc);
	if (pending_user != NULL) {
		struct tbq_token_ctrl *old_tc = fb->base.tc;
		tbq_flow_backlog_detach(fb);
		tbq_flow_backlog_attach(fb, pending_user);
		BUG_ON(fb->base.tc == old_tc);
		// TODO: switch flow
		TBQ_DEBUG("flow %p switch from tc:%p@[%s] to tc:%p@[%s]\n",
			fb,	old_tc, old_tc->bucket->name, fb->base.tc, fb->base.tc->bucket->name);
		return;
	}

	tbq_flow_backlog_drr_schedule(fb, pc->pkt_len);
	tbq_flow_backlog_dequeue(fb, pkt, pc->pkt_len);

	flow_detach = fb->base.octets == 0;
	tbq_packet_ctrl_backlog_update(pc, -(int32_t)pc->pkt_len, flow_detach ? fb : NULL);

	list_add_tail(&pkt->list, &dq->send);
	dq->nr_send++;
}

void tbq_user_dequeue(struct tbq_user *user, struct tbq_dequeue_info *dq)
{
	struct tbq_bucket *bucket = user->tc.bucket;
	struct tbq_flow_backlog *fb;

	BUG_ON(!list_empty(&user->tc.list));

	while (list_empty(&user->tc.list) && !list_empty(&user->tc.backlog.units)) {
		if (list_empty(&bucket->tc.list)) {
			fb = list_first_entry(&user->tc.backlog.units, struct tbq_flow_backlog, base.list);
			BUG_ON(fb->base.tc != &user->tc);
			tbq_flow_backlog_try_dequeue(fb, dq);
		} else {
			tbq_backlog_attach(&user->backlog, &bucket->tc);
			break;
		}
	}
}

void tbq_bucket_dequeue(struct tbq_bucket *bucket, struct tbq_dequeue_info *dq)
{
	struct tbq_backlog *ub;
	struct tbq_flow_backlog *fb;
	struct tbq_user *user;

	BUG_ON(!list_empty(&bucket->tc.list));

	while (list_empty(&bucket->tc.list) && !list_empty(&bucket->tc.backlog.units)) {
		ub = list_first_entry(&bucket->tc.backlog.units, struct tbq_backlog, list);
		BUG_ON(ub->tc != &bucket->tc);
		BUG_ON(tbq_backlog_empty(ub));
		user = container_of(ub, struct tbq_user, backlog);
		if (list_empty(&user->tc.list)) {
			fb = list_first_entry(&user->tc.backlog.units, struct tbq_flow_backlog, base.list);
			BUG_ON(fb->base.tc != &user->tc);
			tbq_flow_backlog_try_dequeue(fb, dq);
		} else {
			tbq_backlog_detach(&user->backlog);
		}
	}
}

void tbq_token_ctrl_activate(
	struct tbq_token_ctrl *tc,
	struct tbq_dequeue_info *dq)
{
	struct tbq_user *user;
	struct tbq_bucket *bucket;
	int bucket_index;

	tbq_timer_del(&tbq.timer, tc);

	user = tbq_token_ctrl_user(tc);
	bucket = tc->bucket;
	bucket_index = tbq_bucket_index(bucket);
	if (user != NULL) {
		TBQ_RULE_MASK_CLR(user->sched->inactive_mask, bucket_index);
		if (!tbq_backlog_attached(&user->backlog))
			tbq_user_dequeue(user, dq);
		else
			TBQ_DEBUG("skip user dequeue: %p@[%s]\n", tc, tc->bucket->name);
	} else {
		TBQ_RULE_MASK_CLR(bucket->sched->inactive_mask, bucket_index);
		tbq_bucket_dequeue(bucket, dq);
	}
}

void tbq_timer_feed(struct tbq_timer *timer, struct tbq_dequeue_info *dq)
{
	struct list_head *vec_list;
	struct list_head work_list;
	struct tbq_token_ctrl *tc, *next_tc;
	unsigned long vec_jiffies;

	long delay = jiffies - timer->jiffies;
	TBQ_TRACE_IF(TIMER, delay != 0, "timer delay: %ld\n", delay);

	while (time_before_eq(timer->jiffies, jiffies)) {
		vec_list = timer->vec + (timer->jiffies++ & TBQ_TIMER_VEC_MASK);
		if (!list_empty(vec_list)) {
			list_replace_init(vec_list, &work_list);
			BUG_ON(!list_empty(vec_list));
			vec_jiffies = timer->jiffies - 1;
			list_for_each_entry_safe(tc, next_tc, &work_list, list) {
				if (tc->jiffies == vec_jiffies) {
					tbq_token_ctrl_activate(tc, dq);
				} else {
					TBQ_INFO("delayed timer execute\n");
					list_add_tail(&tc->list, vec_list);
				}
			}
		}
	}
}

void tbq_timer_func(unsigned long data)
{
	struct tbq_dequeue_info dq;
	struct nf_queue_entry *pkt, *pkt_next;

	rcu_read_lock();

	INIT_LIST_HEAD(&dq.send);
	INIT_LIST_HEAD(&dq.drop);
	dq.nr_send = 0;
	dq.nr_drop = 0;

	spin_lock_bh(&tbq.lock);
	tbq_timer_feed(&tbq.timer, &dq);
	tbq.backlog_packets -= dq.nr_send + dq.nr_drop;
	spin_unlock_bh(&tbq.lock);

	// TODO: packets may be sent out of order in tbq_filter_packet
	list_for_each_entry_safe(pkt, pkt_next, &dq.send, list) {
		nf_reinject(pkt, NF_ACCEPT);
	}
	list_for_each_entry_safe(pkt, pkt_next, &dq.drop, list) {
		nf_reinject(pkt, NF_DROP);
	}

	if (tbq_status_is(TBQ_STATUS_WAITING_STOP)) {
		if (tbq.timer.nr_pending == 0) {
			tbq_timer_assert_unused(&tbq.timer);
			complete(&tbq.disable_done);
			TBQ_INFO("notify disable done in timer func\n");
		}
	}

	rcu_read_unlock();
	mod_timer(&tbq.timer.ktimer, jiffies + TBQ_TIMER_INTERVAL);
}

void tbq_bucket_sched_init(
	struct tbq_bucket_sched *sched,
	struct tbq_rule *rules,
	const uint32_t nr_rule,
	const int pkt_dir)
{
	int i;

	BUG_ON(nr_rule > TBQ_RULE_COUNT_MAX);

	sched->inactive_mask = 0;

	for (i = 0; i < nr_rule; i++) {
		struct tbq_rule *r = &rules[i];
		tbq_bucket_init(&sched->buckets[i], r->name, pkt_dir, sched, &r->token_rules[pkt_dir]);
	}
}

void tbq_bucket_sched_cleanup(struct tbq_bucket_sched *sched)
{
	int i;

	if (sched->inactive_mask != 0) {
		printk("inactive_mask: %08X\n", sched->inactive_mask);
		TBQ_RULE_MASK_FOR_EACH(i, sched->inactive_mask) {
			tbq_token_ctrl_dump(&sched->buckets[i].tc);
		}
		BUG();
	}

	for (i = 0; i < tbq.config.nr_rule; i++) {
		tbq_bucket_cleanup(&sched->buckets[i]);
	}
}

void tbq_global_set_config(struct tbq_config *config)
{
	struct tbq_user_track *tu;
	struct tbq_flow_track *tf;
	int pkt_dir;

	BUG_ON(!tbq_status_is(TBQ_STATUS_STOPPED));
	BUG_ON(tbq.backlog_packets != 0);

	spin_lock_bh(&tbq.lock);
	while (!list_empty(&tbq.users)) {
		tu = list_first_entry(&tbq.users, struct tbq_user_track, list);
		tbq_user_track_free(tu);
		spin_unlock_bh(&tbq.lock);
		spin_lock_bh(&tbq.lock);
	}
	spin_unlock_bh(&tbq.lock);

	spin_lock_bh(&tbq.lock);
	while (!list_empty(&tbq.flows)) {
		tf = list_first_entry(&tbq.flows, struct tbq_flow_track, list);
		tbq_flow_track_cleanup(tf);
		spin_unlock_bh(&tbq.lock);
		spin_lock_bh(&tbq.lock);
	}
	spin_unlock_bh(&tbq.lock);

	for (pkt_dir = 0; pkt_dir <= 1; pkt_dir++) {
		tbq_bucket_sched_cleanup(&tbq.sched[pkt_dir]);
	}
	tbq_config_cleanup(&tbq.config);

	if (config == NULL)
		return;

	tbq.config = *config;
	for (pkt_dir = 0; pkt_dir <= 1; pkt_dir++) {
		tbq_bucket_sched_init(&tbq.sched[pkt_dir], config->rules, config->nr_rule, pkt_dir);
	}
}

void tbq_global_init(void)
{
	memset(&tbq, 0, sizeof(tbq));

	tbq.config.max_backlog_packets = 10000;
	tbq.config.latency_shift = 7;
	tbq.config.disable_timeout = 2;

	INIT_LIST_HEAD(&tbq.users);
	INIT_LIST_HEAD(&tbq.flows);
	spin_lock_init(&tbq.lock);
	tbq_status_set(TBQ_STATUS_RUNNING);
	init_completion(&tbq.disable_done);
	tbq_timer_init(&tbq.timer);
}

void tbq_global_cleanup(void)
{
	tbq_timer_cleanup(&tbq.timer);
	tbq_global_set_config(NULL);
}

void tbq_on_user_free(struct nos_user_track *ut)
{
	spin_lock_bh(&tbq.lock);
	if (ut->tbq != NULL) {
		tbq_user_track_free(ut->tbq);
	}
	spin_unlock_bh(&tbq.lock);
}

void tbq_on_flow_free(struct tbq_flow_track *tf)
{
	spin_lock_bh(&tbq.lock);
	if (tf->list.next != NULL) {
		tbq_flow_track_cleanup(tf);
	}
	spin_unlock_bh(&tbq.lock);
}

static void tbq_nf_queue_drop(struct net *net, struct nf_hook_ops *hook)
{
	//TODO: flush queue skbs
}

static struct nos_track_event tbq_nos_track_event = {
	.on_user_free = tbq_on_user_free,
	.on_flow_free = tbq_on_flow_free,
};

static const struct nf_queue_handler tbq_nf_queue = {
	.outfn	= tbq_enqueue,
	.nf_hook_drop = tbq_nf_queue_drop,
};

static struct nf_hook_ops tbq_nf_hook_ops[] = {
	{
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 4, 0)
		.owner = THIS_MODULE,
#endif
		.hook = tbq_nf_hook,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_FORWARD,
		.priority = NF_IP_PRI_LAST,
	},
};

static int __init nos_tbq_init(void)
{
	int ret = 0;

	TBQ_INFO("tbq_token_ctrl size:   %zu\n", sizeof(struct tbq_token_ctrl));
	TBQ_INFO("tbq_user size:         %zu\n", sizeof(struct tbq_user));
	TBQ_INFO("tbq_user_sched size:   %zu\n", sizeof(struct tbq_user_sched));
	TBQ_INFO("tbq_bucket size:       %zu\n", sizeof(struct tbq_bucket));
	TBQ_INFO("tbq_bucket_sched size: %zu\n", sizeof(struct tbq_bucket_sched));
	TBQ_INFO("nf_conn size:          %zu\n", sizeof(struct nf_conn));
	TBQ_INFO("sk_buff size:          %zu\n", sizeof(struct sk_buff));

	TBQ_INFO("TBQ_BACKLOG_PACKETS_MAX:	%d\n", TBQ_BACKLOG_PACKETS_MAX);
	TBQ_INFO("TBQ_LATENCY_SHIFT_MAX:	%d\n", TBQ_LATENCY_SHIFT_MAX);
	TBQ_INFO("TBQ_DISABLE_TIMEOUT_MAX:	%d\n", TBQ_DISABLE_TIMEOUT_MAX);

	TBQ_INFO("HZ: %d\n", HZ);

	tbq_global_init();

	nos_track_event_register(&tbq_nos_track_event);

	ret = tbq_sysfs_register();
	if (ret != 0) {
		goto cleanup_global;
	}

	nf_register_queue_handler(&tbq_nf_queue);

	ret = nf_register_hooks(tbq_nf_hook_ops, ARRAY_SIZE(tbq_nf_hook_ops));
	if (ret != 0) {
		TBQ_ERROR("nf_register_hook failed: %d\n", ret);
		goto unregister_queue_handler;
	}

	TBQ_INFO("nos_tbq_init() OK\n");
	return 0;

unregister_queue_handler:
	nf_unregister_queue_handler();
	tbq_sysfs_unregister();
cleanup_global:
	nos_track_event_unregister(&tbq_nos_track_event);
	tbq_global_cleanup();
	return ret;
}

static void __exit nos_tbq_fini(void)
{
	tbq_sysfs_unregister();
	nf_unregister_hooks(tbq_nf_hook_ops, ARRAY_SIZE(tbq_nf_hook_ops));
	nf_unregister_queue_handler();
	nos_track_event_unregister(&tbq_nos_track_event);
	tbq_global_cleanup();
	TBQ_INFO("nos_tbq_fini() OK\n");
}

module_init(nos_tbq_init);
module_exit(nos_tbq_fini);

MODULE_DESCRIPTION(DRV_DESC);
MODULE_VERSION(DRV_VERSION);
MODULE_AUTHOR("Gabor Juhos <juhosg@openwrt.org>");
MODULE_LICENSE("GPL v2");
