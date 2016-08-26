// #define __DEBUG

#include <linux/udp.h>
#include <linux/tcp.h>
#include <linux/crc32.h>
#include <linux/nos_track.h>

#include <nproto/http.h>

#include "mwm.h"
#include "bmh.h"
#include "rules.h"
#include "pcre.h"
#include "nproto_private.h"

#define RULE_DBG_TRACE

int rule_trace_id = NP_INNER_RULE_HTTP_WEIBO;
module_param(rule_trace_id, int, 0444);
MODULE_PARM_DESC(rule_trace_id, "debug rule trace id.");
/* ... */
#ifdef RULE_DBG_TRACE
#define RULE_DBG(rule, npt, fmt...)  do { \
		if(rule->ID == rule_trace_id){ \
			if(npt){ \
				np_print("%d: "FMT_PKT_STR"\n\t", __LINE__, FMT_PKT((nt_packet_t*)npt)); \
			} \
			np_print(fmt); \
		} \
	}while(0)
#else
#define RULE_DBG(rule, npt, fmt...) do{}while(0)
#endif

#define NP_MWM_STR "nproto"
#define np_assert(x) BUG_ON(!(x))

/* inner data struct's */
typedef struct {
	int count;
	np_rule_t *array[NP_RULES_COUNT_MAX];
	uint16_t id_to_index[NP_RULES_COUNT_MAX];
} all_rules_t;
static all_rules_t RULES_ALL;
static np_rule_t *get_rule_by_id(uint16_t id)
{
	uint16_t idx;

	np_assert(id >= 0);
	np_assert(id < NP_RULES_COUNT_MAX);

	idx = RULES_ALL.id_to_index[id];
	return RULES_ALL.array[idx];
}

static np_rule_t *inner_rules[NP_INNER_RULE_MAX];
static np_rule_set_t RS_BASE[NP_FLOW_DIR_MAX][NP_SET_BASE_MAX];

static int ctm_init(np_rule_t *rule, match_t *ctm)
{
	if(!ctm->length) {
		ctm->length = strlen(ctm->patt);
	}
	if(ctm->length <= 0) {
		return EINVAL;
	}
	switch(ctm->type) {
		case MHTP_REGEXP: {
			if(!ctm->rex) {
				pcre_t *rex = pcre_create(ctm->patt, ctm->length);
				if(!rex) {
					np_error("[%s] rex patt create failed.\n", rule->name_rule);
					return -ENOMEM;
				}
				ctm->rex = rex;
			}
		} break;
		case MHTP_SEARCH: {
			if(!ctm->bmh) {
				bmh_t *bmh = kmalloc(sizeof(bmh_t), GFP_KERNEL);
				if(!bmh) {
					np_error("[%s] bmh patt alloc failed.\n", rule->name_rule);
					return -ENOMEM;
				}
				BMHInit(bmh, ctm->patt, ctm->length);
				ctm->bmh = bmh;
			}
		} break;
		default: {np_error("error ctm type.\n");} break;
	}

	return 0;
}

static void ctm_destroy(np_rule_t *rule, match_t *ctm)
{
	if(ctm->rex) {
		np_debug("[%s] destroy rex wrap.\n", rule->name_rule);
		pcre_destroy(ctm->rex);
		ctm->rex = NULL;
	}

	if(ctm->bmh) {
		np_debug("[%s] destroy bmh http.\n", rule->name_rule);
		kfree(ctm->bmh);
		ctm->bmh = NULL;
	}
}

static int rule_compile(np_rule_t *rule)
{
	int i;

	/* init rule callback ok. */
	if(rule->proto_init && rule->proto_init()) {
		np_error("init proto callback failed.\n");
		return -EINVAL;
	}

	/* init bmh/regexp struct. */
	if(rule->enable_l7) {
		for(i=0; i<rule->l7.ctm_num; i++) {
			content_match_t *ctm = &rule->l7.ctm[i];
			ctm_init(rule, &ctm->wrap);
			ctm_init(rule, &ctm->match);
		}
	}

	/* init http match struct */
	if(RULE_REF_HTTP(rule)) {
		for(i=0; i<ARRAY_SIZE(rule->http.htpm); i++) {
			httpm_t *htpm = &rule->http.htpm[i];
			if(ctm_init(rule, &htpm->match) > 0) {
				break;
			}
		}
	}
	rule->crc = crc32(0, rule->name_rule, strlen(rule->name_rule));
	return 0;
}

