
#ifndef _CONTROL_H
#define _CONTROL_H
#include "nxjson.h"
#include "rule_parse.h"

int do_parse_control_set(const nx_json *js, struct ac_set *set);
int do_parse_control_rule(const nx_json *js, struct ac_rule *rule);
void display_raw_control_rule(struct ac_rule *rule);
void display_raw_control_set(struct ac_set *set);

int do_parse_audit_set(const nx_json *js, struct ac_set *set);
int do_parse_audit_rule(const nx_json *js, struct ac_rule *rule);
void display_raw_audit_rule(struct ac_rule *rule);
void display_raw_audit_set(struct ac_set *set);

void free_ac_config(struct ac_config *config);
#endif