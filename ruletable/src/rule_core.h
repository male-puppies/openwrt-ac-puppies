#ifndef _RULE_CORE_H
#define _RULE_CORE_H

int do_commit_config(const char *config_str, unsigned int len);
int do_fetch_config();
int do_parse_config(const char *json_str, unsigned int size);
#endif