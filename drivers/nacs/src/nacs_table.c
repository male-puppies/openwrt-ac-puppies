/*
*this file contains three functions mainly, eg, set/get/query table
*set:update set and rule of control and audit
*get:fetch set and rule of control and audit
*query:check set and rule of control and audit, and generate check result
*/
#include <linux/err.h>
#include <linux/spinlock.h>
#include <linux/rwlock.h>
#include <linux/export.h>
#include <asm/uaccess.h>
#include <linux/vmalloc.h>
#include <linux/mm.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/mutex.h>
#include <linux/netfilter/ipset/ip_set.h>
#include <linux/netdevice.h>
#include "nacs_table.h"
#include "rule_table.h"
#include "nacs_debug.h"
#include "nacs_comm.h"

/*just for test, it will be removed*/
#include "rule_parse.h"

/*todo:support update*/
uint8_t cur_loglevel = NACS_ALL_LVL;

/*nac_mutex syn access to nac_table*/
static DEFINE_MUTEX(nac_mutex);
static struct ac_table nac_table = {
		.me = THIS_MODULE,
};


/*Notice:In process context, before we access nac_table, we need hold a lock*/
static struct ac_table* get_table_withlock(void) 
{
	mutex_lock(&nac_mutex);
	return &nac_table;
}


static void table_unlock(void)
{
	mutex_unlock(&nac_mutex);
}


static char flow_match_map[AC_FLOW_TYPE_MAX][AC_FLOW_MATCH_KEY_MAXLEN + 1]= {
	AC_RULE_SRC_ZONEIDS_KEY, AC_RULE_SRC_IPGRPIDS_KEY,
	AC_RULE_DST_ZONEIDS_KEY, AC_RULE_DST_IPGRPIDS_KEY
};

/*target_map and target_flag_map have consistent order,
eg,ACCEPT, AUDIT, REJECT*/
static char target_map[AC_ACTION_MAX][AC_ACTION_MAXNAMELEN + 1] = {
	AC_ACTION_ACCEPT_KEY, AC_ACTION_AUDIT_KEY, AC_ACTION_REJECT_KEY
};

static char target_flag_map[AC_ACTION_MAX] = {
	AC_ACCEPT, AC_AUDIT, AC_REJECT
};


void display_ac_flow_match(const struct ac_flow_match *flow_match) 
{
	int idx_offset = 0, i = 0, j = 0;
	flow_id_t *base = NULL;

	if (flow_match == NULL) {
		NACS_ERROR("invalid parameter: flow_match is NULL\n");
		return;
	}
	NACS_ERROR("---------FLOW_MATCH START---------\n");
	NACS_ERROR("Total size of match:%d\n", flow_match->match_size);
	base = (flow_id_t*)flow_match->elems;
	for (i = 0; i < AC_FLOW_TYPE_MAX; ++i) {
		NACS_ERROR("Number of %s is %d:[", flow_match_map[i], flow_match->number[i]);

		for (j = 0; j < flow_match->number[i]; ++j) {
			NAC_PRINT_DEBUG("%d, ", *(base + idx_offset + j));
		}
		idx_offset += flow_match->number[i];
	}
	NACS_ERROR("---------FLOW_MATCH END---------\n\n");
}


void display_ac_proto_match(const struct ac_proto_match* proto_match) 
{
	#define IDS_NUM_PER_ROW 6
	int i = 0;
	proto_id_t *base = NULL;
	if (proto_match == NULL) {
		NACS_ERROR("invalid parameter: proto_match is NULL\n");
		return;
	}
	NACS_ERROR("---------PROTO_MATCH START---------\n");
	NACS_ERROR("The total size of match:%d\n", proto_match->match_size);
	NACS_ERROR("Number of ids is %d:", proto_match->number);
	base = (proto_id_t*)proto_match->elems;
	for (i = 0; i < proto_match->number; ++i) {
		NAC_PRINT_DEBUG("%d, ", *(base + i));
		if (i && (i % IDS_NUM_PER_ROW) == 0) {
			NACS_ERROR("\n");
		}
	}

	NACS_ERROR("---------PROTO_MATCH END---------\n\n");
	#undef IDS_NUM_PER_ROW 
}


void display_ac_target(const struct ac_target *target)
{
	int i = 0;
	if (target == NULL) {
		NACS_ERROR("invalid parameter: target is NULL\n");
		return;
	}
	NACS_ERROR("--------TARGET START------\n");
	NACS_ERROR("The value of flags is %u:", target->flags);

	for (i = 0; i < AC_ACTION_MAX; ++i) {
		if (target->flags & target_flag_map[i]) {
			NAC_PRINT_DEBUG("%s, ", target_map[i]);
		}
	}
	NACS_ERROR("---------TARGET END-------\n\n");
}


