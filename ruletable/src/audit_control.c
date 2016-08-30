/*
	Parse control config between json and c structure.
*/
#include <stdlib.h>
#include <strings.h>
#include <rule_table.h>
#include "rule_parse.h"
#include "json_utility.h"
#include "rule_print.h"

static const char ipset_key_map[CONTROL_IPSET_TYPE_MAX][AC_IPSET_SETKEY_MAXLEN + 1] = {
	CONTROL_MACWHITELIST_SET_KEY,
	CONTROL_IPWHITELIST_SET_KEY,
	CONTROL_MACBLACKLIST_SET_KEY,
	CONTROL_IPBLACKLIST_SET_KEY
};


static int check_list_valid(const nx_json *js, const unsigned int maxnum)
{
	if (js == NULL || js->type != NX_JSON_ARRAY || js->length > maxnum) {
		return -1;
	}
	return 0;
}


static void id_list_cleanup(unsigned int *list)
{}


/*init id which type is 'unsigned int';
if the function occur failed, it will free all memory alloced by itself.
*/
static int id_list_init(unsigned int **list, unsigned int *number, const nx_json *js, unsigned int min, unsigned int max)
{
	int ret = -1, idx = 0;
	const nx_json *js_elem = NULL;
	if (js == NULL || js->type == NX_JSON_NULL || list == NULL || number == NULL) {
		AC_ERROR("invalid parameter");
		return -1;
	}

	*list = malloc(sizeof(unsigned int) * js->length);
	if (*list == NULL) {
		return -1;
	}

	for (idx = 0; idx < js->length; ++idx) {
		js_elem = nx_json_item(js, idx);
		if (js_elem->int_value > max || js_elem->int_value < min) {
			return -1;
		}
		(*list)[idx] = js_elem->int_value;
	}
	*number = js->length;
	return 0;
}


/*init c string;
if the function occur failed, it will free all memory alloced by itself.*/
static int str_list_init(char *list[], unsigned int *number, const nx_json *js)
{
	int ret = -1, idx = 0;
	const nx_json *js_elem = NULL;

	if (list == NULL || number == NULL || js == NULL || js->type == NX_JSON_NULL) {
		AC_ERROR("invalid parameters");
		return -1;
	}

	/*the value of list item is null, it will be set in nx_json_string_map */
	for (idx = 0; idx < js->length; ++idx) {
		js_elem = nx_json_item(js, idx);
		if (nx_json_string_map(&list[idx], js_elem, "Action", AC_ACTION_MAXNAMELEN) == -1) {
			goto fail;
		}
	}
	*number = js->length;
	return 0;
fail:
	/*if occur failed, free memory*/
	for (idx = 0; idx < js->length; ++idx) {
		if (list[idx]) {
			free(list[idx]); /*alloced in current function*/
			list[idx] = NULL;
		}
	}
	return -1;
}


/*clean rule item, such as free memory*/
static void ac_rule_item_cleanup(struct ac_rule_item *rule_item)
{
	int idx = 0;
	if (rule_item == NULL) {
		return;
	}

	if (rule_item->src_zone_num && rule_item->src_zone_ids) {
		free(rule_item->src_zone_ids);
		rule_item->src_zone_ids = NULL;
		rule_item->src_zone_num = 0;
	}

	if (rule_item->src_ipgrp_num && rule_item->src_ipgrp_ids) {
		free(rule_item->src_ipgrp_ids);
		rule_item->src_ipgrp_ids = NULL;
		rule_item->src_ipgrp_num = 0;
	}

	if (rule_item->dst_zone_num && rule_item->dst_zone_ids) {
		free(rule_item->dst_zone_ids);
		rule_item->dst_zone_ids = NULL;
		rule_item->dst_zone_num = 0;
	}

	if (rule_item->dst_ipgrp_num && rule_item->dst_ipgrp_ids) {
		free(rule_item->dst_ipgrp_ids);
		rule_item->dst_ipgrp_ids = NULL;
		rule_item->dst_ipgrp_num = 0;
	}

	if (rule_item->action_num) {
		for (idx = 0; idx < rule_item->action_num; ++idx) {
			if (rule_item->action[idx]) {
				free(rule_item->action[idx]);
				rule_item->action[idx] = NULL;
			}
		}
		rule_item->action_num = 0;
	}

	return;
}