static void rule_release(np_rule_t *rule)
{
	int i;

	/* release the dmalloc mem. */
	if(rule->proto_clean) {
		rule->proto_clean();
	}
	if(rule->enable_l7) {
		for(i=0; i<rule->l7.ctm_num; i++) {
			content_match_t *ctm = &rule->l7.ctm[i];
			ctm_destroy(rule, &ctm->wrap);
			ctm_destroy(rule, &ctm->match);
		}
	}
	if(RULE_REF_HTTP(rule)) {
		for(i=0; i<ARRAY_SIZE(rule->http.htpm); i++) {
			httpm_t *htpm = &rule->http.htpm[i];
			ctm_destroy(rule, &htpm->match);
		}
	}
}

static void set_dump(np_rule_set_t *, int stage);
static void rule_dump(np_rule_t *rule)
{
	int i;

	np_print("rule[%s] Proto[%s] Service[%s]:\n",
		rule->name_rule, rule->name_app, rule->name_service);
	np_print("\tID: [%d]\n", rule->ID);
	for(i=0; i<MAX_REF_IDs; i++){
		if(rule->ID_REFs[i]) {
			if(i==0) {
				np_print("\tID_REFs:");
			}
			np_print(" %d", rule->ID_REFs[i]);
		} else {
			if(i)np_print("\n");
			break;
		}
	}
	if(rule->ref_set) {
		np_print("-------------- ref-set --------------\n");
		set_dump(rule->ref_set, 1);
	}
}

int set_add_rule_normal_sorted(np_rule_set_t *set, np_rule_t *rule)
{
	if(rule->priority == NP_RULE_PRI_MIN) {
		set->rules[set->num_rules] = rule;
	} else if(rule->priority == NP_RULE_PRI_MAX) {
		if(set->num_rules > 0)
			memmove(&set->rules[1], set->rules, sizeof(set->rules[0]) * set->num_rules);
		set->rules[0] = rule;
	} else {
		/* find the insert position */
		int lo = 0;
		int hi = set->num_rules - 1;
		int mid, count;
		while(lo <= hi) {
			mid = (lo + hi) / 2;
			if(set->rules[mid]->priority == rule->priority) {
				hi = mid;
				break;
			} else {
				if(set->rules[mid]->priority < rule->priority) {
					hi = mid - 1; /* < */
				} else {
					lo = mid + 1; /* > */
				}
			}
		}
		/* move [hi],([hi+1]),[hi+2]... */
		count = set->num_rules - (hi + 1);
		if(count > 0) {
			memmove(&set->rules[hi + 2], &set->rules[hi + 1], sizeof(set->rules[0]) * count);
		}
		set->rules[hi + 1] = rule;
	}
	set->num_rules ++;

	np_info("[%s:%d]\n", rule->name_rule, rule->ID);
	return set->num_rules;
}

#define NP_SET_GROW_COUNT 64
static int set_add_rule_normal(np_rule_set_t *set, np_rule_t *rule)
{
	if(set->num_rules >= set->capacity) {
		uint32_t nsize = (set->capacity + NP_SET_GROW_COUNT) * sizeof(set->rules[0]);
		np_rule_t **po = set->rules;
		np_rule_t **pn = (np_rule_t **)vmalloc(nsize);
		if (!pn) {
			np_error("re-alloc mem failed: %d\n", nsize);
			return -ENOMEM;
		}
		memcpy(pn, po, set->capacity * sizeof(set->rules[0]));
		set->rules = pn;
		set->capacity += NP_SET_GROW_COUNT;
		vfree(po);
	}

	return set_add_rule_normal_sorted(set, rule);
}

static int set_add_rule_mwm(np_rule_set_t *set, mwm_t **pmwm, np_rule_t *rule, match_t *ctm)
{
	int n;
	mwm_t *mwm = *pmwm;

	/* init mwm st.. */
	if(!mwm) {
		mwm = mwmNew();
		if(!mwm) {
			np_error("create mwm failed.\n");
			return set_add_rule_normal(set, rule);
		}
		*pmwm = mwm;
	}
	/* add patters & rule to mwm. */
	n = mwmAddPatternEx(mwm, ctm->patt, ctm->length, ctm->offset, ctm->deep, rule);
	if(n<0) {
		np_error("mwm: [%s:%d] add patt [%s] err\n", rule->name_rule, rule->ID, ctm->patt);
		return set_add_rule_normal(set, rule);
	} else {
		np_info("mwm: [%s:%d] add [%s]\n", rule->name_rule, rule->ID, ctm->patt);
	}
	return 0;
}

