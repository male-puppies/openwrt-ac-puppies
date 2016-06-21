
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"


/*
UA:
SVN/1.9.3 (x86_64-unknown-linux-gnu) serf/1.3.8
*/
np_rule_t inner_http_svn = {
	.name_rule = "http-svn",
	.name_app = "svn",
	.name_service = "svn",

	.ID = NP_INNER_RULE_HTTP_SVN,
	.priority = NP_RULE_PRI_MAX,
	
	.rule_type = TP_RULE_FIN,
	/* just match the http matched packet's */
	.refs_type = NP_REF_PACKET,

	/* use http match only. */
	.enable_l4 = 0,
	.enable_l7 = 0,
	.enable_http = 1,

	.http = {
		{
			.OR = 1,
			.type = HTP_MTP_HDR,
			.hdr = NP_HTTP_User_Agent,
			.patt = "/^SVN\\/[0-9]\\.[0-9]\\.[0-9] /i",
		},
	},

	/* callback's. */
};
