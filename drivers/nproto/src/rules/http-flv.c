
#include <linux/tcp.h>

#include <nproto/http.h>
#include <ntrack_comm.h>
#include <ntrack_flow.h>
#include <ntrack_packet.h>

#include "../rules.h"
#include "../mwm.h"
#include "../bmh.h"


/*
# Flash - Macromedia Flash.  

# Macromedia spec:
# http://download.macromedia.com/pub/flash/flash_file_format_specification.pdf
# See also:
# http://www.digitalpreservation.gov/formats/fdd/fdd000130.shtml
# http://osflash.org/flv

flash
# FWS = uncompressed, CWS = compressed, next byte is version number
# FLV = video 
[FC]WS[\x01-\x09]|FLV\x01\x05\x09
*/
np_rule_t inner_http_flv = {
	.name_rule = "http-flv",
	.name_app = "flv",
	.name_service = "flv",

	.ID = NP_INNER_RULE_HTTP_FLV,
	.priority = NP_RULE_PRI_MAX,
	
	.rule_type = TP_RULE_FIN,
	/* match the http current packet's & flow. */
	.refs_type = NP_REF_PACKET | NP_REF_FLOW,

	/* use http match only. */
	.enable_l4 = 0,
	.enable_l7 = 0,
	.enable_http = 1,

	.http = {
		.relation = NP_CTM_OR,
		.htpm = {
			{
				.hdr = 0, /* context match. */
				.match = {
					.type = MHTP_REGEXP,
					.patt = "/^[FC]WS[\\x01-\\x09]|FLV\\x01\\x05\\x09/",
				},
			},
		},
	},

	/* callback's. */
};
