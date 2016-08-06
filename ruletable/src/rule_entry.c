#include <stdlib.h>
#include <strings.h>
#include <string.h>
#include "rule_print.h"
#include "rule_table.h"
#include "rule_parse.h"
#include "match_target.h"
#include "rule_ipc.h"

static void display_ac_entry(struct ac_entry *entry)
{
	struct ac_flow_match *flow_match = NULL;
	struct ac_proto_match *proto_match = NULL;
	struct ac_target *target = NULL;

	if (entry == NULL) {
		AC_ERROR("invalid parameter:entry is NULL\n");
		return;
	}
	AC_DEBUG("**************ENTRY START**************\n");
	AC_PRINT("entry id:%u\n", entry->entry_id);
	AC_PRINT("proto match offset:%u\n", entry->proto_match_offset);
	AC_PRINT("target offset:%u\n", entry->target_offset);
	AC_PRINT("netxt offset:%u\n", entry->next_offset);
	flow_match = (struct ac_flow_match*)((void*)entry + sizeof(struct ac_entry));
	proto_match = (struct ac_proto_match*)((void*)entry + entry->proto_match_offset);
	target = (struct ac_target*)((void*)entry + entry->target_offset);
	display_ac_flow_match(flow_match);
	display_ac_proto_match(proto_match);
	display_ac_target(target);
	AC_DEBUG("**************ENTRY END**************\n\n");
}


static struct ac_entry *generate_ac_entry(struct ac_rule_item *rule_item)
{
	struct ac_entry *entry = NULL;
	struct ac_flow_match *flow_match = NULL;
	struct ac_proto_match *proto_match = NULL;
	struct ac_target *target = NULL;
	int entry_size = 0;

	if (rule_item == NULL) {
		AC_ERROR("invalid parameter:rule_item is NULL\n");
		return NULL;
	}

	flow_match = generate_flow_match(rule_item->src_zone_ids, rule_item->src_zone_num,
									rule_item->src_ipgrp_ids, rule_item->src_ipgrp_num,
									rule_item->dst_zone_ids, rule_item->dst_zone_num,
									rule_item->dst_ipgrp_ids, rule_item->dst_ipgrp_num);
	if (flow_match == NULL) {
		AC_ERROR("generate flow match failed\n");
		goto out;
	}

	proto_match = generate_proto_match(rule_item->proto_ids, rule_item->proto_num);
	if (proto_match == NULL) {
		AC_ERROR("generate proto match failed\n");
		goto out;
	}

	target = generate_target(rule_item->action, rule_item->action_num);
	if (target == NULL) {
		AC_ERROR("generate target failed\n");
		goto out;
	}

	entry_size += AC_ALIGN(sizeof(struct ac_entry));
	entry_size += flow_match->match_size;
	entry_size += proto_match->match_size;
	entry_size += AC_ALIGN(sizeof(struct ac_target));
	entry = (struct ac_entry*)malloc(entry_size);

	if (entry == NULL) {
		AC_ERROR("Out of memory\n");
		goto out;
	}
	/*both entry head and body are aligned*/
	bzero(entry, entry_size);
	entry->entry_id = rule_item->id;
	entry->proto_match_offset = AC_ALIGN(sizeof(struct ac_entry)) + flow_match->match_size;
	entry->target_offset = entry->proto_match_offset + proto_match->match_size;
	entry->next_offset = entry->target_offset + AC_ALIGN(sizeof(struct ac_target));
	memcpy((void*)entry + AC_ALIGN(sizeof(struct ac_entry)), flow_match, flow_match->match_size);
	memcpy((void*)entry + entry->proto_match_offset, proto_match, proto_match->match_size);
	memcpy((void*)entry + entry->target_offset, target, AC_ALIGN(sizeof(struct ac_target)));

out:
	
	if (flow_match) {
		free(flow_match);
	}

	if (proto_match) {
		free(proto_match);
	}

