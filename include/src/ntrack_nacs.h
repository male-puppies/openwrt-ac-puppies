#ifndef _NTRACK_NACS_H
#define _NTRACK_NACS_H

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

#endif