static void display_ac_entry(struct ac_entry *entry)
{
	struct ac_flow_match *flow_match = NULL;
	struct ac_proto_match *proto_match = NULL;
	struct ac_target *target = NULL;

	if (entry == NULL) {
		NACS_WARN("invalid parameter:entry is NULL\n");
		return;
	}
	NACS_WARN("**************ENTRY START**************\n");
	NACS_WARN("entry id:%u\n", entry->entry_id);
	NACS_WARN("proto match offset:%u\n", entry->proto_match_offset);
	NACS_WARN("target offset:%u\n", entry->target_offset);
	NACS_WARN("netxt offset:%u\n", entry->next_offset);
	flow_match = (struct ac_flow_match*)((void*)entry + sizeof(struct ac_entry));
	proto_match = (struct ac_proto_match*)((void*)entry + entry->proto_match_offset);
	target = (struct ac_target*)((void*)entry + entry->target_offset);
	display_ac_flow_match(flow_match);
	display_ac_proto_match(proto_match);
	display_ac_target(target);
	NACS_WARN("**************ENTRY END**************\n\n");
}


static void display_ac_table(struct ac_table_info *table) 
{
	void *table_base = NULL;
	struct ac_entry *entry = NULL;
	
	if (table == NULL) {
		NACS_WARN("invalid parameter: table is NULL\n");
		return;
	}

	table_base = (void*) table->entries;
	ac_entry_foreach(entry, table->entries, table->size) {
		display_ac_entry(entry);
	}
}

static void display_ac_table_kernel(struct ac_table_info *table) {
	int i = 0;
	void *table_base = NULL;
	struct ac_entry *entry = NULL;
	
	if (table == NULL) {
		NACS_WARN("invalid parameter: table is NULL\n");
		return;
	}
	NACS_WARN("possible Core num:%u\n", num_possible_cpus());
	for (i = 0; i < num_possible_cpus(); ++i) {
		table_base = (void*)table->entries + SMP_ALIGN(table->size) * i;
		NACS_WARN("Core %d, table_base:%p\n", i , table_base);
		NACS_WARN("category=%u, szie:%u, align_size = %u, number=%u\n", 
				table->category , table->size, 
				SMP_ALIGN(table->size), table->number);
		ac_entry_foreach(entry, table_base, table->size) {
			display_ac_entry(entry);
		}
		NAC_PRINT_DEBUG("\n\n\n\n");
	}
}

void display_ac_set(struct ac_set_info *set_info) 
{
	int i = 0, entry_offset = 0;
	char (*ipset_name)[AC_IPSET_MAXNAMELEN + 1] = NULL;
	struct ac_hybrid_entry *entry = NULL;

	if (set_info == NULL) {
		NACS_WARN("invalid parameter: set_info is NULL\n");
		return;
	}

	entry = (struct ac_hybrid_entry*)set_info->entries;
	NACS_WARN("***************AC_SET START*******************\n");
	NAC_PRINT_DEBUG("the total size of entries = %u\n", set_info->size);
	NAC_PRINT_DEBUG("category = %u number= %u size = %u updated = %u\n\n", 
				set_info->category, set_info->number, set_info->size, set_info->updated);

	NAC_PRINT_DEBUG("set=%p entries=%p\n", set_info, set_info->entries);
	if (set_info->category == RULE_TYPE_CONTROL) {
		ipset_name = set_info->u.control.ipset_name;
	}
	else {
		ipset_name = set_info->u.audit.ipset_name;
	}
	entry_offset = AC_ALIGN(sizeof(struct ac_hybrid_entry));
	for (i = 0; i < set_info->number; ++i) {
		if (set_info->updated & (1 << i)) {
			NACS_WARN("set%d:name=%s, id=%u, action=%u, size =%u\n",
					i, ipset_name[i], entry->ipset_id, entry->flags, entry->size);
		}
		entry = (struct ac_hybrid_entry*)((char*)entry + entry_offset);
	}
	NACS_WARN("***************AC_SET END*******************\n\n"); 
}


void display_ac_set_kernel(struct ac_set_info *set_info) 
{
	int i = 0, entry_offset = 0, j = 0;
	char (*ipset_name)[AC_IPSET_MAXNAMELEN + 1] = NULL;
	struct ac_hybrid_entry *entry = NULL;

	if (set_info == NULL) {
		NACS_WARN("invalid parameter: set_info is NULL\n");
		return;
	}

	entry = (struct ac_hybrid_entry*)set_info->entries;
	NACS_WARN("***************AC_SET START*******************\n");
	NAC_PRINT_DEBUG("the total size of entries = %u\n", set_info->size);
	NAC_PRINT_DEBUG("category = %u number= %u size = %u updated = %u\n\n", 
				set_info->category, set_info->number, set_info->size, set_info->updated);

	NAC_PRINT_DEBUG("set=%p entries=%p\n", set_info, set_info->entries);
	if (set_info->category == RULE_TYPE_CONTROL) {
		ipset_name = set_info->u.control.ipset_name;
	}
	else {
		ipset_name = set_info->u.audit.ipset_name;
	}
	entry_offset = AC_ALIGN(sizeof(struct ac_hybrid_entry));
	NACS_WARN("possible Core num:%u\n", num_possible_cpus());
	for (j = 0; j < num_possible_cpus(); ++j) {
		entry = (struct ac_hybrid_entry*)((void*)set_info->entries + SMP_ALIGN(set_info->size) * j);
		NACS_WARN("Core %d, entry_base:%p\n", j , entry);
		NACS_WARN("category=%u, szie:%u, align_size = %u, number=%u updated=%u\n", 
					set_info->category , set_info->size, 
					SMP_ALIGN(set_info->size), set_info->number, set_info->updated);

		for (i = 0; i < set_info->number; ++i) {
			if (set_info->updated & (1 << i)) {
				NACS_WARN("set%d:name=%s, id=%u, action=%u, size =%u\n",
						i, ipset_name[i], entry->ipset_id, entry->flags, entry->size);
			}
			entry = (struct ac_hybrid_entry*)((char*)entry + entry_offset);
		}
		NACS_WARN("\n\n\n");
	}
	NACS_WARN("***************AC_SET END*******************\n\n"); 
}

