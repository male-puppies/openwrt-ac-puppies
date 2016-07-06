
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"

/*
# Server Hello with certificate | Client Hello
# This allows SSL 3.X, which includes TLS 1.0, known internally as SSL 3.1
Secure Sockets Layer
    TLSv1 Record Layer: Handshake Protocol: Client Hello
        Content Type: Handshake (22)
        Version: TLS 1.0 (0x0301)
        Length: 65
        Handshake Protocol: Client Hello

^(\x16\x03\01,length,xxx)
*/
np_rule_t inner_ssl = {
	.name_rule = "ssl",
	.name_app = "ssl",
	.name_service = "Secure Socket Layer",

	.ID = NP_INNER_RULE_SSL,
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
			.offset = 3,
			.fixed = 5,
			.width = 2,
		},
		.ctm_num = 1, /*  */
		.ctm_relation = NP_CTM_AND,
		.ctm = {
			{
				.match = {
					.type = MHTP_REGEXP,
					.offset = 0,
					.deep = 96,
					.patt = "/^(\\x16\\x03\\0x01|\\x17\\x03\\x01)/m",
				},
			},
		},
	},

	/* callback's. */
};
