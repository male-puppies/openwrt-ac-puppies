/**/
#ifndef _RULE_PARSE_H
#define _RULE_PARSE_H
#include <rule_table.h>

/*There are four categories of config, of course, you can add more categories here.*/
#define RULE_MAXNUM			AC_RULE_MAXID
#define CONTROL_RULE_KEY	"ControlRule"
#define AUDIT_RULE_KEY		"AuditRule"
#define CONTROL_SET_KEY     "ControlSet"
#define AUDIT_SET_KEY     	"AuditSet"

/*the keys of ipsets, you can add more keys here.
*The lenght of keys should be less than AC_IPSET_SETKEY_MAXLEN
*/
#define AC_IPSET_SETKEY_MAXLEN 31
#define CONTROL_MACWHITELIST_SET_KEY 	"MacWhiteListSetName"
#define CONTROL_IPWHITELIST_SET_KEY 	"IpWhiteListSetName"
#define CONTROL_MACBLACKLIST_SET_KEY 	"MacBlackListSetName"
#define CONTROL_IPBLACKLIST_SET_KEY 	"IpBlackListSetName"

#define AUDIT_MACWHITELIST_SET_KEY 		"MacWhiteListSetName"
#define AUDIT_IPWHITELIST_SET_KEY 		"IpWhiteListSetName"

/*the keys of rule, you can add more keys here
*The lenght of keys should be less than AC_IPSET_SETKEY_MAXLEN
*/
#define AC_ID_MAXNUM_PERMATCH		4096	/*one match can contained*/
#define AC_FLOW_MATCH_KEY_MAXLEN    31
#define AC_RULE_ID					"Id"
#define AC_RULE_SRC_ZONEIDS_KEY		"SrcZoneIds"
#define AC_RULE_SRC_IPGRPIDS_KEY	"SrcIpgrpIds"
#define AC_RULE_DST_ZONEIDS_KEY		"DstZoneIds"
#define AC_RULE_DST_IPGRPIDS_KEY	"DstIpgrpIds"
#define AC_RULE_PROTOIDS_KEY		"ProtoIds"
#define AC_ACTION_KEY				"Actions"

#define AC_ACTION_MAXNUM		3
#define AC_ACTION_MAXNAMELEN	15
#define AC_ACTION_ACCEPT_KEY	"ACCEPT"
#define AC_ACTION_AUDIT_KEY		"AUDIT"
#define AC_ACTION_REJECT_KEY	"REJECT"

struct ac_rule_item {
	unsigned int id;
	unsigned int src_zone_num;
	unsigned int *src_zone_ids;
	unsigned int src_ipgrp_num;
	unsigned int *src_ipgrp_ids;

	unsigned int dst_zone_num;
	unsigned int *dst_zone_ids;
	unsigned int dst_ipgrp_num;
	unsigned int *dst_ipgrp_ids;
	unsigned int proto_num;
	unsigned int *proto_ids;
	unsigned int action_num;
	char *action[AC_ACTION_MAX];
};

/*
updated:whether set rule
number:the number of rule
if updated == 1 && number == 0, it means clear all rules.
*/
struct ac_rule {
	unsigned int updated;
	unsigned int number;
	struct ac_rule_item *items;
};

/*
updated:the flag of correspond ipset
number:the number of sets（fixed value CONTROL_IPSET_TYPE_MAX or AUDIT_IPSET_TYPE_MAX）
if updated & bits_offset == 1 && strlen(set_name) == 0, it means unset ipset.
*/
struct ac_set {
	unsigned int updated;
	unsigned int number;
	char **ipsets;
};

struct ac_config {
	struct ac_rule rule;
	struct ac_set set;
};
#endif