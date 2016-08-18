#ifndef _NTRACK_NACS_H
#define _NTRACK_NACS_H
#include <ntrack_flow.h>
#include <ntrack_packet.h>
typedef struct {
	/*table related*/
	uint8_t rule_type, rule_sub_type;
	union {
		struct {	
			uint16_t 	rule_id;
			uint8_t 	src_zone, dst_zone;
			uint64_t 	src_ipgrp_bits, dst_ipgrp_bits;
			uint32_t	proto_id;	/*crc(appname)*/
		}rule;

		struct {
			uint8_t set_type;
		}set;
	}u;
	/*flow related*/
	uint32_t 	src_ip, dst_ip;
	uint16_t	src_port, dst_port;
	uint8_t		proto;		/*tcp/udp...*/
	uint8_t 	actions;	/*accept, reject, audit*/
	unsigned long time_stamp;
}nacs_msg_t;

int do_ac_table_hk(	
	struct net_device *in,
	struct net_device *out,
	struct sk_buff *skb, 
	flow_info_t *fi, 
	user_info_t *ui,
	user_info_t *pi);

int do_ac_table_cb(nt_packet_t *pkt, __u32 proto_new);

#endif