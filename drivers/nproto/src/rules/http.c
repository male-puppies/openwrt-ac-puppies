
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"

static mwm_t *mwmParser = NULL;

/* header need parsered. */
const char *http_headers[] = {
	[NP_HTTP_END] = "\r\n\r\n",
	[NP_HTTP_URL] = NULL,
	[NP_HTTP_Host] = "Host:",
	[NP_HTTP_Referer] =  "Referer:",
	[NP_HTTP_Content] =  "Content:",
	[NP_HTTP_Accept] =  "Accept:",
	[NP_HTTP_User_Agent] =  "User-Agent:",
	[NP_HTTP_Http_Encoding] =  "Http-Encoding:",
	[NP_HTTP_Transfer_Encoding] =  "Transfer-Encoding:",
	[NP_HTTP_Content_Len] =  "Content-Len:",
	[NP_HTTP_Cookie] =  "Cookie:",
	[NP_HTTP_X_Session_Type] =  "X-Session-Type:",
	[NP_HTTP_Method] =  "Method:",
	[NP_HTTP_Response] =  "Response:",
	[NP_HTTP_Server] =  "Server:",
	[NP_HTTP_End_Header] =  "End-Header:",
	[NP_HTTP_MAX] = NULL,
};

static int http_init(void)
{
	int i, n;

	/* init proto vars */
	if(!mwmParser) {
		mwmParser = mwmNew();
		if(!mwmParser) {
			np_error("mwm malloc failed.\n");
			return -ENOMEM;
		}
	}
	/* mwmAddPatternEx,mwmPrepPatterns */
	for(i=0; i<NP_HTTP_MAX; i++) {
		const char *x = http_headers[i];
		if(!(x && strlen(x) >= 4)) {
			continue;
		}
		n = mwmAddPatternEx(mwmParser, (unsigned char*)x, strlen(x), 0, 0, 0);
		if(n<=0) {
			np_error("add patt: %s failed - %d.\n", x, n);
			continue;
		}
	}
	n = mwmPrepPatterns(mwmParser);
	if(n<=0) {
		np_error("compile patts failed: %d\n", n);
		return -EINVAL;
	}

	return 0;
}

static void http_clean(void)
{
	if(mwmParser) {
		mwmFree(mwmParser);
		mwmParser = NULL;
	}
}

static int mwm_http_match(void *par, void *in, void *out)
{
	return 1;
}

static int on_http_req(nt_packet_t *npt, void *rule)
{
	nt_pkt_nproto_t *pkt_proto = nt_pkt_nproto(npt);

	pkt_proto->du_type = NP_DUT_HTTP_REQ;
	/* do line parse. store the result into flow private union -> nproto_t. */

	np_print(FMT_FLOW_STR"\n", FMT_FLOW(npt->fi));

	if(mwmParser) {
		mwmSearch(mwmParser, npt->l7_ptr, npt->l7_len, NULL, NULL, mwm_http_match);
	}
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
				.type_match = MHTP_OFFSET,
				.offset = 0,
				.patt_len = 4,
				.patt = "GET ",
			},{
				.type_match = MHTP_OFFSET,
				.offset = 0,
				.patt_len = 5,
				.patt = "POST ",
			},{
				.type_match = MHTP_OFFSET,
				.offset = 0,
				.patt_len = 8,
				.patt = "CONNECT ",
			},{
				.type_match = MHTP_OFFSET,
				.offset = 0,
				.patt_len = 5,
				.patt = "HEAD ",
			},
		},
	},

	/* callback's. */
	.proto_init = http_init,
	.proto_clean = http_clean,
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
				.type_match = MHTP_OFFSET,
				.offset = 0,
				.patt_len = 5,
				.patt = "HTTP ",
			},
		},
	},
};