/********************************Update rule Start******************************/
/*
*Alloc memory for ac_table_info.
*Notice:support smp accelerating, eg, per-cpu data and align
*/
static struct ac_table_info *alloc_ac_table_info(unsigned int size)
{
	struct ac_table_info *info = NULL;
	/*per-cpu data and align, sz is the real meomry size*/
	size_t sz = sizeof(*info) + SMP_ALIGN(size) * num_possible_cpus();	

	if (sz < sizeof(*info)) {
		return NULL;
	}

	/* Pedantry: prevent them from hitting BUG() in vmalloc.c --RR */
	if ((SMP_ALIGN(size) >> PAGE_SHIFT) + 2 > totalram_pages) {
		return NULL;
	}

	if (sz <= (PAGE_SIZE << PAGE_ALLOC_COSTLY_ORDER)) {
		info = kmalloc(sz, GFP_KERNEL | __GFP_NOWARN | __GFP_NORETRY);
	}

	if (!info) {
		info = vmalloc(sz);
		if (!info) {
			return NULL;
		}
	}

	memset(info, 0, sizeof(*info));
	/*record true size in user-space, this will be used in fetching info from kernel*/
	info->size = size;
	return info;
}


static void free_ac_table_info(struct ac_table_info *info)
{
	/*info occpuied memory maybe get by kmalloc or vmalloc*/
	if (info) {
		kvfree(info);
	}
}


static int check_entry_size(
		struct ac_entry *entry, 
		const unsigned char *base,
		const unsigned char *limit
	)
{
	NACS_DEBUG("entry=%p next=%p offset =%u limit=%p\n", 
				entry, ((unsigned char*)entry + entry->next_offset),  
				entry->next_offset, limit);

	if (((unsigned char*)entry + entry->next_offset) > limit) {
		NACS_ERROR("entry next_offset check failed:next_entry=%p > limit=%p\n",
				(unsigned char*)entry + entry->next_offset, limit);
		return -EINVAL;
	}

	if ((unsigned long)entry % __alignof__(struct ac_entry) != 0) {
		NACS_ERROR("entry align check failed:entry=%p, alignof(entry)=%d\n",
			entry, (unsigned int)__alignof__(struct ac_entry));
		return -EINVAL;
	}

	return 0;
}


/*Checks and translates the user-supplied table segment(hold in newinfo)*/
static int translate_table(
			struct ac_table_info *new_info, 
			void *first_entry, 
			const struct ac_repl_table_info *repl)
{
	int ret = 0, i = 0;
	struct ac_entry *entry = NULL;
	new_info->category = repl->category;
	new_info->size = repl->size;
	new_info->number = repl->number;

	if (new_info->category >= RULE_TYPE_MAX) {
		return -EINVAL;
	}

	ac_entry_foreach(entry, first_entry, new_info->size) {
		ret = check_entry_size(entry, first_entry, first_entry + new_info->size);
		if (ret < 0) {
			NACS_ERROR("entry check failed\n");
			return ret;
		}
		++i;
	}

	if (i != new_info->number) {
		ret = -EINVAL;
	}

	/* And one copy for every other CPU, SMP_ALIGN is needed */
	for (i = 1; i < num_possible_cpus(); i++) {
		memcpy(new_info->entries + SMP_ALIGN(new_info->size) * i,
		       new_info->entries,
		       SMP_ALIGN(new_info->size));
	}

	return ret;
}


static int  __do_replace_table(struct ac_table *table, struct ac_table_info *new_info)
{
	struct ac_table_info *old_info = NULL;

	write_lock_bh(&table->lock);
	old_info = table->priv_tables[new_info->category];
	table->priv_tables[new_info->category] = new_info;
	write_unlock_bh(&table->lock);
	if (old_info) {
		kvfree(old_info);
	}
	display_ac_table_kernel(table->priv_tables[new_info->category]);
	return 0;
}


