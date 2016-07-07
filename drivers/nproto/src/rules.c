// #define __DEBUG

#include <linux/udp.h>
#include <linux/tcp.h>

#include <linux/nos_track.h>

#include <nproto/http.h>

#include "mwm.h"
#include "bmh.h"
#include "rules.h"
#include "pcre.h"

#define RULE_DBG_ID NP_INNER_RULE_HTTP_REQ

/* ... */
#ifdef RULE_DBG_ID
#define RULE_DBG(rule, npt, fmt...)  do { \
		if(rule->ID == RULE_DBG_ID){ \
			if(npt){ \
				np_print("%d: "FMT_PKT_STR"\n\t", __LINE__, FMT_PKT((nt_packet_t*)npt)); \
			} \
			np_print(fmt); \
		} \
	}while(0)
#else
#define RULE_DBG(rule, npt, fmt...) do{}while(0)
#endif

#define np_assert(x) BUG_ON(!(x))

#define NP_MWM_STR "nproto"
#define NP_RULE_SETS_HASH 4096 /* max 4k rule id be-refed. */

/* inner data struct's */
static np_rule_t *inner_rules[NP_INNER_RULE_MAX];
static np_rule_set_t *RS_REFs[NP_RULE_SETS_HASH] = {NULL,};
static np_rule_set_t RS_BASE[NP_FLOW_DIR_MAX][NP_SET_BASE_MAX];