/*init ac rule;
if the function occur failed, it will free all memory alloced by itself.*/
static int ac_rule_item_init(struct ac_rule_item *rule_item, const nx_json *js)
{
	const nx_json *js_elem = NULL;
	if (rule_item == NULL || js == NULL) {
		AC_ERROR("invalid parameters\n");
		return -1;
	}

	bzero(rule_item, sizeof(struct ac_rule_item));

	js_elem = nx_json_get(js, AC_RULE_ID);
	if (nx_json_integer_map(&rule_item->id, js_elem, AC_RULE_ID, AC_RULE_MINID, AC_RULE_MAXID) == -1) {
		goto fail;
	}

	js_elem = nx_json_get(js, AC_RULE_SRC_ZONEIDS_KEY);
	if (check_list_valid(js_elem, AC_ID_MAXNUM_PERMATCH) == 0) {
		if (id_list_init(&rule_item->src_zone_ids, &rule_item->src_zone_num,
							js_elem, AC_ZONE_MINID, AC_ZONE_MAXID) == -1) {
			goto fail;
		}
	}

	js_elem = nx_json_get(js, AC_RULE_SRC_IPGRPIDS_KEY);
	if (check_list_valid(js_elem, AC_ID_MAXNUM_PERMATCH) == 0) {
		if (id_list_init(&rule_item->src_ipgrp_ids, &rule_item->src_ipgrp_num,
							js_elem, AC_IPGRP_MINID, AC_IPGRP_MAXID) == -1) {
			goto fail;
		}
	}

	js_elem = nx_json_get(js, AC_RULE_DST_ZONEIDS_KEY);
	if (check_list_valid(js_elem, AC_ID_MAXNUM_PERMATCH) == 0) {
		if (id_list_init(&rule_item->dst_zone_ids, &rule_item->dst_zone_num,
							js_elem, AC_ZONE_MINID, AC_ZONE_MAXID) == -1) {
			goto fail;
		}
	}

	js_elem = nx_json_get(js, AC_RULE_DST_IPGRPIDS_KEY);
	if (check_list_valid(js_elem, AC_ID_MAXNUM_PERMATCH) == 0) {
		if (id_list_init(&rule_item->dst_ipgrp_ids, &rule_item->dst_ipgrp_num,
							js_elem, AC_IPGRP_MINID, AC_IPGRP_MAXID) == -1) {
			goto fail;
		}
	}

	js_elem = nx_json_get(js, AC_RULE_PROTOIDS_KEY);
	if (check_list_valid(js_elem, AC_ID_MAXNUM_PERMATCH) == 0) {
		if (id_list_init(&rule_item->proto_ids, &rule_item->proto_num,
							js_elem, AC_PROTO_MINID, AC_PROTO_MAXID) == -1) {
			goto fail;
		}
	}

	js_elem = nx_json_get(js, AC_ACTION_KEY);
	if (check_list_valid(js_elem, AC_ACTION_MAXNUM) == 0) {
		if (str_list_init(rule_item->action, &rule_item->action_num, js_elem) == -1) {
			goto fail;
		}
	}

	return 0;
fail:
	ac_rule_item_cleanup(rule_item);
	return -1;
}


/*parse ac rule*/
int do_parse_ac_rule(const nx_json *js, struct ac_rule *rule, const char *key)
{
	int ret = -1;
	if (js == NULL || rule == NULL) {
		AC_ERROR("invalid parameters\n");
		return ret;
	}

	ret = nx_json_array_map(&rule->items, &rule->number, js,
							key, RULE_MAXNUM,
							struct ac_rule_item, ac_rule_item_init, ac_rule_item_cleanup);
	if (ret == -1) {
		AC_ERROR("Parse %s failed\n", key);
	}
	rule->updated = 1;
	return ret;
}


/*Display details of rule*/
void display_raw_ac_rule(struct ac_rule *rule)
{
	int i = 0, j = 0;
	if (rule == NULL) {
		AC_ERROR("invalid parameter.");
		return;
	}

	if (rule->number == 0) {
		AC_DEBUG("No rule to display\n");
		return;
	}


	AC_DEBUG("**********RULE ITEMS START**********\n\n");
	AC_PRINT("Total number of control rule:%d\n", rule->number);
	for (i = 0; i < rule->number; i++) {
		struct ac_rule_item *item = &rule->items[i];
		AC_PRINT("-----------------Rule%d start---------------\n", i);
		AC_PRINT("id:%d\n", item->id);

		AC_PRINT("src zone number:%d [", item->src_zone_num);
		for (j = 0; j < item->src_zone_num; ++j) {
			AC_PRINT("%d, ", item->src_zone_ids[j]);
		}
		AC_PRINT("]\n");

		AC_PRINT("src ipgrp number:%d [", item->src_ipgrp_num);
		for (j = 0; j < item->src_ipgrp_num; ++j) {
			AC_PRINT("%d, ", item->src_ipgrp_ids[j]);
		}
		AC_PRINT("]\n");

		AC_PRINT("dst zone number:%d [", item->dst_zone_num);
		for (j = 0; j < item->dst_zone_num; ++j) {
			AC_PRINT("%d, ", item->dst_zone_ids[j]);
		}
		AC_PRINT("]\n");

		AC_PRINT("dst ipgrp number:%d [", item->dst_ipgrp_num);
		for (j = 0; j < item->dst_ipgrp_num; ++j) {
			AC_PRINT("%d, ", item->dst_ipgrp_ids[j]);
		}
		AC_PRINT("]\n");

		AC_PRINT("proto_num number:%d [", item->proto_num);
		for (j = 0; j < item->proto_num; ++j) {
			AC_PRINT("%u, ", item->proto_ids[j]);
		}
		AC_PRINT("]\n");

		AC_PRINT("action number:%d [", item->action_num);
		for (j = 0; j < item->action_num; ++j) {
			AC_PRINT("%s, ", item->action[j]);
		}
		AC_PRINT("]\n");

		AC_PRINT("-----------------Rule%d end---------------\n\n", i);
	}
	AC_DEBUG("**********RULE ITEMS END**********\n\n\n");
}