/*
*replace table contains 
*a.copy header from user
*b.copy body from user ,and then,translate_table
*c.get speicified table pointer
*d.replace old table with new table
*e.free old table
*notice:take care of clearing rules
*/
int do_replace_table(const void __user *user, unsigned int len)
{
	int ret = 0;
	struct ac_table *table = NULL;
	struct ac_repl_table_info tmp;
	struct ac_table_info *new_info = NULL; 
	void *loc_cpu_entry;

	if (copy_from_user(&tmp, user, sizeof(tmp)) != 0) {
		NACS_WARN("copy from user failed\n");
		return -EFAULT;
	}

	if (len != sizeof(tmp) + tmp.size) {
		NACS_WARN("user data:real len=%u != assumption len=(header=%u + body=%u)\n", 
					len, (unsigned int)sizeof(tmp), tmp.size);
		return -ENOPROTOOPT;
	}
	NACS_WARN("user data:real len=%u == assumption len=(header:%u + body:%u)\n", 
				len, (unsigned int)sizeof(tmp), tmp.size);
	new_info = alloc_ac_table_info(tmp.size);
	if (new_info == NULL) {
		NACS_ERROR("Out of momery\n");
		return -ENOMEM;
	}

	loc_cpu_entry = new_info->entries;
	if (tmp.size > 0 && copy_from_user(loc_cpu_entry, user + sizeof(tmp), tmp.size) != 0) {
		NACS_WARN("copy from user failed\n");
		ret = -EFAULT;
		goto free_newinfo;
	}

	ret = translate_table(new_info, loc_cpu_entry, &tmp);
	if (ret < 0) {
		goto free_newinfo;
	}
	display_ac_table(new_info);
	table = get_table_withlock();
	ret = __do_replace_table(table, new_info);
	if (ret < 0) {
		table_unlock();
		NACS_WARN("do replace table failed\n");
		goto free_newinfo;
	}
	table_unlock();
	return 0;

free_newinfo:
	free_ac_table_info(new_info);
	return ret;
}


/********************************Update ipset Start***************************/
static struct ac_set_info *alloc_ac_set_info(unsigned int size)
{
	struct ac_set_info *info = NULL;
	size_t sz = sizeof(*info) + SMP_ALIGN(size) * num_possible_cpus(); /*per-cpu data*/

	if (sz < sizeof(*info)) {
		return NULL;
	}

	/* Pedantry: prevent them from hitting BUG() in vmalloc.c --RR */
	if ((SMP_ALIGN(size) >> PAGE_SHIFT) + 2 > totalram_pages)
		return NULL;

	if (sz <= (PAGE_SIZE << PAGE_ALLOC_COSTLY_ORDER))
		info = kmalloc(sz, GFP_KERNEL | __GFP_NOWARN | __GFP_NORETRY);
	if (!info) {
		info = vmalloc(sz);
		if (!info) {
			return NULL;
		}
	}
	memset(info, 0, sizeof(*info));
	/*record true size in user-space, this will be used in fetching info from kernel*/
	info->size = size;
	return info;
}


static void free_ac_set_info(struct ac_set_info *info)
{
	if (info) {
		kvfree(info);
	}
}


static int translate_set(
			struct ac_set_info *new_info, 
			void *first_entry, 
			struct ac_repl_set_info *repl)
{
	struct ac_hybrid_entry *entry = NULL;
	char (*ipset_name)[AC_IPSET_MAXNAMELEN + 1] = NULL;
	int i = 0, entry_offset = 0;
	struct ip_set *set = NULL;
	void *entry_base = NULL;

	if (repl->number * (AC_ALIGN(sizeof(struct ac_hybrid_entry))) != repl->size) {
		NACS_WARN("ipset entries size check failed:real_size=%u != expected_size=%u\n",
				repl->size, (unsigned int)AC_ALIGN(repl->number * (sizeof(ip_set_id_t))));
		return -EINVAL;
	}

	new_info->category = repl->category;
	new_info->size = repl->size;
	new_info->updated = repl->updated;
	new_info->number = repl->number;
	if (new_info->category == RULE_TYPE_CONTROL) {
		ipset_name = new_info->u.control.ipset_name;
	}
	else {
		ipset_name = new_info->u.audit.ipset_name; 
	}

	entry_base = first_entry;
	entry_offset = AC_ALIGN(sizeof(struct ac_hybrid_entry));
	for (i = 0; i < new_info->number; ++i) {
		entry = (struct ac_hybrid_entry*)(entry_base + i * entry_offset);
		entry->ipset_id = IPSET_INVALID_ID;
		if (new_info->updated & (1 << i)) {
			entry->ipset_id = ip_set_get_byname(&init_net, ipset_name[i], &set);
		}
	}

	/* And one copy for every other CPU */
	for (i = 1; i < num_possible_cpus(); i++) {
		memcpy(new_info->entries + SMP_ALIGN(new_info->size) * i,
		       new_info->entries,
		       SMP_ALIGN(new_info->size));
	}
	return 0;
}


