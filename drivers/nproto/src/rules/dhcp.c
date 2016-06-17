
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"

/*
UDP, 67,68
^[\x01\x02][\x01- ]\x06.*c\x82sc
*/
np_rule_t inner_dhcp = {
	.name_rule = "dhcp",
	.name_app = "dhcp",
	.name_service = "network",

	.ID = NP_INNER_RULE_DHCP,
	.priority = NP_RULE_PRI_MAX,

	.rule_type = TP_RULE_BASE,
	.refs_type = NP_REF_NONE,

	.enable_http = 0,

	/* layer 4 match. */
	.enable_l4 = 1,
	.l4 = {
		.proto = IPPROTO_UDP,
		.ports[0] = 67,
		.ports[1] = 68,
	},

	/* layer 7 context. */
	.enable_l7 = 0,
	.l7 = {
		.dir = NP_FLOW_DIR_ANY,
		.lnm = {
			.type = NP_LNM_NONE,
		},
		.ctm_num = 1, /*  */
		.ctm_relation = NP_CTM_AND,
		.ctm = {
			{
				.type_match = MHTP_REGEXP,
				.offset = 0,
				.deep = 256,
				.patt = "/^[\\x01\\x02][\\x01- ]\\x06.*c\\x82sc/m",
			},
		},
	},

	/* callback's. */
};
