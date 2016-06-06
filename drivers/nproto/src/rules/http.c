
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"

static int on_http_req(void *pnt, void *pskb, void *rule)
{
	struct nos_track *nt = pnt;
	struct sk_buff *skb = pskb;
	nt_pkt_nproto_t *pkt_proto = nt_pkt_nproto(skb);

	pkt_proto->du_type = NP_DUT_HTTP_REQ;
	/* do line parse. store the result into flow private union -> nproto_t. */

	np_print(FMT_FLOW_STR"\n", FMT_FLOW(nt_flow(nt)));
	return 0;
}

np_rule_t inner_http_req = {
	.name_rule = "http_req",
	.name_app = "http",
	.name_service = "web",

	.ID = NP_INNER_RULE_HTTP_REQ,
	.priority = NP_RULE_PRI_MAX,
	.base_rule = 1,
	.ref_type = 0,

	.enable_l4 = 1,
	.enable_l7 = 1,
	.enable_http = 0,

	/* layer 4 match. */
	.l4 = {
		.proto = IPPROTO_TCP,
	},

	/* layer 7 context. */
	.l7 = {
		.dir = NP_FLOW_DIR_C2S,
		.lnm = {
			.type = NP_LNM_NONE,
		},
		.ctm_num = 4, /* GET,POST,CONNECT,HEAD */
		.ctm_relation = NP_CTM_OR,
		.ctm = {
			{
				.type = MHTP_OFFSET,
				.offset = 0,
				.patt_len = 4,
				.patt = "GET ",
			},{
				.type = MHTP_OFFSET,
				.offset = 0,
				.patt_len = 5,
				.patt = "POST ",
			},{
				.type = MHTP_OFFSET,
				.offset = 0,
				.patt_len = 8,
				.patt = "CONNECT ",
			},{
				.type = MHTP_OFFSET,
				.offset = 0,
				.patt_len = 5,
				.patt = "HEAD ",
			},
		},
	},

	.proto_cb = on_http_req,
};

np_rule_t inner_http_rep = {
	.name_rule = "http_rep",
	.name_app = "http",
	.name_service = "web",

	.ID = NP_INNER_RULE_HTTP_REP,
	.priority = NP_RULE_PRI_MAX,
	.base_rule = 1,
	.ref_type = 0,

	.enable_l4 = 1,
	.enable_l7 = 1,
	.enable_http = 0,

	/* layer 4 match. */
	.l4 = {
		.proto = IPPROTO_TCP,
	},

	/* layer 7 context. */
	.l7 = {
		.dir = NP_FLOW_DIR_S2C,
		.lnm = {
			.type = NP_LNM_NONE,
		},
		.ctm_num = 1, /* GET,POST,CONNECT,HEAD */
		.ctm_relation = NP_CTM_OR,
		.ctm = {
			{
				.type = MHTP_OFFSET,
				.offset = 0,
				.patt_len = 5,
				.patt = "HTTP ",
			},
		},
	},
};
