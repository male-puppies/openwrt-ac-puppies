
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"

np_rule_t inner_pop3 = {
	.name_rule = "pop3",
	.name_app = "e-mail",
	.name_service = "e-mail",

	.ID = NP_INNER_RULE_POP3,
	.priority = NP_RULE_PRI_MAX,
	.base_rule = 1,
	.ref_type = 0,

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
		.ctm_num = 1, /* GET,POST,CONNECT,HEAD */
		.ctm_relation = NP_CTM_OR,
		.ctm = {
			{
				.type_match = MHTP_OFFSET,
				.offset = 0,
				.patt_len = 3,
				.patt = "+OK",
			},
		},
	},

	/* callback's. */
};
