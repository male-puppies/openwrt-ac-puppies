
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"

/*
#Request-Line  =  Method SP Request-URI SP SIP-Version CRLF
sip
^(invite|register|cancel|message|subscribe|notify) sip[\x09-\x0d -~]*sip/[0-2]\.[0-9]
*/
np_rule_t inner_SIP = {
	.name_rule = "SIP",
	.name_app = "SIP",
	.name_service = "Session Initiation Protocol",

	.ID = NP_INNER_RULE_SIP,
	.priority = NP_RULE_PRI_MAX,

	.rule_type = TP_RULE_BASE | TP_RULE_FIN,
	.refs_type = NP_REF_NONE,

	.enable_http = 0,

	/* layer 4 match. */
	.enable_l4 = 1,
	.l4 = {
		.proto = IPPROTO_UDP,
	},

	/* layer 7 context. */
	.enable_l7 = 1,
	.l7 = {
		.dir = NP_FLOW_DIR_C2S,
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
					.patt = "/^(invite|register|cancel|message|subscribe|notify) sip[\\x09-\\x0d -~]*sip/[0-2]\\.[0-9]/i",
				},
			},
		},
	},

	/* callback's. */
};