/*replace ipsets
*notice:take care of clearing sets
*/
int do_replace_set(const void __user *user, unsigned int len)
{
	int ret = 0;
	void *loc_cpu_entry;
	struct ac_repl_set_info tmp;
	struct ac_set_info*new_info = NULL;
	struct ac_table *table = NULL;

	if (copy_from_user(&tmp, user, sizeof(tmp)) != 0) {
		NACS_WARN("copy from user failed\n");
		return -EFAULT;
	}

	if (len != sizeof(tmp) + tmp.size) {
		NACS_WARN("user data:real len=%u != assumption len=(header=%u + body=%u)\n", 
					len, (unsigned int)sizeof(tmp), tmp.size);
		return -ENOPROTOOPT;
	}

	if (tmp.category > RULE_TYPE_MAX) {
		NACS_WARN("invalid category=%u\n", tmp.category);
		return -EINVAL;
	}

	new_info = alloc_ac_set_info(tmp.size);
	if (new_info == NULL) {
		NACS_ERROR("Out of momery\n");
		return -ENOMEM;
	}

	/*copy header*/
	memcpy((void*)new_info, (void*)&tmp, sizeof(tmp));
	loc_cpu_entry = new_info->entries;
	if (tmp.size > 0 && copy_from_user(loc_cpu_entry, user + sizeof(tmp), tmp.size) != 0) {
		NACS_WARN("copy from user failed\n");
		return -EFAULT;
	}
	ret = translate_set(new_info, loc_cpu_entry, &tmp);
	if (ret < 0) {
		goto free_newinfo;
	}
	display_ac_set(new_info);
	table = get_table_withlock();
	table->priv_sets[tmp.category] = new_info;
	table_unlock();
	display_ac_set_kernel(table->priv_sets[tmp.category]);
	return 0;

free_newinfo:
	free_ac_set_info(new_info);
	return ret;
}


/********************************Fetch info Start*****************************/
int do_get_table_info(void __user *user, int *len)
{
	struct ac_table *table = NULL;
	struct ac_table_info *table_info = NULL;
	struct ac_get_entries_info entries_info;
	if (copy_from_user(&entries_info, user, sizeof(entries_info)) != 0) {
		NACS_WARN("copy from user failed\n");
		return -EFAULT;
	}

	if (*len != sizeof(entries_info)) {
		NACS_WARN("user data:real_len=%i != assumption len=%u\n", *len, (unsigned int)sizeof(entries_info));
		return -ENOPROTOOPT;
	}

	if (entries_info.category > RULE_TYPE_MAX) {
		NACS_WARN("invalid category=%u\n", entries_info.category);
		return -EINVAL;
	}

	table = get_table_withlock();
	table_info = nac_table.priv_tables[entries_info.category];
	entries_info.size = table_info->size;
	entries_info.number = table_info->number;
	table_unlock();

	if (copy_to_user(user, &entries_info, *len) != 0) {
		NACS_WARN("copy to user failed\n");
		return -EFAULT;
	}

	return 0;
}


int do_get_set_info(void __user *user, int *len)
{
	struct ac_get_sets_info tmp;
	struct ac_table *table = NULL;
	struct ac_set_info *set_info = NULL;

	if (copy_from_user(&tmp, user, sizeof(tmp)) != 0) {
		NACS_WARN("copy_from_user failed\n");
		return -EFAULT;
	}

	if (*len != sizeof(tmp)) {
		NACS_WARN("user data:real_len=%i != assumption len=%u\n", 
					*len, (unsigned int)sizeof(tmp));
		return -ENOPROTOOPT;
	}

	if (tmp.category > RULE_TYPE_MAX) {
		NACS_WARN("invalid category=%u\n", tmp.category);
		return -EINVAL;
	}

	table = get_table_withlock();
	set_info = table->priv_sets[tmp.category];
	tmp.updated = set_info->updated;
	tmp.size = set_info->size;
	tmp.number = set_info->number;
	table_unlock();

	if (copy_to_user(user, &tmp, *len) != 0) {
		NACS_WARN("copy to user failed\n");
		return -EFAULT;
	}

	return 0;
}


int do_get_entries(void __user *user, int *len)
{
	int ret = 0;
	struct ac_table *table = NULL;
	struct ac_repl_table_info tmp;
	struct ac_table_info *table_info = NULL;

	if (copy_from_user(&tmp, user, sizeof(tmp)) != 0) {
		NACS_WARN("copy from user failed\n");
		return -EFAULT;
	}
	printk("tmp:%u %u %u %u\n", tmp.category, tmp.size, tmp.number, (unsigned int)sizeof(tmp));
	if (*len != sizeof(tmp) + tmp.size) {
		NACS_WARN("user data:real_len=%i != assumption len=%u\n", *len, (unsigned int)sizeof(tmp) + tmp.size);
		return -ENOPROTOOPT;
	}

	if (tmp.category > RULE_TYPE_MAX) {
		NACS_WARN("invalid category=%u\n", tmp.category);
		return -EINVAL;
	}

	table = get_table_withlock();
	table_info = table->priv_tables[tmp.category];
	if (tmp.category != table_info->category || 
		tmp.size != table_info->size || 
		tmp.number != table_info->number) {
		NACS_WARN("invalid parameters\n");
		ret =  -EINVAL;
		goto fail;
	}
	/*Notice:ac_repl_table_info and ac_table_info are different in kernel,however,we just need entries*/
	if (copy_to_user(user + sizeof(tmp), table_info->entries, tmp.size) != 0) {
		NACS_WARN("copy to user failed\n");
		ret = -EFAULT;
		goto fail;
	}

	table_unlock();
	return 0;

fail:
	table_unlock();
	return ret;
}