static int set_add_rule(np_rule_set_t *set, np_rule_t *rule)
{
	int i, in_mwm = -1;

	np_assert(set);
	np_assert(rule);

	/* check l7 search && patt len > 4 */
	if(!rule->enable_l7 && !RULE_REF_HTTP(rule)) {
		return set_add_rule_normal(set, rule);
	}
	/* http search && length >= 4 */
	if(RULE_REF_HTTP(rule)) {
		http_match_t *htp = &rule->http;
		if(htp->htp_relation != NP_CTM_OR) {
			/* only mwm or rules. */
			return set_add_rule_normal(set, rule);
		}
		for(i=0; i<ARRAY_SIZE(htp->htpm); i++) {
			httpm_t *htpm = &htp->htpm[i];
			match_t *ctm = &htpm->match;
			if(htpm->hdr == NP_HTTP_END) {
				/* http only add content search to mwm. */
				if(ctm->type == MHTP_SEARCH && ctm->length >= 4) {
					in_mwm = set_add_rule_mwm(set, &set->pmwm, rule, ctm);
					if(in_mwm) {
						return 0;
					}
				}
			} else if(htpm->hdr == NP_HTTP_Host) {
				/* use mwm to search host, as too many web services. */
				if(ctm->type == MHTP_SEARCH && ctm->length >=4 ) {
					in_mwm = set_add_rule_mwm(set, &set->pmwm_host, rule, ctm);
					if(in_mwm) {
						return 0;
					}
				}
			}
		}
	} else {
		l7_match_t *l7 = &rule->l7;
		if(l7->ctm_relation != NP_CTM_OR) {
			return set_add_rule_normal(set, rule);
		}
		for(i=0; i<l7->ctm_num; i++) {
			match_t *ctm = &l7->ctm[i].match;
			if(ctm->type == MHTP_SEARCH && ctm->length >= 4) {
				/* ! search & patt length >= 4 */
				in_mwm = set_add_rule_mwm(set, &set->pmwm, rule, ctm);
				if(in_mwm) {
					return 0;
				}
			}
		}
	}
	if(in_mwm >= 0) {
		/* already add to mwm OR normal. */
		return 0;
	}
	/* default add to normal set */
	return set_add_rule_normal(set, rule);
}

int np_rule_register(np_rule_t *rule)
{
	int dir = 0, proto = NP_SET_BASE_OTHER;
	/* compile && check valid */
	if(rule_compile(rule)){
		np_error("compile %d: %s\n", rule->ID, rule->name_rule);
		return -EINVAL;
	}

	/* add to global list. */
	RULES_ALL.array[RULES_ALL.count++] = rule;
	if(RULES_ALL.count>=ARRAY_SIZE(RULES_ALL.array)) {
		np_error("GLOBAL rule array limited.\n");
		return -ENOMEM;
	}

	if(!RULE_IS_BASE(rule)) {
		/* ref rule not add to base sets. */
		return 0;
	}

	/* base rule, to inner set's */
	if (rule->enable_l4) {
		proto = np_proto_to_set(rule->l4.proto);
	}

	if(rule->enable_l7) {
		dir = rule->l7.dir;
	}

	/* invalid rule pars. */
	np_assert(dir < NP_FLOW_DIR_MAX);
	np_assert(proto < NP_SET_BASE_MAX);

	np_info("base rule: %s, id: %d\n", rule->name_rule, rule->ID);
	return set_add_rule(&RS_BASE[dir][proto], rule);
}

void set_cleanup(np_rule_set_t *set)
{
	if(set->pmwm) {
		mwmFree(set->pmwm);
	}
	if(set->pmwm_host) {
		mwmFree(set->pmwm_host);
	}
}

static np_rule_set_t *set_alloc(char *name)
{
	np_rule_set_t *set = kmalloc(sizeof(np_rule_set_t), GFP_KERNEL);
	if(!set) {
		np_error("alloc set[%s] failed.\n", name);
		return NULL;
	}
	memset(set, 0, sizeof(np_rule_set_t));

	return set;
}

static int mwm_compile(mwm_t *mwm)
{
	int ret = mwmPrepPatterns(mwm);
	if(ret <= 0) {
		np_error("init mwm:%p - failed.\n", mwm);
		mwmFree(mwm);
		return -EINVAL;
	}
	/* debug dump */
	// mwmGroupDetails(set->pmwm);

	return 0;
}

int set_compile(np_rule_set_t *set, char *name)
{
	int ret;

	snprintf(set->name, sizeof(set->name), "%s", name);
	if(set->pmwm) {
		ret = mwm_compile(set->pmwm);
		if(ret) {
			set->pmwm = NULL;
		}
	}
	if(set->pmwm_host) {
		ret = mwm_compile(set->pmwm_host);
		if(ret) {
			set->pmwm_host = NULL;
		}
	}
	return 0;
}

