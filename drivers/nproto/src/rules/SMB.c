
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"

/*
# http://www.ubiqx.org/cifs/SMB.html
#
# This pattern is lightly tested.

# Samba/SMB - Server Message Block - Microsoft Windows filesharing
# matches a NEGOTIATE PROTOCOL or TRANSACTION REQUEST command
\xffsmb[\x72\x25]
*/
np_rule_t inner_SMB = {
	.name_rule = "SMB",
	.name_app = "Samba",
	.name_service = "MS-Samba",

	.ID = NP_INNER_RULE_SMB,
	.priority = NP_RULE_PRI_MAX,

	.rule_type = TP_RULE_BASE | TP_RULE_FIN,
	.refs_type = NP_REF_NONE,

	.enable_http = 0,

	/* layer 4 match. */
	.enable_l4 = 1,
	.l4 = {
		.proto = IPPROTO_TCP,
		.ports[0] = 445,
	},

	/* layer 7 context. */
	.enable_l7 = 1,
	.l7 = {
		.dir = NP_FLOW_DIR_C2S,
		.lnm = {
			.type = NP_LNM_MATCH,
			.offset = 0,
			.fixed = 4,
			.width = 4,
		},
		.ctm_num = 1, /*  */
		.ctm_relation = NP_CTM_AND,
		.ctm = {
			{
				.match = {
					.type = MHTP_REGEXP,
					.offset = 4,
					.patt = "/^\xffsmb[\x72\x25]/i",
				},
			},
		},
	},

	/* callback's. */
};
