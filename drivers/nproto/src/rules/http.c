
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"

static mwm_t *mwmParser = NULL;
static bmh_t *bmhLine = NULL;

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
	[NP_HTTP_Content_Type] = "Content-Type:",
	[NP_HTTP_MAX] = NULL,
};

static int http_init(void)
{
	int i, n, create = 0;

	/* init bmh line end finder. */
	if(!bmhLine) {
		bmhLine = kmalloc(sizeof(bmh_t), GFP_KERNEL);
		if(!bmhLine) {
			np_error("bmh malloc failed.\n");
			return -ENOMEM;
		}
		BMHInit(bmhLine, "\r\n", 2);
	}

	/* init proto vars */
	if(!mwmParser) {
		mwmParser = mwmNew();
		if(!mwmParser) {
			np_error("mwm malloc failed.\n");
			return -ENOMEM;
		}
		create = 1;
	}
	/* mwmAddPatternUnique, mwmPrepPatterns */
	for(i=0; i<NP_HTTP_MAX; i++) {
		const char *x = http_headers[i];
		if(!(x && strlen(x) >= 4)) {
			continue;
		}
		n = mwmAddPatternUnique(mwmParser, (unsigned char*)x, strlen(x), 0, 0, &http_headers[i]);
		if(n<0) {
			np_error("add patt: %s failed - %d.\n", x, n);
		}
	}
	n = mwmPrepPatterns(mwmParser);
	if(n<=0) {
		np_error("compile patts failed: %d\n", n);
		return -EINVAL;
	}

	/* debug dump */
	if(create) {
		mwmGroupDetails(mwmParser);
	}
	return 0;
}

static void http_clean(void)
{
	if(mwmParser) {
		mwmFree(mwmParser);
		mwmParser = NULL;
	}
	if(bmhLine) {
		kfree(bmhLine);
		bmhLine = NULL;
	}
}

static int mwm_http_match(void *par, void *in, void *out)
{
	nt_packet_t *npt = in;
	nt_pkt_nproto_t *nproto = nt_pkt_nproto(npt);
	uint8_t *end_ptr;
	int16_t start, end = 0, lasted;
	uint8_t idx = ((void*)par - (void*)&http_headers[0])/sizeof(void*);

	if(idx == NP_HTTP_END) {
		int16_t nlen;

		/* \r\n\r\n */
		end = (uint8_t*)out - npt->l7_ptr;
		/* debug */
		np_debug("found http header end.\n");
		np_dump(out, 16, "dump: ");

		/* save end offset. */
		nproto->du.http.headers_range[idx][0] = end;
		nproto->du.http.headers_range[idx][1] = end;

		/* finished parse & exit. */
		nlen = npt->l7_len - end;
		if(nlen < 0) {
			np_error("bad http packet length !!! hdr-end:%d, len:%d\n", end, npt->l7_len);
			return -1;
		}
		/* http context match only. */
		npt->l7_len = nlen;
		npt->l7_ptr += end;
		return -1;
	}

	start = (uint8_t*)out - npt->l7_ptr;
	lasted = npt->l7_len - start;
	end_ptr = BMHChr(bmhLine, out+1, lasted);
	if(!end_ptr) {
		np_debug("[%s] line end not found.\n", http_headers[idx]);
		np_dump(out, 16, "dump: ");
		return 1;
	}
	end = end_ptr - npt->l7_ptr;

	/* debug */
	#if 0//__DEBUG
	np_print("%4d:[%4d-%4d]: %s\n", idx, start, end, http_headers[idx]);
	np_dump((uint8_t*)out + 1, end-start, "dump:");
	#endif

	nproto->du.http.headers_range[idx][0] = start;
	nproto->du.http.headers_range[idx][1] = end;
	return 1;
}

/* do line parse. store the result into flow private union -> nproto_t. */
static int on_http_hdr(nt_packet_t *npt, void *prule)
{
	int i;
	int16_t start = 0, end = 0;
	np_rule_t *rule = prule;
	nt_pkt_nproto_t *nproto = nt_pkt_nproto(npt);

	/* find the blank space. */
	for(i=0; i<npt->l7_len; i++) {
		uint8_t c = npt->l7_ptr[i];
		if(!start && c == 0x20) {
			start = i;
			continue;
		}
		if(!end && c == 0x20) {
			end = i;
			break;
		}
		if(c == '\r' || c == '\n')
			break;
	}
	/* save url offset. */
	if(start && end) {
		nproto->du.http.headers_range[NP_HTTP_URL][0] = start;
		nproto->du.http.headers_range[NP_HTTP_URL][1] = end;
		np_dump(npt->l7_ptr + start, end - start, "[%s]: URL:", rule->name_rule);
	}
	/* parse other headers. */
	if(mwmParser) {
		mwmSearch(mwmParser, npt->l7_ptr, npt->l7_len, npt, NULL, mwm_http_match);
	}
	nproto->du_type = NP_DUT_HTTP_REQ;
	return 0;
}

np_rule_t inner_http_req = {
	.name_rule = "http_req",
	.name_app = "http",
	.name_service = "web",

	.ID = NP_INNER_RULE_HTTP_REQ,
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
		.dir = NP_FLOW_DIR_C2S,
		.lnm = {
			.type = NP_LNM_NONE,
		},
		.ctm_num = 1, /* GET,POST,CONNECT,HEAD,OPTIONS */
		.ctm_relation = NP_CTM_AND,
		.ctm = {
			{
				.match = {
					.type = MHTP_REGEXP,
					.offset = 0,
					.patt = "/^GET|^POST|^CONNECT|^HEAD|^OPTIONS \\//",
				},
			},
		},
	},

	/* callback's. */
	.proto_init = http_init,
	.proto_clean = http_clean,
	.proto_cb = on_http_hdr,
};

np_rule_t inner_http_rep = {
	.name_rule = "http_rep",
	.name_app = "http",
	.name_service = "web",

	.ID = NP_INNER_RULE_HTTP_REP,
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
		.ctm_num = 1, /* HTTP/1.0|2.0 */
		.ctm_relation = NP_CTM_AND,
		.ctm = {
			{
				.match = {
					.type = MHTP_REGEXP,
					.offset = 0,
					.patt = "/^HTTP\\/[12].0 /",
				},
			},
		},
	},

	/* proto callback's */
	.proto_init = http_init,
	.proto_clean = http_clean,
	.proto_cb = on_http_hdr,
};
