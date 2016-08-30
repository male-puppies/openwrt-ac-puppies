#include <stdlib.h>
#include <strings.h>
#include <rule_table.h>
#include "rule_parse.h"
#include "rule_print.h"

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
	int idx_offset = 0;
	flow_id_t *base = NULL;

	if (flow_match == NULL) {
		AC_ERROR("invalid parameter: flow_match is NULL\n");
		return;
	}
	AC_DEBUG("---------FLOW_MATCH START---------\n\n");
	AC_PRINT("	match_size:%d addr:%p elems addr:%p align:%d\n\n",
				flow_match->match_size, flow_match,
				flow_match->elems, __alignof__(struct ac_flow_match));
	base = (flow_id_t*)flow_match->elems;
	for (int i = 0; i < AC_FLOW_TYPE_MAX; ++i) {
		AC_PRINT("	%s(number=%d):[", flow_match_map[i], flow_match->number[i]);

		for (int j = 0; j < flow_match->number[i]; ++j) {
			AC_PRINT("%d, ", (flow_id_t)(*(base + idx_offset + j)));
		}
		AC_PRINT("]\n");
		idx_offset += flow_match->number[i];
	}
	AC_PRINT("\n");
	AC_DEBUG("---------FLOW_MATCH END---------\n\n\n\n");
}


/*
*Notice: type of input parameters is "unsinged int",
*it differents from flow_id_t
*/
struct ac_flow_match* generate_flow_match(
	unsigned int *src_zone_ids, unsigned int src_zone_num,
	unsigned int *src_ipgrp_ids, unsigned int src_ipgrp_num,
	unsigned int *dst_zone_ids, unsigned int dst_zone_num,
	unsigned int *dst_ipgrp_ids, unsigned int dst_ipgrp_num)
{
	struct ac_flow_match *flow_match = NULL;
	unsigned int elems_num = 0, match_size = 0, idx_offset = 0, elem_size = 0;
	flow_id_t *base = NULL;
	unsigned int *ids = NULL;	/*must be same with input parameters*/

	if (src_zone_ids == NULL || src_zone_num == 0 ||
		src_ipgrp_ids == NULL || src_ipgrp_num == 0 ||
		dst_zone_ids == NULL || dst_zone_num == 0 ||
		dst_ipgrp_ids == NULL || dst_ipgrp_num == 0) {
		AC_ERROR("invalid parameters\n");
		return NULL;
	}

	elem_size = sizeof(flow_id_t);
	elems_num = src_zone_num + src_ipgrp_num + dst_zone_num + dst_ipgrp_num;

	/*notice:itself should be aligned*/
	match_size = AC_ALIGN(elems_num * elem_size + AC_ALIGN(sizeof(struct ac_flow_match)));
	flow_match = (struct ac_flow_match*)malloc(match_size);
	if (flow_match == NULL) {
		AC_ERROR("Out of memory\n");
		return NULL;
	}
	bzero(flow_match, match_size);
	flow_match->match_size = match_size;
	flow_match->number[AC_FLOW_TYPE_SRCZONEID] = src_zone_num;
	flow_match->number[AC_FLOW_TYPE_SRCIPGRPID] = src_ipgrp_num;
	flow_match->number[AC_FLOW_TYPE_DSTZONEID] = dst_zone_num;
	flow_match->number[AC_FLOW_TYPE_DSTIPGRPID] = dst_ipgrp_num;
	base = flow_match->elems;

	for (int i = 0; i < AC_FLOW_TYPE_MAX; ++i) {
		switch(i) {
			case AC_FLOW_TYPE_SRCZONEID:
				ids = src_zone_ids;
				break;

			case AC_FLOW_TYPE_SRCIPGRPID:
				ids = src_ipgrp_ids;
				break;

			case AC_FLOW_TYPE_DSTZONEID:
				ids = dst_zone_ids;
				break;

			case AC_FLOW_TYPE_DSTIPGRPID:
				ids = dst_ipgrp_ids;
				break;

			default:
				ids = NULL;
				AC_INFO("unknown flow type:%d\n", i);
				break;
		}

		for (int j = 0; ids && j < flow_match->number[i]; ++j) {
			*(base + idx_offset + j) = (flow_id_t)ids[j];
		}
		idx_offset += flow_match->number[i];
	}
	//display_ac_flow_match(flow_match);
	return flow_match;
}