int do_get_sets(void __user *user, int *len)
{
	int ret = 0;
	struct ac_repl_set_info tmp;
	struct ac_set_info *set_info = NULL;
	struct ac_table *table = NULL;
	//do_ac_table(NULL, NULL, NULL);
	if (copy_from_user(&tmp, user, sizeof(tmp)) != 0) {
		NACS_WARN("copy from user failed\n");
		return -EFAULT;
	}

	if (*len != sizeof(tmp) + tmp.size) {
		NACS_WARN("user data:real_len=%i != assumption len=(header=%u + body=%u)\n", 
					*len, (unsigned int)sizeof(tmp), tmp.size);
		return -ENOPROTOOPT;
	}

	if (tmp.category > RULE_TYPE_MAX) {
		NACS_WARN("invalid category=%u\n", tmp.category);
		return -EINVAL;
	}

	table = get_table_withlock();
	set_info = table->priv_sets[tmp.category];
	if (tmp.category != set_info->category || 
		tmp.size != set_info->size ||
		tmp.number != set_info->number ||
		tmp.updated != set_info->updated) {
		NACS_WARN("invalid parameter:cate=%u number=%u size=%u  updated=%u\n",
			set_info->category, set_info->number, set_info->size, set_info->updated);
		NACS_WARN("invalid parameter:user cate=%u number=%u size=%u  updated=%u\n",
			tmp.category, tmp.number, tmp.size, tmp.updated);
		ret =  -EINVAL;
		goto fail;
	}
	/*Notice:ac_repl_set_info and ac_set_info are different in kernel,so, twice copy needed*/
	if (copy_to_user(user, (void*)set_info, sizeof(struct ac_repl_set_info)) != 0) {
		ret = -EFAULT;
		goto fail;
	}
	if (copy_to_user(user + sizeof(struct ac_repl_set_info), set_info->entries, set_info->size) != 0) {
		ret = -EFAULT;
		goto fail;
	}
	table_unlock();

	return 0;
fail:
	table_unlock();
	return ret;
}


/********************************Query Start*****************************/
/*
*search value(proto_id) in proto_id sorted array
*if find, return the index of the correspond array element
*if not find, return -1
*notice:the proto_id is asc sorted
*/
static int binary_search(
	proto_id_t *proto_id, 
	int number, 
	proto_id_t value)
{
	int left = 0, middle = 0, right = 0;

	right = number - 1;
	while (left <= right) {
		middle = left + ((right - left)>>1);
		if (proto_id[middle] > value) {
			right = middle - 1;
		}
		else if (proto_id[middle] < value) {
			left = middle + 1;
		}
		else {
			return middle;
		}
	}
	return -1;
}


/*
*valid zone range[0~254], zone255 means all of zones
*/
static int ac_zone_check(
	flow_id_t *zone, 
	int number, 
	flow_id_t zone_id) 
{

	int i = 0, matched = 0;

	for (i = 0; i < number; ++i) {
		if (zone[i] == zone_id || zone[i] >= AC_ZONE_MAXID) {
			NACS_DEBUG("zone[%d] = %d, zone_id=%d matched\n", i, zone[i], zone_id);
			matched = 1;
			break;
		}
	}
	return matched;
}


/*
*valid ipgrp range[0~63], ipgrp64 means all of ipgrps
*ipgrp: ipgrp[i] == AC_IPGRP_MAXID means all of ipgrps
*ipgrp_bits:every bit represent a ipgrp,eg, ipgrp_bits:10 been set, means ipgrp10 been set
*/
static int ac_ipgrp_check(
	flow_id_t *ipgrp, 
	int number, 
	__u64 ipgrp_bits) {

	#define IPGRP_BITS_SIZE 64
	int i = 0, matched = 0;

	for (i = 0; i < number; ++i) {
		/*notice: ipgrp[i] maybe greater than 63, we should take care*/ 
		if ((ipgrp[i] < IPGRP_BITS_SIZE) && (ipgrp_bits & (1 << ipgrp[i]))) {
			NACS_DEBUG("ipgrp[%d] = %d, ipgrp_bits=0x%llx matched\n", i, ipgrp[i], ipgrp_bits);
			matched = 1;
			break;
		}

		if (ipgrp[i] >= AC_IPGRP_MAXID) {
			NACS_DEBUG("ipgrp[%d] = %d, ipgrp_bits=0x%llx matched\n", i, ipgrp[i], ipgrp_bits);
			matched = 1;
			break;
		}
	}
	#undef IPGRP_BITS_SIZE
	return matched;
}


/*notice:ac_flow_match contains four parts, check them one by one*/
static int flow_match_check(struct ac_flow_match *match, struct dpi_flow *flow)
{
	int i = 0, matched = 0, offset = 0;
	flow_id_t *base = NULL;

	base = (flow_id_t*)match->elems;
	for (i = 0; i < AC_FLOW_TYPE_MAX; ++i) {
		switch(i) {
			case AC_FLOW_TYPE_SRCZONEID:
				{
					matched = ac_zone_check(base + offset, match->number[i], flow->src_zone);
					break;
				}

			case AC_FLOW_TYPE_SRCIPGRPID:
				{
					matched = ac_ipgrp_check(base + offset, match->number[i], flow->src_ipgrp_bits);
					break;
				}

			case AC_FLOW_TYPE_DSTZONEID:
				{
					matched = ac_zone_check(base + offset, match->number[i], flow->dst_zone);
					break;
				}

			case AC_FLOW_TYPE_DSTIPGRPID:
				{
					matched = ac_ipgrp_check(base + offset, match->number[i], flow->dst_ipgrp_bits);
					break;
				}	

			default:
				matched = 0;
				break;
		}
		/*all of four parts should be matched*/
		if (matched == 0) {
			break;
		}
		offset += match->number[i];
	}
	NACS_DEBUG("src_zone=%u dst_zone=%u src_ipgrp_bits=%llu dst_ipgrp_bits=%llu matched=%d\n\n",
		flow->src_zone, flow->dst_zone, flow->src_ipgrp_bits, flow->dst_ipgrp_bits, matched);
	return matched;
}