	if (target) {
		free(target);
	}
	return entry;
}


void display_ac_table(const struct ac_repl_table_info *table)
{
	void *table_base = NULL;
	unsigned int offset = 0;
	struct ac_entry *entry = NULL;
	
	if (table == NULL) {
		AC_ERROR("invalid parameter: table is NULL\n");
		return;
	}

	table_base = (void*) table->entries;
	AC_DEBUG("category:%d, size:%d, number:%d, header=%d\n", table->category, table->size, table->number, sizeof(struct ac_repl_table_info));
	ac_entry_foreach(entry, table->entries, table->size) {
		display_ac_entry(entry);
	}
}


struct ac_repl_table_info *generate_empty_ac_table()
{
	struct ac_repl_table_info *table = NULL;
	table = (struct ac_repl_table_info*)malloc(sizeof(struct ac_repl_table_info));
	if (table) {
		bzero(table, sizeof(struct ac_repl_table_info));
		return table;
	}	
	AC_ERROR("out of memory\n");
	return NULL;
}


struct ac_repl_table_info *glue_entries_to_table(struct ac_entry **entries, unsigned int number)
{
	struct ac_repl_table_info *table = NULL;
	void *table_base = NULL;
	int entry_size = 0, entry_num = 0, next_offset = 0, cpy_offset = 0;

	if (entries == NULL || number == 0) {
		AC_ERROR("invalid pramater\n");
		return NULL;
	}
	for (int i = 0; i < number; ++i) {
		if (entries[i]) {
			entry_size += entries[i]->next_offset;
			entry_num++;
		}
	}

	if (entry_num != number) {
		AC_ERROR("invalid pramater: entries contains NULL");
		return NULL;
	}

	table = (struct ac_repl_table_info*)malloc(sizeof(struct ac_repl_table_info) + entry_size);
	if (table == NULL) {
		AC_ERROR("out of memory\n");
		goto out;
	}

	bzero(table, (sizeof(struct ac_repl_table_info) +  entry_size));
	table->size = entry_size;
	table->number = entry_num;
	table_base = table->entries;
	for (int i = 0; i < table->number; ++i) {
		entry_size = entries[i]->next_offset;
		cpy_offset = next_offset;
		next_offset += entry_size;
		memcpy((void*)table_base + cpy_offset , entries[i], entry_size);
	}
out:
	return table;
}


struct ac_repl_table_info *generate_ac_table(struct ac_rule *rules, int category)
{
	struct ac_entry **entries = NULL;
	struct ac_repl_table_info *table = NULL;
	int entries_size = 0;
	if (rules == NULL) {
		AC_ERROR("invalid pramater:config is NULL\n");
		return NULL;
	}

	if (rules->updated == 0) {
		AC_INFO("no need update rule\n");
		return NULL;
	}

	/*if rules updated and without no items, it means clear rules*/
	if (rules->number == 0) {
		table = generate_empty_ac_table();
		if (table) {
			table->category = category;
		}
		return table;
	}

	entries = (struct ac_entry**)malloc(sizeof(struct ac_entry*) * rules->number);
	if (entries == NULL) {
		goto out;
	}

	for (int i = 0; i < rules->number; ++i) {
		entries[i] = generate_ac_entry(&rules->items[i]);
		if (entries[i] == NULL) {
			goto out;
		}
	}

	table = glue_entries_to_table(entries, rules->number);
	if (table == NULL) {
		AC_ERROR("gule entries to table failed\n");
		goto out;
	}
	table->category = category;
out:
	if (entries == NULL) {
		return table;
	}

	for (int j = 0; j < rules->number; ++j) {
		if (entries[j] == NULL) {
			break;
		}
		free(entries[j]);
	}
	free(entries);

	return table;
}