static void set_dump(np_rule_set_t *set, int stage)
{
	int i;

	if(set->num_rules == 0 && set->pmwm == NULL) {
		/* empty */
		return;
	}

	np_print("----[%d:%s:%d]----\n", stage, set->name, set->num_rules);
	if(set->pmwm) {
		np_print("mwm search:\n");
		mwmGroupDetails(set->pmwm);
	}
	if(set->pmwm_host) {
		np_print("mwm host search:\n");
		mwmGroupDetails(set->pmwm_host);
	}
	for(i=0; i<set->num_rules; i++) {
		np_rule_t *rule = set->rules[i];
		rule_dump(rule);
	}
	return;
}

int nproto_rules_dump_name(char *out, int olen, char *buffer, int bufsz, int offset)
{
	int i, len = 0;

	for (i = 0; i < RULES_ALL.count; ++i) {
		np_rule_t *rule = RULES_ALL.array[i];

		len += snprintf(buffer, bufsz - len, "[%08u] %s\n", rule->crc, rule->name_rule);
		if(len <= 0) {
			/* overflow */
			np_error("io buffer overflow. %d\n", len);
		}
	}
	if(offset >= len) {
		/* finished */
		return 0;
	}
	/* copy to user */
	if(len > olen) {
		len = olen;
	}
	memcpy(out, buffer + offset, len);

	return len;
}

void rules_cleanup(void)
{
	int i, j;

	/* clean rule set's */
	for(i=0; i<NP_FLOW_DIR_MAX; i++) {
		for(j=0; j<NP_SET_BASE_MAX; j++){
			set_cleanup(&RS_BASE[i][j]);
		}
	}
	for(i=0; i<RULES_ALL.count; i++) {
		np_rule_t *rule = RULES_ALL.array[i];

		/* cleanup refs. */
		rule_release(rule);
		if(rule->ref_set) {
			set_cleanup(rule->ref_set);
		}
	}
}

const char *flow_dir_name[NP_FLOW_DIR_MAX] = {"ANY", "C2S", "S2C"};
const char *set_inner_name[NP_SET_BASE_MAX] = {"UDP","TCP","OTHER's"};
int rules_build(void)
{
	int i, j, k;
	char name[64];

	/* build id2index */
	for (i = 0; i < RULES_ALL.count; ++i) {
		np_rule_t *rule = RULES_ALL.array[i];
		if(RULES_ALL.id_to_index[rule->ID]) {
			np_error("conflected rule ID: %d\n", rule->ID);
			continue;
		}
		RULES_ALL.id_to_index[rule->ID] = i;
	}

	/* build each ref's */
	for(i=0; i<RULES_ALL.count; i++) {
		np_rule_t *rule1 = RULES_ALL.array[i];
		if(RULE_REFs(rule1)) {
			/* rule1 in-rule's ref as rule2 matched. */
			for(k=0; k<ARRAY_SIZE(rule1->ID_REFs); k++) {
				/* each ref id find the target rule. */
				uint16_t ref_id = rule1->ID_REFs[k];
				if(!ref_id) {
					break;
				}
				/* round2 find the ref target. */
				for(j=0; j<RULES_ALL.count; j++) {
					np_rule_t *rule2 = RULES_ALL.array[j];
					if(rule2->ID != ref_id) {
						continue;
					}
					if(!rule2->ref_set) {
						np_rule_set_t *ref_set;
						snprintf(name, sizeof(name), "ref-%s", rule2->name_rule);
						ref_set = set_alloc(name);
						if(!ref_set) {
							np_error("alloc ref set[%s] failed.\n", rule2->name_rule);
							continue;
						}
						rule2->ref_set = ref_set;
					}
					/* got it */
					np_info("[%s] add ref-to [%s]\n", rule1->name_rule, rule2->name_rule);
					set_add_rule(rule2->ref_set, rule1);
				}
			}
		}
	}

	/* init all set's */
	for(i=0; i<NP_FLOW_DIR_MAX; i++) {
		/* base sets */
		for(j=0; j<NP_SET_BASE_MAX; j++) {
			snprintf(name, sizeof(name), "base: %s-%s", SET_DIR_STR(i), SET_BASE_STR(j));
			set_compile(&RS_BASE[i][j], name);
		}
	}
	/* rule in-match ref. */
	for(i=0; i<RULES_ALL.count; i++) {
		np_rule_t *rule = RULES_ALL.array[i];
		if(rule->ref_set) {
			snprintf(name, sizeof(name), "in-ref: %s", rule->name_rule);
			set_compile(rule->ref_set, name);
		}
	}

	#if 1
	/* dump rules */
	for(i=0; i<NP_FLOW_DIR_MAX; i++) {
		for(j=0; j<NP_SET_BASE_MAX; j++)
		 set_dump(&RS_BASE[i][j], 0);
	}
	#endif

	return 0;
}

