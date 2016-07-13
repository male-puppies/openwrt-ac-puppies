
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
np_rule_t inner_http_weibo = {
	.name_rule = "http-weibo",
	.name_app = "weibo",
	.name_service = "Media",

	.ID = NP_INNER_RULE_HTTP_WEIBO,
	.priority = NP_RULE_PRI_MAX,
	
	.rule_type = TP_RULE_FIN,
	/* just match the http matched packet's */
	.refs_type = NP_REF_PACKET,
	.ID_REFs = {NP_INNER_RULE_HTTP_REQ, },

	/* use http match only. */
	.enable_http = 1,

	.http = {
		.htp_relation = NP_CTM_OR,
		.htpm = {
			{
				.hdr = NP_HTTP_Host,
				.match = {
					.type = MHTP_SEARCH,
					.patt = ".weibo.com",
				},
			},{
				.hdr = NP_HTTP_Host,
				.match = {
					.type = MHTP_SEARCH,
					.patt = ".weibo.cn",
				},
			},{
				.hdr = NP_HTTP_Host,
				.match = {
					.type = MHTP_SEARCH,
					.patt = ".sinaimg.cn",
				},
			},{
				.hdr = NP_HTTP_Host,
				.match = {
					.type = MHTP_SEARCH,
					.patt = ".sinajs.cn",
				},
			},{
				.hdr = NP_HTTP_Host,
				.match = {
					.type = MHTP_SEARCH,
					.patt = ".sina.cn",
				},
			},{
				.hdr = NP_HTTP_Host,
				.match = {
					.type = MHTP_SEARCH,
					.patt = ".sina.com.cn",
				},
			},
		},
	},

	/* callback's. */
};