void display_ac_set(struct ac_repl_set_info *set_info) 
{
	int entry_offset = 0;
	char (*ipset_name)[AC_IPSET_MAXNAMELEN + 1] = NULL;
	struct ac_hybrid_entry *entry = NULL;
	void *entry_base = NULL;

	if (set_info == NULL) {
		AC_ERROR("invalid parameter: set_info is NULL\n");
		return;
	}

	entry_base = set_info->entries;
	AC_DEBUG("***************AC_SET START*******************\n\n");
	AC_PRINT("the total size of entries = %u\n", set_info->size);
	AC_PRINT("category = %u number= %u size = %u updated = %u\n\n", 
				set_info->category, set_info->number, set_info->size, set_info->updated);
	AC_PRINT("set=%p entries=%p\n", set_info, set_info->entries);
	if (set_info->category == RULE_TYPE_CONTROL) {
		ipset_name = set_info->u.control.ipset_name;
	}
	else {
		ipset_name = set_info->u.audit.ipset_name;
	}
	entry_offset = AC_ALIGN(sizeof(struct ac_hybrid_entry));
	for (int i = 0; i < set_info->number; ++i) {
		entry = (struct ac_hybrid_entry*)(entry_base + i * entry_offset);
		if (set_info->updated & (1 << i)) {
			AC_PRINT("set%d:name=%s, id=%d, action=%u, size =%d\n",
					i, ipset_name[i], entry->ipset_id, entry->flags, entry->size);
		}
	}
	AC_DEBUG("***************AC_SET END*******************\n\n"); 
}

/*
#define AC_MACWHITELIST_SET 	0
#define AC_IPWHITELIST_SET		1
#define AC_MACBLACKLIST_SET 	2
#define AC_IPBLACKLIST_SET 		3
#define AC_IPSET_TYPE_MAX		4
*/
static int ac_set_action_map[AC_IPSET_TYPE_MAX] = {
	(AC_IGNORE | AC_ACCEPT),	/*MACWHITE*/ 
	(AC_IGNORE | AC_ACCEPT),	/*IPWHITE*/
	(AC_AUDIT | AC_REJECT),		/*MACBLACK*/ 
	(AC_AUDIT | AC_REJECT),		/*IPBLACK*/
};


struct ac_repl_set_info *generate_ac_set(struct ac_set *set, int category) 
{
	int offset = 1, entry_size = 0, entry_offset = 0, total_size = 0;
	struct ac_repl_set_info *set_info = NULL;
	char (*ipset_name)[AC_IPSET_MAXNAMELEN + 1] = NULL;
	struct ac_hybrid_entry *entry = NULL;
	void *entry_base = NULL;

	if (set == NULL) {
		AC_ERROR("invalid parameter: set is NULL\n");
		return NULL;
	}

	entry_size = set->number * AC_ALIGN(sizeof(struct ac_hybrid_entry));
	total_size = entry_size + sizeof(struct ac_repl_set_info);
	set_info = (struct ac_repl_set_info*)malloc(total_size);
	if (set_info == NULL) {
		AC_ERROR("Out of memory\n");
		goto out;
	}
	
	bzero(set_info, total_size);
	set_info->size = entry_size;
	set_info->updated = set->updated;
	set_info->category = category;
	set_info->number = set->number;
	entry_base = set_info->entries;
	entry_offset = AC_ALIGN(sizeof(struct ac_hybrid_entry));
	
	if (set_info->category == RULE_TYPE_CONTROL) {
		ipset_name = set_info->u.control.ipset_name;
	}
	else {
		ipset_name = set_info->u.audit.ipset_name;
	}

	AC_PRINT("set_info addr=%p total_size = %u entry_size= %u, " 
				"per_entry_size = %u number = %u entries addr =%p\n", 
			set_info, total_size, entry_size, 
			entry_offset, set_info->number, set_info->entries);

