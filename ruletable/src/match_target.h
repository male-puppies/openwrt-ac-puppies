
#ifndef _MATCH_TARGET_H
#define _MATCH_TARGET_H

struct ac_flow_match* generate_flow_match(
	unsigned int *src_zone_ids, unsigned int srz_zone_num,
	unsigned int *src_ipgrp_ids, unsigned int src_ipgrp_num,
	unsigned int *dst_zone_ids, unsigned int dst_zone_num,
	unsigned int *dst_ipgrp_ids, unsigned int dst_ipgrp_num);

void display_ac_flow_match(const struct ac_flow_match *flow_match);

struct ac_proto_match* generate_proto_match(
	unsigned int *proto_ids, 
	unsigned int proto_num);

void display_ac_proto_match(const struct ac_proto_match* proto_match);


struct ac_target* generate_target(char *action[], unsigned int action_num);
void display_ac_target(const struct ac_target *target);
#endif