
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"

/*
vnc
# Assumes single digit major and minor version numbers 
# This message should be all alone in the first packet, so ^$ is appropriate
^rfb 00[1-9]\.00[0-9]\x0a$
*/
np_rule_t inner_mysql = {
	.name_rule = "mysql",
	.name_app = "mysql",
	.name_service = "Database",

	.ID = NP_INNER_RULE_MYSQL,
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
		.dir = NP_FLOW_DIR_S2C,
		.lnm = {
			.type = NP_LNM_MATCH,
			.offset = 0,
			.fixed = 4,
			.width = 2,
		},
		.ctm_num = 1, /*  */
		.ctm_relation = NP_CTM_AND,
		.ctm = {
			{
				.match = {
					.type = MHTP_REGEXP,
					.patt = "/^\\x0a[0-9]\\x2e[0-9]\\x2e[0-9][0-9]\\x0/m",
					.offset = 4,
				},
			},
		},
	},

	/* callback's. */
};