void display_ac_proto_match(const struct ac_proto_match* proto_match)
{
	#define IDS_NUM_PER_ROW 8
	proto_id_t *base = NULL;
	if (proto_match == NULL) {
		AC_ERROR("invalid parameter: proto_match is NULL\n");
		return;
	}
	AC_DEBUG("---------PROTO_MATCH START---------\n\n");
	AC_PRINT("	match_size:%d addr:%p elems addr:%p align:%d\n\n",
				proto_match->match_size, proto_match,
				proto_match->elems, __alignof__(struct ac_proto_match));

	AC_PRINT("	%s(number=%d):[", AC_RULE_PROTOIDS_KEY, proto_match->number);
	base = (proto_id_t*)proto_match->elems;
	for (int i = 0; i < proto_match->number; ++i) {
		AC_PRINT("%u, ", *(base + i));
		if (i && (i % IDS_NUM_PER_ROW) == 0) {
			AC_PRINT("\n");
		}
	}

	AC_PRINT("]\n\n");
	AC_DEBUG("---------PROTO_MATCH END---------\n\n\n\n");
	#undef IDS_NUM_PER_ROW
}


struct ac_proto_match* generate_proto_match(
	unsigned int *proto_ids,
	unsigned int proto_num)
{
	int match_size = 0;
	proto_id_t *base = NULL;
	struct ac_proto_match *proto_match = NULL;

	if (proto_ids == NULL || proto_num == 0) {
		AC_ERROR("invalid parameters\n");
		return NULL;
	}

	/*notice:itself should be aligned*/
	match_size =AC_ALIGN(proto_num * sizeof(proto_id_t) + AC_ALIGN(sizeof(struct ac_proto_match)));
	proto_match = (struct ac_proto_match*)malloc(match_size);
	if (proto_match == NULL) {
		AC_ERROR("Out of memory\n");
		return NULL;
	}

	bzero(proto_match, match_size);
	proto_match->number = proto_num;
	proto_match->match_size = match_size;
	proto_match->protoid_sort = AC_PROTOID_SORT_ASC; /*fixme: we assume it sorted in asc*/
	base = (proto_id_t*)proto_match->elems;

	for (int i = 0; i < proto_match->number; ++i) {
		*(base + i)= (proto_id_t)proto_ids[i];
	}
	//display_ac_proto_match(proto_match);
	return proto_match;
}


void display_ac_target(const struct ac_target *target)
{
	if (target == NULL) {
		AC_ERROR("invalid parameter: target is NULL\n");
		return;
	}
	AC_DEBUG("--------TARGET START------\n\n");
	AC_PRINT("target_size:%d addr:%p flags:%u [", target->size, target, target->flags);
	for (int i = 0; i < AC_ACTION_MAX; ++i) {
		if (target->flags & target_flag_map[i]) {
			AC_PRINT("%s, ", target_map[i]);
		}
	}
	AC_PRINT("]\n\n");
	AC_DEBUG("---------TARGET END-------\n\n\n\n");
}


struct ac_target *generate_target(char *action[], unsigned int action_num)
{
	struct ac_target *target = NULL;
	unsigned int flags = 0, size = 0;
	if (action == NULL || action_num == 0) {
		AC_ERROR("invalid parameters\n");
		return NULL;
	}
	size = AC_ALIGN(sizeof(struct ac_target));
	target = (struct ac_target*)malloc(size);
	if (target == NULL) {
		AC_ERROR("Out of memory\n");
		return NULL;
	}
	bzero(target, sizeof(struct ac_target));
	target->size = size;
	for (int i = 0; i < action_num; ++i) {
		for (int j = 0; j < AC_ACTION_MAX; ++j) {
			if (strcasecmp(action[i], target_map[j]) == 0) {
				target->flags |= target_flag_map[j];
			}
		}
	}
	//display_ac_target(target);
	return target;
}