static int l4_match(np_rule_t *rule, nt_packet_t *npt)
{
	uint32_t saddr, daddr;
	uint16_t sport, dport, proto;
	l4_match_t *l4 = &rule->l4;

	saddr = ntohl(npt->iph->saddr);
	daddr = ntohl(npt->iph->daddr);
	proto = npt->l4_proto;

	/* check proto */
	if(l4->proto && l4->proto != proto) {
		RULE_DBG(rule, NULL, "l4: proto miss.\n");
		return NP_FALSE;
	}
	switch(proto) {
		case IPPROTO_TCP: {
			sport = ntohs(npt->tcp->source);
			dport = ntohs(npt->tcp->dest);
		} break;
		case IPPROTO_UDP: {
			sport = ntohs(npt->udp->source);
			dport = ntohs(npt->udp->dest);
		} break;
		default: {
			sport = dport = 0;
		} break;
	}

	/* must check ports. */
	if(l4->ports[0]) {
		int i=0, m=0;
		while(l4->ports[i]) {
			if((sport == l4->ports[i]) ||
				(dport == l4->ports[i]))
			{
				m = l4->ports[i]; break;
			}
			i ++;
		}
		if(!m) {
			RULE_DBG(rule, NULL, "l4: ports miss[%d:%d->%d].\n", i, sport, dport);
			return NP_FALSE;
		}
	}

	/* must check addrs. */
	if(l4->addrs[0]) {
		int i=0, m = 0;
		while(l4->addrs[i]) {
			if((saddr == l4->addrs[i]) ||
				(daddr == l4->addrs[i]))
			{
				m = l4->addrs[i]; break;
			}
			i ++;
		}
		if(!m) {
			RULE_DBG(rule, NULL, "l4: addr miss[%d:%x->%x].\n", i, saddr, daddr);
			return NP_FALSE;
		}
	}

	return NP_TRUE;
}

static int len_info_match(np_rule_t *rule, len_match_t *lnm, nt_packet_t *npt)
{
	uint32_t n = 0;
	switch(lnm->type) {
		case NP_LNM_LIST:{
			int i=0;
			while(lnm->list[i]) {
				if(lnm->list[i] == npt->l7_len) {
					return NP_TRUE;
				}
				i++;
			}
			if(i) {
				return NP_FALSE;
			}
		} break;
		case NP_LNM_RANGE:{
			int i=0;
			while(lnm->range[i][0] && lnm->range[i][1]) {
				if(npt->l7_len >= lnm->range[i][0] &&
					npt->l7_len <= lnm->range[i][1])
				{
					return NP_TRUE;
				}
				i++;
			}
			if(i) {
				return NP_FALSE;
			}
		} break;
		case NP_LNM_MATCH:{
			switch(lnm->width) {
				case 1: {
					n = npt->l7_ptr[lnm->offset];
					n += lnm->fixed;
					if(n == npt->l7_len) {
						return NP_TRUE;
					}
				}break;
				case 2: {
					n = (*(uint16_t*)&npt->l7_ptr[lnm->offset]);
					if((ntohs(n) + lnm->fixed == npt->l7_len) ||
						(n + lnm->fixed == npt->l7_len))
					{
						return NP_TRUE;
					}
				}break;
				case 4: {
					n = (*(uint32_t*)&npt->l7_ptr[lnm->offset]);
					if((ntohl(n) + lnm->fixed == npt->l7_len) ||
						(n + lnm->fixed == npt->l7_len))
					{
						return NP_TRUE;
					}
				}break;
				default: {
					np_error("l7 len info width error type: %d\n", lnm->width);
					return NP_FALSE;
				}break;
			}
		} break;
		default:{
			np_error("unknown len info type: %d\n", lnm->type);
			return NP_FALSE;
		} break;
	}

	// RULE_DBG(rule, NULL, "frame[%u-%u] offset:%d fixed: %d\n", n, ntohl(n), lnm->offset, lnm->fixed);
	return NP_FALSE;
}

