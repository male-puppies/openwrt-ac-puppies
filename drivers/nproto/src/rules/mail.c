
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"

/*
+OK Welcome to XXXmail Mail Pop3 Server
*/
np_rule_t inner_pop3 = {
	.name_rule = "pop3",
	.name_app = "e-mail",
	.name_service = "e-mail",

	.ID = NP_INNER_RULE_POP3,
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
			.type = NP_LNM_NONE,
		},
		.ctm_num = 1, /*  */
		.ctm_relation = NP_CTM_AND,
		.ctm = {
			{
				.match = {
					.type = MHTP_REGEXP,
					.offset = 0,
					.deep = 48,
					.patt = "/^\\+ok\\b.*pop3\\b/i",
				},
			},
		},
	},

	/* callback's. */
};

/*
220 XXX.cn Anti-spam GT for Coremail System
*/
np_rule_t inner_smtp = {
	.name_rule = "smtp",
	.name_app = "e-mail",
	.name_service = "e-mail",

	.ID = NP_INNER_RULE_SMTP,
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
			.type = NP_LNM_NONE,
		},
		.ctm_num = 1, /*  */
		.ctm_relation = NP_CTM_AND,
		.ctm = {
			{
				.match = {
					.type = MHTP_REGEXP,
					.offset = 0,
					.deep = 48,
					.patt = "/^220[\\x09-\\x0d -~]*.*(smtp|mail)/i",
				},
			},
		},
	},

	/* callback's. */
};
