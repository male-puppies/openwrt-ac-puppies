/*
	Implementing core functions of the tool.
*/

#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include "rule_print.h"
#include <rule_table.h>
#include "rule_parse.h"
#include "audit_control.h"
#include "rule_entry.h"
#include "json_utility.h"
#include "rule_ipc.h"

/*mantain config*/
struct ac_global_config {
	struct ac_config *control;
	struct ac_config *audit;
};

static struct ac_global_config s_config;


static int init_global_config()
{
	bzero(&s_config, sizeof(struct ac_global_config));
	s_config.control = (struct ac_config*)malloc(sizeof(struct ac_config));
	if (s_config.control == NULL) {
		goto fail;
	}	

	s_config.audit = (struct ac_config*)malloc(sizeof(struct ac_config));
	if (s_config.audit == NULL) {
		goto fail;
	}

	bzero(s_config.control, sizeof(struct ac_config));
	bzero(s_config.audit, sizeof(struct ac_config));
	return 0;
fail:
	if (s_config.control) {
		free(s_config.control);
		s_config.control = NULL;
	}
	return -1;
}


static void free_global_config()
{
	free_ac_config(s_config.control);
	s_config.control = NULL;
	free_ac_config(s_config.audit);
	s_config.audit = NULL;
}


/*
	Parse json string to c data structure, and then store them in global config
*/
int do_parse_config(const char *json_str, unsigned int size)
{
	int ret = -1;
	char *json_str_cpy = NULL;
	const nx_json *js = NULL, *js_elem = NULL;
	
	if (json_str == NULL || size <= 0) {
		AC_ERROR("invalid parameters.");
		return -1;
	}

	json_str_cpy = malloc(sizeof(char) * (size + 1));
	if (json_str_cpy == NULL) {
		goto out;
	}
	bzero(json_str_cpy, size + 1);
	memcpy(json_str_cpy, json_str, size);
	js = nx_json_parse_utf8(json_str_cpy);
	if (js == NULL) {
		AC_ERROR("config parse failed.\n");
		goto out;
	}

	if (nx_json_verify(js) != 0) {
		AC_ERROR("nxjson verify failed.\n");
		goto out;
	}

	init_global_config();
	
	/*parse control set*/
	js_elem = nx_json_get(js, CONTROL_SET_KEY);
	if (js_elem->type != NX_JSON_NULL) {
		if (do_parse_control_set(js_elem, &s_config.control->set) == 0) {
			display_raw_control_set(&s_config.control->set);
		}
	}

	/*parse audit set*/
	js_elem = nx_json_get(js, AUDIT_SET_KEY);
	if (js_elem->type != NX_JSON_NULL) {
		if (do_parse_audit_set(js_elem, &s_config.audit->set) == 0) {
			display_raw_audit_set(&s_config.audit->set);
		}
	}

	/*parse control rule*/
	js_elem = nx_json_get(js, CONTROL_RULE_KEY);
	if (js_elem->type != NX_JSON_NULL) {
		if (do_parse_control_rule(js_elem, &s_config.control->rule) == 0) {
			display_raw_control_rule(&s_config.control->rule);
		}
		else {
			goto out;
		}
	}
	
	/*parse audit rule*/
	js_elem = nx_json_get(js, AUDIT_RULE_KEY);
	if (js_elem->type != NX_JSON_NULL) {
		if (do_parse_audit_rule(js_elem, &s_config.audit->rule) == 0) {
			display_raw_audit_rule(&s_config.audit->rule);
		}
		else {
			goto out;
		}
	}

	ret = 0;
out:
	if (js != NULL) {
		nx_json_free(js);
	}
	if (json_str_cpy) {
		free(json_str_cpy);
	}
	if (ret != 0) {
		free_global_config();
	}
	return ret;
}