/*notice:ac_proto_match contains a asc sorted array which contains several proto_ids*/
static int proto_match_check(struct ac_proto_match *match, struct dpi_proto *proto)
{
	int match_idx = 0;
	proto_id_t *proto_ids = NULL, proto_id = 0;
	
	proto_id = proto->sub_proto_id == 0 ? proto->proto_id : proto->sub_proto_id;
	/*Notice: all arraies are sorted by asc*/
	proto_ids = (proto_id_t*)match->elems;
	match_idx = binary_search(proto_ids, match->number, proto_id);
	NACS_DEBUG("proto_id=%d match_idx=%d\n\n", proto_id, match_idx);
	return match_idx < 0 ? 0 : 1; 
}


/*
*whether need check
*a:whether this flow has been processed before
*c:whether this flow isn't avaliable to check
*/
static int is_need_check(	
	const struct net_device *in,
	const struct net_device *out,
	struct sk_buff *skb )
{
	return 0;
}


static int __do_set(
	const struct net_device *in,
	const struct net_device *out,
	struct sk_buff *skb, 
	struct ac_set_info *set_info, struct ac_check_result *result)
{
	int ret = -1, i = 0, entry_offset = 0;
	void *set_base = NULL;
	struct ac_hybrid_entry *entry = NULL;

	entry_offset = AC_ALIGN(sizeof(struct ac_hybrid_entry));
	set_base = set_info->entries + SMP_ALIGN(set_info->size) * smp_processor_id();
	for (i = 0; i < set_info->number; ++i) {
		entry = (struct ac_hybrid_entry*)(set_base + entry_offset * i);
		if (entry->ipset_id != IPSET_INVALID_ID) {
			switch(i) {
				case AC_MACWHITELIST_SET:
						if (ip_set_test_src_mac(in, out, skb, entry->ipset_id)) {
							ret = AC_MACWHITELIST_SET;
						}
						break;

				case AC_IPWHITELIST_SET:
						if (ip_set_test_src_ip(in, out, skb, entry->ipset_id)) {
							ret = AC_IPWHITELIST_SET;
						}	
						break;

				case AC_MACBLACKLIST_SET:
						if (ip_set_test_src_mac(in, out, skb, entry->ipset_id)) {
							ret = AC_MACBLACKLIST_SET;
						}
						break;

				case AC_IPBLACKLIST_SET:
						if (ip_set_test_src_ip(in, out, skb, entry->ipset_id)) {
							ret = AC_IPBLACKLIST_SET;
						}	
						break;

				default:
					ret = -1;
					break;
			}
		}
	}

	if (ret != -1) {
		result->rule_sub_type = RULE_SUB_TYPE_SET;
		result->u.set.set_type = ret;
		result->action = entry->flags;
		do_gettimeofday(&result->tv);
	}

	return ret;
}


static int __do_table(
	const struct net_device *in,
	const struct net_device *out,
	struct sk_buff *skb, 
	struct ac_table_info *table_info,
	struct ac_check_result *result)
{
	int ret = -1;
	void *table_info_base = NULL;
	struct ac_flow_match *flow_match = NULL;
	struct ac_proto_match *proto_match = NULL;
	struct ac_target *target = NULL;
	struct ac_entry *entry = NULL;

	struct dpi_flow flow = {
		.src_ip = 174320,
		.dst_ip = 174322,
		.src_zone = 2,
		.dst_zone = 3,
		.src_ipgrp_bits = 0x10,
		.dst_ipgrp_bits = 0x10
	};
	struct dpi_proto proto = {9,0,1}; 
	
	table_info_base = table_info->entries + SMP_ALIGN(table_info->size) * smp_processor_id();
	ac_entry_foreach(entry, table_info_base, table_info->size) {
		flow_match = (struct ac_flow_match*)entry->elems;
		proto_match = (struct ac_proto_match*)((void*)entry + entry->proto_match_offset);
		target = (struct ac_target*)((void*)entry + entry->target_offset);
		if (flow_match_check(flow_match, &flow) && proto_match_check(proto_match, &proto)) {
			ret = target->flags;
			break;
		}
	}
	if (ret != -1) {
		result->rule_sub_type = RULE_SUB_TYPE_RULE;
		memcpy(&result->u.rule.proto, &proto, sizeof(struct dpi_proto));
		result->action = target->flags;
	}
	return ret;
}