static uint8_t* ctm_do(np_rule_t *rule, match_t *ctm, uint8_t *data, int dlen)
{
	int mlen, offset;
	/* fixup & compare offset. */
	offset = ctm->offset;
	if(offset < 0) {
		/* revert ctm. */
		offset += dlen;
		if(offset <= 0) {
			RULE_DBG(rule, NULL, "l7: ctm offset fixed faild: %d-%d\n", offset, dlen);
			return NULL;
		}
	}
	/* the last length to match/search. */
	mlen = dlen - offset;
	if(ctm->deep && mlen > ctm->deep) {
		mlen = ctm->deep;
	}

	switch(ctm->type) {
		case MHTP_OFFSET: {
			/* fixed match */
			if(mlen < ctm->length) {
				/* fixed match need check patt len, regexp no need. */
				RULE_DBG(rule, NULL, "l7: ctm fixed length miss.[%d->%d:%d]\n", dlen, offset, ctm->length);
				return NULL;
			}
			if(memcmp(data + offset, ctm->patt, ctm->length) == 0) {
				return data + offset;
			}
			return NULL;
		} break;
		case MHTP_REGEXP: {
			int m = 0;
			if(!ctm->rex) {
				np_error("l7: ctm rex nil.\n");
				return NULL;
			}
			m = pcre_find(ctm->rex, data + offset, mlen);
			if(m>=0) {
				RULE_DBG(rule, NULL, "l7: rex match at: %d\n", m);
				return data + offset + m;
			} else {
				RULE_DBG(rule, NULL, "l7: rex[%s] miss %d.\n", ctm->patt, m);
				np_dump(data + offset, 16, "rex:");
			}
			return NULL;
		} break;
		case MHTP_SEARCH: {
			uint8_t *mc;
			if(!ctm->bmh) {
				np_error("l7: ctm bmh nil.\n");
				return NP_FALSE;
			}
			mc = BMHChr(ctm->bmh, data + offset, mlen);
			if(mc){
				RULE_DBG(rule, NULL, "l7: bmh match at: %d\n", (int)((uint8_t*)mc-data));
				return mc;
			} else {
				RULE_DBG(rule, NULL, "l7: bmh miss.\n");
			}
			return NULL;
		} break;
		default: {
			np_error("l7: ctm not supported type: %d\n", ctm->type);
			return NULL;
		} break;
	}
	return NULL;
}

static int cont_match(np_rule_t *rule, content_match_t *cont, nt_packet_t *npt)
{
	int l7dlen;
	uint8_t *l7data, *wrapper, *mc;

	l7data = wrapper = npt->l7_ptr;
	l7dlen = npt->l7_len;

	if(cont->spec_len && cont->spec_len != l7dlen) {
		RULE_DBG(rule, NULL, "l7: cont length miss.\n");
		return NP_FALSE;
	}

	/* fixup wrapper proto. */
	if(cont->wrap.type == MHTP_REGEXP ||
		cont->wrap.type == MHTP_SEARCH) {
		mc = ctm_do(rule, &cont->wrap, l7data, l7dlen);
		if(!mc) {
			l7data = mc;
			l7dlen -= l7data - wrapper;
			if(l7dlen <= 0) {
				RULE_DBG(rule, NULL, "l7: wrapper - short len.\n");
				return NP_FALSE;
			}
		}
		RULE_DBG(rule, NULL, "l7: wrapper len: %d\n", (uint16_t)(mc - l7data));
	}

	mc = ctm_do(rule, &cont->match, l7data, l7dlen);
	if(!mc) {
		RULE_DBG(rule, NULL, "l7: ctx miss.\n");
		return NP_FALSE;
	}
	return NP_TRUE;
}

static int l7_match(np_rule_t *rule, nt_packet_t *npt)
{
	l7_match_t *l7 = &rule->l7;
	len_match_t *lnm = &l7->lnm;

	if(npt->l7_len == 0) {
		RULE_DBG(rule, NULL, "l7: zero data len.\n");
		return NP_FALSE;
	}
	if(l7->dir && npt->dir != l7->dir) {
		RULE_DBG(rule, NULL, "l7: pkt in flow dir[%d] miss.\n", npt->dir);
		return NP_FALSE;
	}
	if(lnm->type != NP_LNM_NONE && !len_info_match(rule, lnm, npt)) {
		RULE_DBG(rule, NULL, "l7: length[%d] info miss.\n", npt->l7_len);
		return NP_FALSE;
	}
	if(l7->ctm_num == 0) {
		/* upper matched ok. */
		return NP_TRUE;
	} else {
		int i, m = 0;
		for(i=0; i<l7->ctm_num; i++) {
			m = cont_match(rule, &l7->ctm[i], npt);
			if(m && l7->ctm_relation == NP_CTM_OR) {
				RULE_DBG(rule, NULL, "l7: ctm OR matched.\n");
				return NP_TRUE;
			}
			if(!m && l7->ctm_relation == NP_CTM_AND) {
				RULE_DBG(rule, NULL, "l7: ctm AND miss.\n");
				return NP_FALSE;
			}
		}
		if(m && l7->ctm_relation == NP_CTM_AND) {
			RULE_DBG(rule, NULL, "l7: ctm AND matched.\n");
			return NP_TRUE;
		}
	}
	return NP_FALSE;
}

