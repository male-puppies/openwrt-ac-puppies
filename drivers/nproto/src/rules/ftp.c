
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"

/*
TELNET 21
220 Welcome to ftp.kernel.org
220 Microsoft FTP Service
PASV
227 Entering Passive Mode (149,20,4,69,117,102).
*/
np_rule_t inner_ftp = {
	.name_rule = "ftp",
	.name_app = "ftp",
	.name_service = "ftp",

	.ID = NP_INNER_RULE_FTP,
	.priority = NP_RULE_PRI_MAX,

	.rule_type = TP_RULE_BASE | TP_RULE_FIN,
	.refs_type = NP_REF_NONE,

	.enable_http = 0,

	/* layer 4 match. */
	.enable_l4 = 1,
	.l4 = {
		.proto = IPPROTO_TCP,
		.ports[0] = 21,
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
				.match = {
					.type = MHTP_REGEXP,
					.offset = 0,
					.deep = 32,
					.patt = "/^220.*ftp/i",
				},
			},
		},
	},

	/* callback's. */
};