/*
Description:Parse rule of control,all memory alloced by itself.
If parse success, the caller should response for freeing memory.
*/
int do_parse_control_rule(const nx_json *js, struct ac_rule *rule, const char *key)
{
	return do_parse_ac_rule(js, rule, key);
}


/*Display details of control rule*/
void display_raw_control_rule(struct ac_rule *rule)
{
	return display_raw_ac_rule(rule);
}


int do_parse_audit_rule(const nx_json *js, struct ac_rule *rule, const char *key)
{
	return do_parse_ac_rule(js, rule, key);
}


void display_raw_audit_rule(struct ac_rule *rule)
{
	return display_raw_ac_rule(rule);
}


/*
Description:Parse ipset name of control,all memory alloced by itself.
If parse success, the caller should response for freeing memory.
*/
int do_parse_ac_set(const nx_json *js, struct ac_set *set)
{
	int idx = 0, number = 0;
	const nx_json *js_elem = NULL;

	if (js == NULL || set == NULL) {
		AC_ERROR("invalid parameters\n");
		return -1;
	}

	set->ipsets = (char**)calloc(set->number, sizeof(char*));
	if (set->ipsets == NULL) {
		AC_ERROR("Out of memory");
		goto fail;
	}

    for (idx = 0; idx < set->number; ++idx) {
    	js_elem = nx_json_get(js, ipset_key_map[idx]);
    	/*we need check:the property must be set*/
    	if (js_elem->type != NX_JSON_NULL) {
    		if (nx_json_string_map(&set->ipsets[idx], js_elem, ipset_key_map[idx], AC_IPSET_MAXNAMELEN) == -1) {
    			AC_ERROR("Parse %s failed\n", ipset_key_map[idx]);
    			goto fail;
    		}
			set->updated |= (1 << idx);
    	}
    }

    return 0;
fail:
	if (set->ipsets) {
		for (idx = 0; idx < set->number; ++idx) {
			if (set->updated & (1<<idx)) {
				if (set->ipsets[idx]) {
					free(set->ipsets[idx]);
					set->ipsets[idx] = NULL;
				}
			}
		}
		free(set->ipsets);
		set->ipsets = NULL;
	}

	return -1;
}


/*Display set of control*/
static void display_raw_ac_set(struct ac_set *set)
{
	int idx = 0, updated_num = 0;
	if (set == NULL) {
		AC_ERROR("invalid parameters");
		return;
	}

	if (set->number == 0) {
		AC_DEBUG("no set to display");
		return;
	}
	for (idx = 0; idx < set->number; ++idx) {
		if (set->updated & (1 << idx)) {
			++updated_num;
		}
	}
	AC_DEBUG("total_num=%d updated_num=%d\n\n", set->number, updated_num);
	for (idx = 0; idx < set->number; ++idx) {
		if ((set->updated & (1 << idx)) && set->ipsets[idx]) {
			AC_PRINT("set%d: key=%s value=%s\n", idx, ipset_key_map[idx], set->ipsets[idx]);
		}
	}
	AC_PRINT("\n");
}


int do_parse_control_set(const nx_json *js, struct ac_set *set)
{
	if (js == NULL || set == NULL) {
		AC_ERROR("invalid parameter.");
		return -1;
	}
	set->number = CONTROL_IPSET_TYPE_MAX;
	return do_parse_ac_set(js, set);
}


void display_raw_control_set(struct ac_set *set)
{
	AC_DEBUG("---------------raw control set start--------------\n\n");
	display_raw_ac_set(set);
	AC_DEBUG("---------------raw control set end--------------\n\n");
}


int do_parse_audit_set(const nx_json *js, struct ac_set *set)
{
	if (js == NULL || set == NULL) {
		AC_ERROR("invalid parameter.");
		return -1;
	}
	set->number = AUDIT_IPSET_TYPE_MAX;
	return do_parse_ac_set(js, set);
}


void display_raw_audit_set(struct ac_set *set)
{
	AC_DEBUG("---------------raw audit set start--------------\n\n");
	display_raw_ac_set(set);
	AC_DEBUG("---------------raw audit set end--------------\n\n");
}


static void free_ac_set(struct ac_set *set)
{
	int idx = 0;
	if (set) {
		for (idx = 0; idx < set->number; ++idx) {
			if (set->ipsets[idx]){
				free(set->ipsets[idx]);
				set->ipsets[idx] = NULL;
			}
		}
		free(set->ipsets);
	}
}


static void free_ac_rule(struct ac_rule *rule)
{
	int idx = 0;
	if (rule) {
		for (idx = 0; idx < rule->number; ++idx) {
			ac_rule_item_cleanup(&rule->items[idx]);
		}
		free(rule->items);
	}
}


void free_ac_config(struct ac_config *config) {
	if (config) {
		free_ac_rule(&config->rule);
		free_ac_set(&config->set);
		free(config);
	}
}