static int http_do_match(np_rule_t *rule, httpm_t *htpm, nt_packet_t *npt)
{
	int mdlen = npt->l7_len;
	uint8_t *mdata = npt->l7_ptr, *mc;
	nt_pkt_nproto_t *np = nt_pkt_nproto(npt);

	switch(np->du_type) {
		case NP_DUT_HTTP_REQ:
		case NP_DUT_HTTP_REP: {
			/* current packet match. */
			if(htpm->hdr != NP_HTTP_END) {
				mdata = np_http_hdr(npt, htpm->hdr, &mdlen);
				if(!mdata || mdlen <= 0) {
					RULE_DBG(rule, NULL, "http: hdr not found.\n");
					return NP_FALSE;
				}
			}
		} break;
		default: {
			/* current flow match */
			if(htpm->hdr != NP_HTTP_END) {
				RULE_DBG(rule, NULL, "http: ctx ignor header.\n");
				return NP_CONTINUE;
			}
			mdata = npt->l7_ptr;
			mdlen = npt->l7_len;
		} break;
	}

	mc = ctm_do(rule, &htpm->match, mdata, mdlen);
	if(mc) {
		RULE_DBG(rule, NULL, "http: ctm matched.\n");
		return NP_TRUE;
	}
	return NP_FALSE;
}

static int http_match(np_rule_t *rule, nt_packet_t *npt)
{
	int i, m = NP_TRUE, relation_OR;
	relation_OR = (rule->http.htp_relation == NP_CTM_OR ? 1 : 0);
	for (i = 0; i <ARRAY_SIZE(rule->http.htpm); ++i) {
		httpm_t *htpm = &rule->http.htpm[i];
		if(htpm->match.length <= 0) {
			break;
		}
		m = http_do_match(rule, htpm, npt);
		if(m == NP_TRUE) {
			if(relation_OR) {
				RULE_DBG(rule, NULL, "http: or matched.\n");
				return NP_TRUE;
			}
		} else if (m == NP_FALSE){
			if(!relation_OR) {
				RULE_DBG(rule, NULL, "http: and miss match.\n");
				return NP_FALSE;
			}
		} else {
			/* try next ... */
			RULE_DBG(rule, NULL, "http: try next. %d\n", i);
			continue;
		}
	}
	return m;
}

static int rule_matched_cb(void *np, void *prule)
{
	np_rule_t *rule = prule;
	RULE_DBG(rule, NULL, "rule: %s, matched.\n", rule->name_rule);
	return NP_TRUE;
}

int rule_one_match(np_rule_t *rule, nt_packet_t *npt,
	int(*matched_cb)(void *nt, void *rule))
{
	int n;

	RULE_DBG(rule, npt, "\t<<<<<<<<---- dir: %d rule: %s\n", npt->dir, rule->name_rule);

	/* do match process. */
	if(rule->enable_l4) {
		n = l4_match(rule, npt);
		if(!n) {
			/* miss match. */
			RULE_DBG(rule, npt, "l4: miss match. ---->>>>>>>>\n");
			return NP_FALSE;
		}
	}
	/* do match l7 */
	if(rule->enable_l7) {
		n = l7_match(rule, npt);
		if(!n) {
			RULE_DBG(rule, npt, "l7: miss match. ---->>>>>>>>\n");
			return NP_FALSE;
		}
	}

	/* do http match */
	if(RULE_REF_HTTP(rule)) {
		n = http_match(rule, npt);
		if(!n) {
			RULE_DBG(rule, npt, "http: miss match. ---->>>>>>>>\n");
			return NP_FALSE;
		}
	}

	/* all matched, test the callbacks. */
	if(rule->proto_cb) {
		/* rule's proto parser callback. */
		rule->proto_cb(npt, rule);
	}
	if(matched_cb) {
		/* rule match callback. */
		return matched_cb(npt, rule);
	}
	return NP_TRUE;
}

/*
** @return: !=0 -> ture, 0:false -> try next.
*/
static int mwmOnMatch(void* rule, void *npt, void *out)
{
	if(rule_one_match(rule, npt, rule_matched_cb)) {
		out = rule;
		return NP_TRUE;
	}
	return NP_FALSE;
}

