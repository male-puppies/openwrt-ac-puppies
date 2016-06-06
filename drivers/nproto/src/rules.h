#pragma once

#include <linux/types.h>
#include <linux/list.h>
#include <linux/skbuff.h>

#include <linux/nos_track.h>

#include <ntrack_flow.h>

#include "mwm.h"

#define MAX_REF_IDs 8
#define MAX_L4_ADDRS 8
#define MAX_L4_PORTS 31

#define MAX_L7_LEN_LIST 15
#define MAX_L7_LEN_RANGE 16
#define MAX_CT_MATCH_NUM 16

#define NP_PATT_LEN_MAX  64
#define NP_RULE_PRI_MIN 0
#define NP_RULE_PRI_MAX 65535

typedef struct {
	uint32_t addrs[MAX_L4_ADDRS];
	uint16_t ports[MAX_L4_PORTS];
	uint16_t proto;
} l4_match_t;

enum __em_match_t {
	MHTP_OFFSET = 0,
	MHTP_HTTP_CTX,
	MHTP_REGEXP,
	MHTP_SEARCH,
};

enum __em_lnm_t {
	NP_LNM_NONE = 0,
	NP_LNM_LIST,
	NP_LNM_MATCH,
	NP_LNM_RANGE,
};

typedef struct {
	uint8_t type;  /* NONE, LIST, MATCH, RANGE, ... */
	int16_t offset; /* the curror of len info. */
	int16_t fixed; /* fixed +-n. */
	uint8_t width; /* byte, short, int -> 1,2,4 */
	uint16_t list[MAX_L7_LEN_LIST];
	uint16_t range[MAX_L7_LEN_RANGE][2];
} len_match_t;

/* rule matched callback. */
typedef int (*nproto_cb_t)(void *nt, void *pkt, void *rule);
typedef struct {
	/* 0: offset match, 1: http body, 2: regexp, 3: search */
	uint8_t type;

	/* only match the len == spec_len. */
	uint16_t spec_len;

	/* 
	** takeoff the wrapper proto.
	** 
	** 0,0: match the +OFFSET, 
	** n,m: search +/- n->m 
	** 
	** this find the realy proto payload, 
			such as http->hdr->body (FLV-...).
	*/
	int16_t begin, end;
	uint16_t search_len;
	uint8_t search[NP_PATT_LEN_MAX];

	/*
	** ++++++offset[x]++***patt***+++++++++++
	** search range: offset -> offset + deep 
	*/
	int16_t offset;
	uint16_t deep;
	uint16_t patt_len;
	uint8_t patt[NP_PATT_LEN_MAX];

	/* regexp */

	/* bmh */
} content_match_t;

typedef struct {
	/* C->S, S->C, any */
	uint8_t dir; 

	/* length info */
	len_match_t lnm;

	/* content info */ 
	/* or|and */
	uint8_t ctm_num:6, ctm_relation:2;
	content_match_t ctm[MAX_CT_MATCH_NUM];
} l7_match_t;

typedef struct {
	/* http hdr: URL, Context-type, Host, ... */
	uint32_t hdr_URL:1, hdr_Host:1, hdr_ContextType:1;

} http_match_t;

typedef struct nproto_rule np_rule_t;
/* 
** rule set:
** 	UDP
**	TCP ->
		HTTP
		Not-HTTP
	Others
	REF_Rules
*/
typedef struct {
	char name[64];
	mwm_t *pmwm; /* rules with 4 char search patterns. */

	uint16_t num_rules;
	uint16_t capacity; /* the capacity of this set */
	np_rule_t **rules; /* the dmalloc array pointer */
} np_rule_set_t;

struct nproto_rule {
	struct list_head list;
	/* rule name, app name(xunlei, web-chrome), service: http, mail, game. */
	char *name_rule, *name_app, *name_service;

	/* match pri, but as mwm search, this not used... */
	uint16_t priority;

	uint16_t ID;
	/* this rule ref to other/base rules. */
	uint16_t ID_REFs[MAX_REF_IDs];
	/* 
	* base: start match as unknown, or ref to someone.
	* ref: 0: current-package/1: cross-package-in-session. 
	* 		bit-map: 0/1/2/3.
	*/
	uint8_t base_rule: 4, ref_type: 4;

	/* enable the l4/l7 match process */
	uint8_t enable_l4:1, enable_l7:1, enable_http:1;

	/* l4 header match */
	l4_match_t l4;

	/* payload data match */
	l7_match_t l7;

	/* match http proto's */
	http_match_t http;

	/* ref sets */
	np_rule_set_t ref_set;

	/* rule match callback... */
	nproto_cb_t proto_cb;
};

enum __em_inner_sets {
	NP_SET_BASE_UDP = 0,
	NP_SET_BASE_TCP,
	NP_SET_BASE_OTHER,
	NP_SET_BASE_MAX,
};

static inline uint8_t np_proto_to_set(uint8_t proto)
{
	switch(proto){
		case IPPROTO_TCP:
		return NP_SET_BASE_TCP;
		case IPPROTO_UDP:
		return NP_SET_BASE_UDP;
		default:
		return NP_SET_BASE_OTHER;
	}
}

enum __em_inner_proto {
	NP_INNER_RULE_HTTP_REQ = 0,
	NP_INNER_RULE_HTTP_REP,
	NP_INNER_RULE_SMTP,
	NP_INNER_RULE_POP3,
	NP_INNER_RULE_SSH,
	NP_INNER_RULE_MAX,
};

enum __em_ctm_relation {
	NP_CTM_OR = 0,
	NP_CTM_AND,
};