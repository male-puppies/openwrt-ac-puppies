#include <stdlib.h>
#include <string.h>
#include <ntrack_nacs.h>
#include <ntrack_log.h>
#include <rule_table.h>
#include <cJSON.h>

static cJSON* create_ipgrp_array(uint64_t ipgrp_bits)
{
	#define IPGRP_BITS_SIZE 64
	int i = 0;
	cJSON *array = cJSON_CreateArray();
	if (array == NULL) {
		return NULL;
	}
	for (i = 0; i < IPGRP_BITS_SIZE; ++i) {
		if (ipgrp_bits & (1ULL << i)) {
			cJSON *item = cJSON_CreateNumber(i);
			if (item == NULL) {
				goto failed;
			}
			cJSON_AddItemToArray(array, item);
		}
	}
	#undef IPGRP_BITS_SIZE
	return array;

failed:
	cJSON_Delete(array);
	return NULL;
}

char *trans_aclog(nacs_msg_t *msg, int *len)
{
	int n = 0;
	char *out = NULL, buf[256];
	cJSON *root = NULL,*user = NULL, *flow = NULL, *rule = NULL, *actions = NULL;

	root = cJSON_CreateObject();
	user = cJSON_CreateObject();
	flow = cJSON_CreateObject();
	rule = cJSON_CreateObject();
	actions = cJSON_CreateArray();
	if (!root || !user || !flow ||!rule || !actions) {
		nt_error("trans_aclog failed: no memory\n");
		goto failed;
	}

	cJSON_AddStringToObject(root, "cmd", "aclog_add");
	cJSON_AddStringToObject(root, "ruletype",
				msg->rule_type == RULE_TYPE_CONTROL ? "CONTROL": "AUDIT");
	cJSON_AddStringToObject(root, "subtype",
				msg->rule_sub_type == RULE_SUB_TYPE_SET ? "SET": "RULE");
	cJSON_AddItemToObject(root, "actions", actions);
	cJSON_AddItemToObject(root, "user", user);
	cJSON_AddItemToObject(root, "flow", flow);
	cJSON_AddItemToObject(root, "rule", rule);
	cJSON_AddNumberToObject(root, "time_stamp", msg->time_stamp);

	if (msg->actions & AC_ACCEPT) {
		cJSON_AddItemToArray(actions, cJSON_CreateString("ACCEPT"));
	}
	if (msg->actions & AC_REJECT) {
		cJSON_AddItemToArray(actions, cJSON_CreateString("REJECT"));
	}
	if (msg->actions & AC_AUDIT) {
		cJSON_AddItemToArray(actions, cJSON_CreateString("AUDIT"));
	}

	n = sprintf(buf, FMT_MAC_STR, FMT_MAC(msg->macaddr));
	if (n > 0) {
		cJSON_AddStringToObject(user, "mac", buf);
	}
	n = sprintf(buf, "%u.%u.%u.%u", NIPQUAD(msg->src_ip));
	if (n > 0) {
		cJSON_AddStringToObject(user, "ip", buf);
	}

	cJSON_AddNumberToObject(flow, "src_ip", msg->src_ip);
	cJSON_AddNumberToObject(flow, "dst_ip", msg->dst_ip);
	cJSON_AddNumberToObject(flow, "src_port", msg->src_port);
	cJSON_AddNumberToObject(flow, "dst_port", msg->dst_port);
	cJSON_AddNumberToObject(flow, "proto", msg->proto);

	if (msg->rule_sub_type == RULE_SUB_TYPE_RULE) {
		cJSON *ipgrp_arr = NULL;
		cJSON_AddNumberToObject(rule, "rule_id", msg->u.rule.rule_id);
		cJSON_AddNumberToObject(rule, "src_zone", msg->u.rule.src_zone);
		cJSON_AddNumberToObject(rule, "dst_zone", msg->u.rule.dst_zone);
		cJSON_AddNumberToObject(rule, "proto_id", msg->u.rule.proto_id);

		if (ipgrp_arr = create_ipgrp_array(msg->u.rule.src_ipgrp_bits)) {
			cJSON_AddItemToObject(rule, "src_ipgrp_bits", ipgrp_arr);
		}

		if (ipgrp_arr = create_ipgrp_array(msg->u.rule.dst_ipgrp_bits)) {
			cJSON_AddItemToObject(rule, "dst_ipgrp_bits", ipgrp_arr);
		}
	}
	else {
		#define IPSET_TYPE_MAXLEN 32
		char ipset_type[AC_IPSET_TYPE_MAX][IPSET_TYPE_MAXLEN] = {
				"MACWHITELIST", "IPWHITELIST",
				"MACBLACKLIST", "IPBLACKLIST"
			};
		if (msg->u.set.set_type >= 0 && msg->u.set.set_type < AC_IPSET_TYPE_MAX) {
			cJSON_AddStringToObject(rule, "set_name", ipset_type[msg->u.set.set_type]);
		}
	}

	out = cJSON_Print(root);
	*len = strlen(out);
	cJSON_Delete(root);
	return out;
failed:
	cJSON_Delete(root);
	cJSON_Delete(user);
	cJSON_Delete(flow);
	cJSON_Delete(rule);
	cJSON_Delete(actions);
	return NULL;
}
