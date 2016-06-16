
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"

/*
SSH-2.0-OpenSSH_5.3
*/
np_rule_t inner_ssh = {
	.name_rule = "ssh",
	.name_app = "ssh2",
	.name_service = "ssh2",

	.ID = NP_INNER_RULE_SSH,
	.priority = NP_RULE_PRI_MAX,

	.rule_type = TP_RULE_BASE,
	.refs_type = NP_REF_NONE,

	.enable_http = 0,

	/* layer 4 match. */
	.enable_l4 = 1,
	.l4 = {
		.proto = IPPROTO_TCP,
	},

	/* layer 7 context. */
	.enable_l7 = 1,
	.l7 = {
		.dir = NP_FLOW_DIR_S2C,
		.lnm = {
			.type = NP_LNM_RANGE,
			.range[0][0] = 8,
			.range[0][1] = 64,
		},
		.ctm_num = 1, /*  */
		.ctm_relation = NP_CTM_AND,
		.ctm = {
			{
				.type_match = MHTP_REGEXP,
				.offset = 0,
				.deep = 16,
				.patt = "/^SSH-[12]\\.[0-9]-/i",
			},
		},
	},

	/* callback's. */
};