	for (int i = 0; i < set->number; ++i) {
		if (set->updated & (1 << i)) {
			memcpy(ipset_name[i], set->ipsets[i], (AC_IPSET_MAXNAMELEN + 1));
		} 
		entry = (struct ac_hybrid_entry*)(entry_base + i * entry_offset);
		AC_PRINT("entry addr:%p entry_offset:%u\n", entry, AC_ALIGN(sizeof(struct ac_hybrid_entry)));
		entry->size = AC_ALIGN(sizeof(struct ac_hybrid_entry));
		entry->ipset_id = IPSET_INVALID_ID;
		entry->flags = ac_set_action_map[i];
	}
	display_ac_set(set_info);
out:
	#undef IPSET_INVALID_ID
	return set_info;
}


static void display_entries_info(const struct ac_get_entries_info *info)
{
	AC_DEBUG("-------------------Entries Info Start-------------\n");
	AC_PRINT("category:%u\n", info->category);
	AC_PRINT("number:%u\n", info->number);
	AC_PRINT("size:%u\n", info->size);
	AC_DEBUG("-------------------Entries Info End---------------\n");
}


struct ac_repl_table_info *fetch_ac_table(unsigned int cate, unsigned int info_cmd, unsigned int detail_cmd)
{
	int total_size = 0;
	struct ac_get_entries_info entries_info;
	struct ac_repl_table_info *table = NULL;

	total_size = sizeof(struct ac_get_entries_info);
	bzero(&entries_info, total_size);
	entries_info.category = cate;
	if (do_rule_ipc_get(info_cmd, &entries_info, total_size) != 0) {
		AC_ERROR("get entries_info failed\n");
		goto failed;
	} 
	display_entries_info(&entries_info);

	total_size = sizeof(struct ac_repl_table_info) + entries_info.size;
	table = (struct ac_repl_table_info*)malloc(total_size);
	if (table == NULL) {
		AC_ERROR("Out of memory\n");
		goto failed;
	}
	bzero(table, total_size);
	table->category = cate;
	table->number = entries_info.number;
	table->size = entries_info.size;

	if (do_rule_ipc_get(detail_cmd, table, total_size) != 0) {
		AC_ERROR("get entries failed\n");
		goto failed;
	}

	return table;
failed:
	if (table) {
		free(table);
	}
	return NULL;
}

static void display_sets_info(const struct ac_get_sets_info *info)
{
	AC_DEBUG("-------------------Entries Info Start-------------\n");
	AC_PRINT("category:%u\n", info->category);
	AC_PRINT("number:%u\n", info->number);
	AC_PRINT("updated:%u\n", info->updated);
	AC_PRINT("size:%u\n", info->size);
	AC_DEBUG("-------------------Entries Info End---------------\n");
}

struct ac_repl_set_info *fetch_ac_set(unsigned int cate, unsigned int info_cmd, unsigned int detail_cmd)
{
	int total_size = 0;
	struct ac_get_sets_info sets_info;
	struct ac_repl_set_info *sets = NULL;

	total_size = sizeof(struct ac_get_sets_info);
	bzero(&sets_info, total_size);
	sets_info.category = cate;
	if (do_rule_ipc_get(info_cmd, &sets_info, total_size) != 0) {
		AC_ERROR("get sets_info failed\n");
		goto failed;
	} 
  
 	display_sets_info(&sets_info);

	total_size = sizeof(struct ac_repl_set_info) + sets_info.size;
	sets = (struct ac_repl_set_info*)malloc(total_size);
	if (sets == NULL) {
		AC_ERROR("Out of memory\n");
		goto failed;
	}
	bzero(sets, total_size);
	sets->category = cate;
	sets->updated = sets_info.updated;
	sets->size = sets_info.size;
	sets->number = sets_info.number;

	if (do_rule_ipc_get(detail_cmd, sets, total_size) != 0) {
		AC_ERROR("get sets failed\n");
		goto failed;
	}

	return sets;
failed:
	if (sets) {
		free(sets);
	}
	return NULL;
}