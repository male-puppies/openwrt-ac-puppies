
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"

/*
# NTP 
ntp
^([\x13\x1b\x23\xd3\xdb\xe3]|[\x14\x1c$].......?.?.?.?.?.?.?.?.?[\xc6-\xff])
*/
np_rule_t inner_NTP = {
	.name_rule = "NTP",
	.name_app = "NTP",
	.name_service = "Network Time Protocol",

	.ID = NP_INNER_RULE_NTP,
	.priority = NP_RULE_PRI_MAX,

	.rule_type = TP_RULE_BASE | TP_RULE_FIN,
	.refs_type = NP_REF_NONE,

	.enable_http = 0,

	/* layer 4 match. */
	.enable_l4 = 1,
	.l4 = {
		.proto = IPPROTO_UDP,
		.ports[0] = 123,
	},

	/* layer 7 context. */
	.enable_l7 = 1,
	.l7 = {
		.dir = NP_FLOW_DIR_C2S,
		.lnm = {
			.type = NP_LNM_LIST,
			.list[0] = 48,
		},
		.ctm_num = 0, /*  */
	},

	/* callback's. */
};