/*
*the main behind the curtain, it will check set and rule, 
*and then, generate check result
*/
static int __do_ac_table(
	const struct net_device *in,
	const struct net_device *out,
	struct sk_buff *skb, 
	struct ac_table *table,
	int rule_type, struct ac_check_result *result) 
{

	int ret = -1;
	struct ac_set_info *set_info = NULL;
	struct ac_table_info *table_info = NULL;

	read_lock_bh(&table->lock);
	/*check ipset*/
	set_info = table->priv_sets[rule_type];
	ret = __do_set(in, out, skb, set_info, result);
	if (ret != -1) {
		/*matched in set, no need to check rule*/
		goto out;
	}

	/*check table rule*/
	table_info = table->priv_tables[rule_type];
	ret = __do_table(in, out, skb, table_info, result);

out:
	read_unlock_bh(&table->lock);
	return ret;
}


/*
*process check result
*a.set action flag and processed flag
*b.log the event
*/
static int process_check_result(struct ac_check_result *result) 
{
	NACS_DEBUG("----------process check result start-----\n");
	NAC_PRINT_DEBUG("Match in:[%s %s]\n", 
		result->rule_type == RULE_TYPE_CONTROL ? "CONTROL": "AUDIT", 
		result->rule_sub_type == RULE_SUB_TYPE_SET ? "SET" :"RULE");
	
	if (result->rule_sub_type == RULE_SUB_TYPE_RULE) {
		NAC_PRINT_DEBUG("proto:type=%u, proto_id=%u, sub_proto_id=%u\n",
			result->u.rule.proto.type, 
			result->u.rule.proto.proto_id, 
			result->u.rule.proto.sub_proto_id);
	}
	else {
		switch(result->u.set.set_type) {
			case AC_MACWHITELIST_SET:
				NAC_PRINT_DEBUG("Set:%s\n", "MACWHITELIST");
				break;

			case AC_IPWHITELIST_SET:
				NAC_PRINT_DEBUG("Set:%s\n", "IPWHITELIST");
				break;

			case AC_MACBLACKLIST_SET:
				NAC_PRINT_DEBUG("Set:%s\n", "MACBLACKLIST");
				break;

			case AC_IPBLACKLIST_SET:
				NAC_PRINT_DEBUG("Set:%s\n", "IPBLACKLIST");
				break;

			default:
				break;
		}
	}
	NAC_PRINT_DEBUG("Action:%u\n", result->action);
	NACS_DEBUG("----------process check result end--------\n");
	return 0;
}


/*
*In this function, both ipset and rule of audit and control will be check:
*a:check whether need to check
*b:check set and rule of control, if matched, result hold the check result, then processit
*c:check set and rule of audit, process flow just like control
*/
int do_ac_table(	
	const struct net_device *in,
	const struct net_device *out,
	struct sk_buff *skb)
{
	int rule_type = 0, ret = 0;
	struct ac_check_result result;

	if (is_need_check(in, out, skb) == 0) {
		return ret;
	}

	for (rule_type = 0; rule_type < RULE_TYPE_MAX; ++rule_type) {
		result.rule_type = rule_type;
		if (__do_ac_table(in, out, skb, &nac_table, rule_type, &result) != -1) {
			ret = process_check_result(&result);
		}
	}
	return ret;
}


/**************************************init & fini Start**************************/
static int table_init(void)
{
	int i = 0;
	rwlock_init(&nac_table.lock);
	for (i = 0; i < RULE_TYPE_MAX; ++i) {
		nac_table.priv_tables[i] = (struct ac_table_info*)kzalloc(sizeof(struct ac_table_info), GFP_KERNEL | __GFP_NOWARN);
		if (nac_table.priv_tables[i] == NULL) {
			NACS_ERROR("Out of memory\n");
			goto fail;
		}
		nac_table.priv_tables[i]->category = i;

		nac_table.priv_sets[i] = (struct ac_set_info*)kzalloc(sizeof(struct ac_set_info), GFP_KERNEL | __GFP_NOWARN);
		if (nac_table.priv_sets[i] == NULL) {
			NACS_ERROR("Out of memory\n");
			goto fail;
		}
		nac_table.priv_sets[i]->category = i;
	}

	return 0;
	
fail:
	for (i = 0; i < RULE_TYPE_MAX; ++i) {
		if (nac_table.priv_tables[i]) {
			kfree(nac_table.priv_tables[i]);
			nac_table.priv_tables[i] = NULL;
		}

		if (nac_table.priv_sets[i]) {
			kfree(nac_table.priv_sets[i]);
			nac_table.priv_sets[i] = NULL;
		}
	}
	return -1;
}


static void table_fini(void)
{
	int i = 0;
	for (i = 0; i < RULE_TYPE_MAX; ++i) {
		if (nac_table.priv_tables[i]) {
			kvfree(nac_table.priv_tables[i]);
			nac_table.priv_tables[i] = NULL;
		}

		if (nac_table.priv_sets[i]) {
			kvfree(nac_table.priv_sets[i]);
			nac_table.priv_sets[i] = NULL;
		}
	}
}


int nacs_table_init(void)
{
	int ret = -1;

	ret = table_init();
	if (ret < 0) {

		return ret;
	}
	NACS_INFO("nacs_table_init success\n");
	return ret;
}


void nacs_table_fini(void)
{	
	table_fini();
	NACS_INFO("nacs_table_fini success\n");
}