
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"

/*
revert find: -64 bytes
rdpdr.*cliprdr.*rdpsnd
*/
np_rule_t inner_RDP = {
	.name_rule = "RDP",
	.name_app = "MS-RDP",
	.name_service = "Remote-Desktop",

	.ID = NP_INNER_RULE_RDP,
	.priority = NP_RULE_PRI_MAX,

	.rule_type = TP_RULE_BASE | TP_RULE_FIN,
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
		.dir = NP_FLOW_DIR_C2S,
		.lnm = {
			.type = NP_LNM_MATCH,
			.offset = 2,
			.fixed = 0,
			.width = 2,
		},
		.ctm_num = 1, /*  */
		.ctm_relation = NP_CTM_AND,
		.ctm = {
			{
				.match = {
					.type = MHTP_REGEXP,
					.offset = -64,
					.patt = "/rdpdr.*cliprdr.*rdpsnd/m",
				},
			},
		},
	},

	/* callback's. */
};