/*commit config to kernel*/
int do_commit_config(const char *config_str, unsigned int len) 
{
	int ret = -1;
	struct ac_repl_table_info *control_table_info = NULL;
	struct ac_repl_set_info *control_set_info = NULL;
	struct ac_repl_table_info *audit_table_info = NULL;
	struct ac_repl_set_info *audit_set_info = NULL;

	if (config_str == NULL || len <= 0) {
		return -1;
	}
	if (do_parse_config(config_str, len) != 0) {
		AC_ERROR("do_parse_config failed\n");
		return -1;
	}

	if (s_config.control->rule.updated) {
		control_table_info = generate_ac_table(&s_config.control->rule, RULE_TYPE_CONTROL);
		if (control_table_info) {
			if (do_rule_ipc_set(AC_SO_SET_REPLACE_TABLE, control_table_info, sizeof(struct ac_repl_table_info) + control_table_info->size) != 0) {
				goto out;
			}
		}
	}

	if (s_config.control->set.updated) {
		control_set_info = generate_ac_set(&s_config.control->set, RULE_TYPE_CONTROL);
		if (control_set_info) {
			if (do_rule_ipc_set(AC_SO_SET_REPLACE_SET, control_set_info, sizeof(struct ac_repl_set_info) + control_set_info->size) != 0) {
				goto out;
			}
		}	
	}

	if (s_config.audit->rule.updated) {
		audit_table_info = generate_ac_table(&s_config.audit->rule, RULE_TYPE_AUDIT);
		if (audit_table_info) {
			if (do_rule_ipc_set(AC_SO_SET_REPLACE_TABLE, audit_table_info, sizeof(struct ac_repl_table_info) + audit_table_info->size) != 0) {
				goto out;
			}
		}
	}

	if (s_config.audit->set.updated) {
		audit_set_info = generate_ac_set(&s_config.audit->set, RULE_TYPE_AUDIT);
		if (audit_set_info) {
			if (do_rule_ipc_set(AC_SO_SET_REPLACE_SET, audit_set_info, sizeof(struct ac_repl_set_info) + audit_set_info->size) != 0) {
				goto out;
			}
		}
	}

	ret = 0;
out:

	if (control_table_info) {
		free(control_table_info);
	}

	if (control_set_info) {
		free(control_set_info);
	}

	if (audit_table_info) {
		free(control_table_info);
	}

	if (audit_set_info) {
		free(audit_set_info);
	}
	free_global_config();
	return ret;
}


/*fetch_config and display.
there are four parts config  totally.

#define AC_SO_BASE_CTL 4096
#define AC_SO_SET_REPLACE_TABLE		(AC_SO_BASE_CTL)
#define AC_SO_SET_REPLACE_SET		(AC_SO_BASE_CTL + 1)
#define AC_SO_SET_MAX				AC_SO_SET_REPLACE_SET

#define AC_SO_GET_TABLE_INFO		(AC_SO_BASE_CTL)
#define AC_SO_GET_SET_INFO			(AC_SO_BASE_CTL + 1)
#define AC_SO_GET_ENTRIES			(AC_SO_BASE_CTL	+ 2)
#define AC_SO_GET_SETS      		(AC_SO_BASE_CTL	+ 3)
#define AC_SO_GET_MAX				AC_SO_GET_SETS
*/

/*
	Fetch config from kernel and print it
*/
int do_fetch_config()
{
	int i = 0;
	struct ac_repl_table_info *table = NULL;
	struct ac_repl_set_info *sets = NULL;

	for (i = 0; i < RULE_TYPE_MAX; ++i) {
		table = fetch_ac_table(i, AC_SO_GET_TABLE_INFO, AC_SO_GET_ENTRIES);
		if (table == NULL) {
			break;
		}
		display_ac_table(table);
		free(table);
		table = NULL;

		sets = fetch_ac_set(i, AC_SO_GET_SET_INFO, AC_SO_GET_SETS);
		if (sets == NULL) {
			break;
		}

		display_ac_set(sets);
		free(sets);
		sets = NULL;

	}

	if (i < RULE_TYPE_MAX) {
		return -1;
	}
	return 0;
}