static LIST_HEAD(all_rules);

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
			http_match_rule_t *htpm = &rule->http.htpm[i];
			if(ctm_init(rule, &htpm->match) > 0) {
				break;
			}
		}
	}
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
	if(rule->enable_http) {
		for(i=0; i<ARRAY_SIZE(rule->http.htpm); i++) {
			http_match_rule_t *htpm = &rule->http.htpm[i];
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
	return 0;
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

static int set_add_rule_mwm(np_rule_set_t *set, np_rule_t *rule, match_t *ctm)
{
	int n;
	mwm_t *mwm = set->pmwm;

	/* init mwm st.. */
	if(!mwm) {
		mwm = mwmNew();
		if(mwm) {
			np_error("create mwm failed.\n");
			return set_add_rule_normal(set, rule);
		}
		set->pmwm = mwm;
	}
	/* add patters & rule to mwm. */
	n = mwmAddPatternEx(mwm, ctm->patt, ctm->length, ctm->offset, ctm->deep, rule);
	if(n<0) {
		np_error("mwm prepare %s:%d error.\n", rule->name_rule, rule->ID);
		return set_add_rule_normal(set, rule);
	} else {
		np_info("mwm add rule[%s:%d].\n", rule->name_rule, rule->ID);
	}
	return 0;
}

static int set_add_rule(np_rule_set_t *set, np_rule_t *rule)
{
	int i;

	np_assert(set);
	np_assert(rule);

	/* check l7 search && patt len > 4 */
	if(!rule->enable_l7 && !RULE_REF_HTTP(rule)) {
		return set_add_rule_normal(set, rule);
	}
	/* http search && length >= 4 */
	if(RULE_REF_HTTP(rule)) {
		for(i=0; i<ARRAY_SIZE(rule->http.htpm); i++) {
			match_t *ctm = &rule->http.htpm[i].match;
			if(ctm->type == MHTP_SEARCH && ctm->length >= 4) {
				return set_add_rule_mwm(set, rule, ctm);
			}
		}
	} else {
		for(i=0; i<rule->l7.ctm_num; i++) {
			match_t *ctm = &rule->l7.ctm[i].match;
			if(ctm->type == MHTP_SEARCH && ctm->length >= 4) {
				/* ! search & patt length >= 4 */
				return set_add_rule_mwm(set, rule, ctm);
			}
		}
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
	list_add_tail(&rule->list, &all_rules);

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

int set_compile(np_rule_set_t *set, char *name)
{
	int ret;

	snprintf(set->name, sizeof(set->name), "%s", name);
	if(set->pmwm) {
		ret = mwmPrepPatterns(set->pmwm);
		if(ret < 0) {
			np_error("init mwm - failed.\n");
			return -EINVAL;
		} else if(ret == 0) {
			mwmFree(set->pmwm);
			set->pmwm = NULL;
		} else {
			mwmGroupDetails(set->pmwm);
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

	while(stage--) {
		np_print("\t\t");
	}
	np_print("----[%s:%d]----\n", set->name, set->num_rules);
	if(set->pmwm) {
		mwmGroupDetails(set->pmwm);
	}
	for(i=0; i<set->num_rules; i++) {
		np_rule_t *rule = set->rules[i];
		rule_dump(rule);
	}
	return;
}

void rules_cleanup(void)
{
	int i, j;
	struct list_head *itr;

	/* clean rule set's */
	for(i=0; i<NP_FLOW_DIR_MAX; i++) {
		for(j=0; j<NP_SET_BASE_MAX; j++){
			set_cleanup(&RS_BASE[i][j]);
		}
	}
	for(i=0; i<NP_RULE_SETS_HASH; i++) {
		np_rule_set_t *hash_set = RS_REFs[i];
		if(hash_set) {
			set_cleanup(hash_set);
		}
	}
	list_for_each(itr, &all_rules) {
		np_rule_t *rule = list_entry(itr, np_rule_t, list);
	
		/* cleanup refs. */
		rule_release(rule);
		if(rule->ref_set) {
			set_cleanup(rule->ref_set);
		}
	}
}

const char *flow_dir_name[NP_FLOW_DIR_MAX] = {"any", "c2s", "s2c"};
const char *set_inner_name[NP_SET_BASE_MAX] = {"udp","tcp","others"};
int rules_build(void)
{
	int i, j;
	char name[64];
	struct list_head *itr1, *itr2;

	/* build the http ref's */
	list_for_each(itr1, &all_rules) {
		np_rule_t *rule1 = list_entry(itr1, np_rule_t, list);
		if(rule1->ID != NP_INNER_RULE_HTTP_REQ &&
			rule1->ID != NP_INNER_RULE_HTTP_REP) 
		{
			continue;
		}
		/* round2 find the http ref rules. */
		list_for_each(itr2, &all_rules) {
			np_rule_t *rule2 = list_entry(itr2, np_rule_t, list);
			if(rule1 == rule2) { /* self */
				continue;
			}
			if(RULE_REF_HTTP(rule2)) {
				/* assert not base rule. */
				np_assert(!RULE_IS_BASE(rule2));
				for(i=0; i<ARRAY_SIZE(rule1->ID_REFs); i++) {
					if(!rule2->ID_REFs[i]) {
						break;
					}
				}
				rule2->ID_REFs[i] = rule1->ID;
			}
		}
	}

	/* build each ref's */
	list_for_each(itr1, &all_rules) {
		np_rule_t *rule1 = list_entry(itr1, np_rule_t, list);
		if(RULE_REF_FLOW(rule1)) {
			/* cross rule match use hash sets. */
			uint16_t idx = rule1->ID % NP_RULE_SETS_HASH;
			np_rule_set_t *hash_set = RS_REFs[idx];
			if(!hash_set) {
				hash_set = set_alloc("hash");
				if(!hash_set) {
					np_error("alloc hash set[%d:%s] failed.\n", rule1->ID, rule1->name_rule);
					continue;
				}
				RS_REFs[idx] = hash_set;
			}
			set_add_rule(hash_set, rule1);
		}
		if(RULE_REF_PACKET(rule1)) {
			/* rule1 in-rule's ref as rule2 matched. */
			for(i=0; i<ARRAY_SIZE(rule1->ID_REFs); i++) {
				/* each ref id find the target rule. */
				uint16_t ref_id = rule1->ID_REFs[i];
				if(!ref_id) {
					break;
				}
				/* round2 find the ref target. */
				list_for_each(itr2, &all_rules) {
					np_rule_t *rule2 = list_entry(itr2, np_rule_t, list);
					if(rule2->ID != ref_id) {
						continue;
					}
					if(rule1 == rule2) {
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
	list_for_each(itr1, &all_rules) {
		np_rule_t *rule = list_entry(itr1, np_rule_t, list);
		if(rule->ref_set) {
			snprintf(name, sizeof(name), "in-ref: %s", rule->name_rule);
			set_compile(rule->ref_set, name);
		}
	}
	/* cross rule matched ref. */
	for(i=0; i<NP_RULE_SETS_HASH; i++) {
		np_rule_set_t *hash_set = RS_REFs[i];
		if(!hash_set) {
			continue;
		}
		snprintf(name, sizeof(name), "hash-ref: %d", i);
		set_compile(hash_set, name);
	}

	#if 1
	/* dump rules */
	for(i=0; i<NP_FLOW_DIR_MAX; i++) {
		for(j=0; j<NP_SET_BASE_MAX; j++)
		 set_dump(&RS_BASE[i][j], 0);
	}
	for(i=0; i<NP_RULE_SETS_HASH; i++) {
		np_rule_set_t *hash_set = RS_REFs[i];
		if(hash_set) {
			set_dump(hash_set, 0);
		}
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
				RULE_DBG(rule, NULL, "l7: rex miss.\n");
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

static int http_do_match(np_rule_t *rule, http_match_rule_t *htpm, nt_packet_t *npt)
{
	int mlen = npt->l7_len, m;
	uint8_t *hdr, *mdata = npt->l7_ptr, *mc;
	nt_pkt_nproto_t *np = nt_pkt_nproto(npt);

	switch(np->du_type) {
		case NP_DUT_HTTP_REQ:
		case NP_DUT_HTTP_REP: {
			/* current packet match. */
			switch(htpm->hdr) {
				case 0: {
					/* context search/regext match. */
					hdr = np_http_hdr(npt, NP_HTTP_END, &m);
					if(hdr && m > 0) {
						mdata = hdr + m;
						mlen -= (mdata - npt->l7_ptr);
					}
					if(mlen <= 0) {
						RULE_DBG(rule, NULL, "http: nil content.\n");
						return NP_FALSE;
					}
				} break;
				default: {
					hdr = np_http_hdr(npt, htpm->hdr, &mlen);
					if(!hdr) {
						RULE_DBG(rule, NULL, "http: hdr not found.\n");
						return NP_FALSE;
					}
					mdata = hdr;
				}break;
			}
		} break;
		default: {
			/* current flow match */
			if(htpm->hdr != NP_HTTP_END) {
				RULE_DBG(rule, NULL, "http: ctx ignor header.\n");
				return NP_CONTINUE;
			}
			mdata = npt->l7_ptr;
			mlen = npt->l7_len;
		} break;
	}

	mc = ctm_do(rule, &htpm->match, mdata, mlen);
	if(mc) {
		RULE_DBG(rule, NULL, "http: ctm matched.\n");
		return NP_TRUE;
	}
	return NP_FALSE;
}

static int http_match(np_rule_t *rule, nt_packet_t *npt)
{
	int i, m = NP_TRUE, relation_OR;
	relation_OR = (rule->http.relation == NP_CTM_OR ? 1 : 0);
	for (i = 0; i <ARRAY_SIZE(rule->http.htpm); ++i) {
		http_match_rule_t *htpm = &rule->http.htpm[i];
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

	RULE_DBG(rule, npt, "-------- dir: %d rule: %s\n", npt->dir, rule->name_rule);

	/* do match process. */
	if(rule->enable_l4) {
		n = l4_match(rule, npt);
		if(!n) {
			/* miss match. */
			RULE_DBG(rule, npt, "l4: miss match. -------- \n");
			return NP_FALSE;
		}
	}
	/* do match l7 */
	if(rule->enable_l7) {
		n = l7_match(rule, npt);
		if(!n) {
			RULE_DBG(rule, npt, "l7: miss match. -------- \n");
			return NP_FALSE;
		}
	}

	/* do http match */
	if(rule->enable_http) {
		n = http_match(rule, npt);
		if(!n) {
			RULE_DBG(rule, npt, "http: miss match. -------- \n");
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
	int i;
	mwm_t *pmwm = set->pmwm;

	for (i = 0; i <set->num_rules; i++) {
		np_rule_t* rule = set->rules[i];
		if(rule_one_match(rule, npt, rule_matched_cb)) {
			/* direct matched. */
			np_debug("direct matched: %s\n", rule->name_rule);
			return rule;
		}
	}
	if(pmwm) {
		void* out = NULL;
		mwmSearch(pmwm, npt->l7_ptr, npt->l7_len, npt, &out, mwmOnMatch);
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
	np_rule_set_t *hash_set = NULL;
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
	}

	/* base matched, check the cross packets ref. */
	if(mlast) {
		/* proto maybe changed. */
		proto = mlast->ID;
	}

	/* assert the valid proto index. */
	np_assert(proto < NP_RULE_SETS_HASH);

	hash_set = RS_REFs[proto % NP_RULE_SETS_HASH];
	if(hash_set) {
		rule = rules_set_match(hash_set, npt);
		if(rule) {
			mlast = rule;
			np_debug("hash-ref match: %s\n", rule->name_rule);
		}
	}
	/* proto change save to flow. */
	if(mlast) {
		if(RULE_IS_FIN(mlast)) {
			nt_flow_nproto_fin_set(npt->fi);
		}
		nt_flow_nproto_update(npt->fi, mlast->ID, NULL);
	}
	
	/* DEBUG */
	if(mlast) {
		np_info(FMT_FLOW_STR"\n\t\t[%s] --- matched %s--- \n", 
			FMT_FLOW(npt->fi),
			mlast->name_rule, 
			RULE_IS_FIN(mlast)?"fin":"mid");
	}
	/* END debug. */

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

	memset(&inner_rules, 0, sizeof(inner_rules));
	memset(&RS_BASE, 0, sizeof(RS_BASE));
	memset(&RS_REFs, 0, sizeof(RS_REFs));

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
