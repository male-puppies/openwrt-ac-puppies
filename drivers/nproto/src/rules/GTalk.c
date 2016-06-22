
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"

/*
# GTalk, a Jabber (XMPP) client
# Pattern attributes: good veryfast fast subset
# Protocol groups: chat ietf_proposed_standard
# Wiki: http://www.protocolinfo.org/wiki/Jabber
# Copyright (C) 2009 Matthew Strait; See ../LICENSE

# See ../protocols/jabber.pat for more details

gtalk
^<stream:stream to="gmail\.com"
*/
np_rule_t inner_GTalk = {
	.name_rule = "GTalk",
	.name_app = "GTalk",
	.name_service = "Google Talk",

	.ID = NP_INNER_RULE_GTalk,
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
			.type = NP_LNM_NONE,
		},
		.ctm_num = 1, /*  */
		.ctm_relation = NP_CTM_AND,
		.ctm = {
			{
				.type_match = MHTP_REGEXP,
				.patt = "/^<stream:stream to=[\"']gmail\\.com[\"']/",
			},
		},
	},

	/* callback's. */
};