np_rule_t *rules_set_match(np_rule_set_t *set, nt_packet_t *npt)
{
	int i, mdlen = npt->l7_len;
	uint8_t *mdata = npt->l7_ptr;
	mwm_t *pmwm = set->pmwm;
	mwm_t *pmwm_host = set->pmwm_host;

	np_debug("%s\n", set->name);

	for (i = 0; i <set->num_rules; i++) {
		np_rule_t* rule = set->rules[i];
		if(rule_one_match(rule, npt, rule_matched_cb)) {
			/* direct matched. */
			np_debug("direct matched: %s\n", rule->name_rule);
			return rule;
		}
	}
	/* search dst ip addr. */

	/* search http host, only as set's ref-http. */
	if(pmwm_host) {
		/* HTTP ref-match */
		void *out = NULL;
		mdata = np_http_hdr(npt, NP_HTTP_Host, &mdlen);
		if(!mdata || mdlen <= 0) {
			np_debug("host not found.\n");
			goto __next_mwm;
		}
		mwmSearch(pmwm_host, mdata, mdlen, npt, &out, mwmOnMatch);
		if(out) {
			np_rule_t *rule = out;
			np_debug("mwm host matched: %s\n", rule->name_rule);
			return rule;
		}
	}

__next_mwm:
	/* search l7 content OR http payload. */
	if(pmwm) {
		void* out = NULL;
		mwmSearch(pmwm, mdata, mdlen, npt, &out, mwmOnMatch);
		if(out) {
			np_rule_t* rule = out;
			np_debug("mwm matched: %s\n", rule->name_rule);
			return rule;
		}
	}

	return NULL;
}

int nproto_rules_match(nt_packet_t *npt)
{
	np_rule_t *rule = NULL, *mlast = NULL;
	np_rule_set_t *base_set = &RS_BASE[npt->dir][np_proto_to_set(npt->l4_proto)];

	uint16_t proto = nt_flow_nproto(npt->fi);
	if(!proto) {
		/* unknown proto yet. */
		rule = rules_set_match(base_set, npt);
		if(rule) {
			mlast = rule;
			np_debug("base match: %s\n", rule->name_rule);
		}
		/* current packet's ref match. */
		if(rule && rule->ref_set) {
			rule = rules_set_match(rule->ref_set, npt);
			if(rule) {
				mlast = rule;
				np_debug("inner-ref match: %s\n", rule->name_rule);
			}
		}
	} else {
		/* cross packet, same flow ref match */
		rule = get_rule_by_id(proto);
		if(rule && rule->ref_set) {
			rule = rules_set_match(rule->ref_set, npt);
			if(rule) {
				mlast = rule;
				np_debug("flow-ref match: %s\n", rule->name_rule);
			}
		}
	}

	/* base matched, check the cross packets ref. */
	if(mlast) {
		/* proto maybe changed. */
		proto = mlast->ID;
		if(RULE_IS_FIN(mlast)) {
			nt_flow_nproto_fin_set(npt->fi);
		}
		nproto_update(npt, mlast);

		/* DEBUG */
		np_info(FMT_FLOW_STR"\n\t\t[%s] --- matched %s--- \n",
			FMT_FLOW(npt->fi),
			mlast->name_rule,
			RULE_IS_FIN(mlast)?"fin":"mid");
		/* END debug. */
	}

	return mlast ? mlast->ID : 0;
}

int nproto_init(void)
{
	int ret;

	ret = mwmSysInit(NP_MWM_STR);
	if(ret) {
		np_error("mwm init failed.\n");
		return -ENOMEM;
	}
	ret = pcre_init();
	if(ret) {
		np_error("pcre init failed. %d\n", ret);
		goto __erro_pcre;
	}

	memset(&RULES_ALL, 0, sizeof(RULES_ALL));
	memset(&inner_rules, 0, sizeof(inner_rules));
	memset(&RS_BASE, 0, sizeof(RS_BASE));

	ret = inner_rules_init();
	if(ret) {
		np_error("inner rules init failed.\n");
		goto __erro_rules;
	}

	ret = rules_build();
	if(ret){
		np_error("rules build.\n");
		goto __erro_compile;
	}
	return 0;

__erro_compile:
	rules_cleanup();
__erro_rules:
	pcre_cleanup();
__erro_pcre:
	mwmSysClean(NP_MWM_STR);
	return ret;
}

void nproto_cleanup(void)
{
	rules_cleanup();
	pcre_cleanup();
	mwmSysClean(NP_MWM_STR);
}
