// #define __DEBUG

#include <linux/udp.h>
#include <linux/tcp.h>

#include <linux/nos_track.h>

#include "mwm.h"
#include "rules.h"

#if 0
#define RULE_DBG(rule, fmt...)  do { \
		if(rule->ID == NP_INNER_RULE_HTTP_REP){ \
			np_debug(fmt); \
		} \
	}while(0)
#else
#define RULE_DBG(rule, fmt...) do{}while(0)
#endif
#define np_assert(x) BUG_ON(!(x))

#define NP_MWM_STR "nproto"
#define NP_RULE_SETS_HASH 4096 /* max 4k rule id be-refed. */

/* inner data struct's */
np_rule_t *inner_rules[NP_INNER_RULE_MAX];
np_rule_set_t *rule_sets_refs[NP_RULE_SETS_HASH] = {NULL,};
np_rule_set_t rule_sets_base[NP_FLOW_DIR_MAX][NP_SET_BASE_MAX];

static LIST_HEAD(all_rules);

static int rule_compile(np_rule_t *rule)
{
	/* init rule callback ok. */
	if(rule->proto_init && rule->proto_init()) {
		np_error("init proto callback failed.\n");
		return -EINVAL;
	}

	/* init bmh/regexp struct. */
	return 0;
}

static void rule_release(np_rule_t *rule)
{
	/* release the dmalloc mem. */
	if(rule->proto_clean) {
		rule->proto_clean();
	}
}

static void rule_dump(np_rule_t *rule)
{
	int i;

	np_print("dump rule[%s] Proto[%s] Service[%s]:\n", 
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
}

static int set_add_rule_normal_sorted(np_rule_set_t *set, np_rule_t *rule)
{
	if(rule->priority == NP_RULE_PRI_MIN) {
		set->rules[set->num_rules] = rule;
	} else if(rule->priority == NP_RULE_PRI_MAX) {
		if(set->num_rules > 0)
			memmove(&set->rules[1], set->rules, sizeof(set->rules[0]) * set->num_rules);
		set->rules[0] = rule;
	} else {
		/* find the insert position */
		int L = 0;
		int H = set->num_rules - 1;
		int M, C;
		while(L <= H) {
			M = (L + H) / 2;
			if(set->rules[M]->priority == rule->priority) {
				H = M;
				break;
			} else {
				if(set->rules[M]->priority < rule->priority) {
					H = M - 1; /* < */
				} else {
					L = M + 1; /* > */
				}
			}
		}
		/* move [H],([H+1]),[H+2]... */
		C = set->num_rules - (H + 1);
		if(C > 0) {
			memmove(&set->rules[H + 2], &set->rules[H + 1], sizeof(set->rules[0]) * C);
		}
		set->rules[H + 1] = rule;
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

static int set_add_rule(np_rule_set_t *set, np_rule_t *rule)
{
	int i, n, rule_in_mwm = 0;

	np_assert(set);
	np_assert(rule);

	/* check l7 search && patt len > 4 */
	if(!rule->enable_l7) {
		set_add_rule_normal(set, rule);
	}

	for(i=0; i<rule->l7.ctm_num; i++) {
		mwm_t *mwm = set->pmwm;
		content_match_t *ct = &rule->l7.ctm[i];

		/* search & patt length >= 4 */
		if(!(ct->type_match == MHTP_SEARCH && ct->patt_len >= 4))
			continue;

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
		n = mwmAddPatternEx(mwm, ct->patt, ct->patt_len, ct->offset, ct->deep, rule);
		if(n<0) {
			np_error("mwm prepare %s:%d error.\n", rule->name_rule, rule->ID);
			return set_add_rule_normal(set, rule);
		} else {
			rule_in_mwm = 1;
			np_info("mwm add rule[%s:%d] ct[%d]\n", rule->name_rule, rule->ID, i);
		}
	}

	/* default add to normal set */
	if(!rule_in_mwm) {
		return set_add_rule_normal(set, rule);
	}

	return 0;
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
	return set_add_rule(&rule_sets_base[dir][proto], rule);
}

void set_clean(np_rule_set_t *set)
{
	if(set->pmwm) {
		mwmFree(set->pmwm);
	}
}

int set_init(np_rule_set_t *set, char *name)
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

void set_dump(np_rule_set_t *set)
{
	int i;

	if(set->num_rules == 0 && set->pmwm == NULL) {
		/* empty */
		return;
	}

	np_print(" ---- rule-set [%s] ---- \n", set->name);
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
			set_clean(&rule_sets_base[i][j]);
		}
	}
	for(i=0; i<NP_RULE_SETS_HASH; i++) {
		np_rule_set_t *hash_set = rule_sets_refs[i];
		if(hash_set) {
			set_clean(hash_set);
		}
	}
	list_for_each(itr, &all_rules) {
		np_rule_t *rule = list_entry(itr, np_rule_t, list);
	
		/* cleanup refs. */
		rule_release(rule);
		if(rule->ref_set) {
			set_clean(rule->ref_set);
		}
	}
}

int rules_build(void)
{
	int i, j;
	char name[64];
	struct list_head *itr1, *itr2;

	/* build each ref's */
	list_for_each(itr1, &all_rules) {
		np_rule_t *rule1 = list_entry(itr1, np_rule_t, list);
		if(RULE_REF_RULES(rule1)) {
			/* cross rule match use hash sets. */
			uint16_t idx = rule1->ID % NP_RULE_SETS_HASH;
			np_rule_set_t *hash_set = rule_sets_refs[idx];
			if(!hash_set) {
				hash_set = kmalloc(sizeof(np_rule_set_t), GFP_KERNEL);
				if(!hash_set) {
					np_error("alloc hash set[%d:%s] failed.\n", rule1->ID, rule1->name_rule);
					continue;
				}
				memset(hash_set, 0, sizeof(np_rule_set_t));
				rule_sets_refs[idx] = hash_set;
			}
			set_add_rule(hash_set, rule1);
		}
		if(RULE_REF_MATCH(rule1)) {
			/* rule1 in-rule's ref as rule2 matched. */
			for(i=0; i<sizeof(rule1->ID_REFs)/sizeof(rule1->ID_REFs[0]); i++) {
				/* each ref id find the target rule. */
				uint16_t ref_id = rule1->ID_REFs[i];
				if(!ref_id) {
					break;
				}
				/* round2 find the ref target. */
				list_for_each(itr2, &all_rules) {
					np_rule_t *rule2 = list_entry(itr2, np_rule_t, list);
					if(rule1 == rule2) { /* self */
						continue;
					}
					if(!rule1->ref_set) {
						np_rule_set_t *ref_set = kmalloc(sizeof(np_rule_set_t), GFP_KERNEL);
						if(!ref_set) {
							np_error("alloc ref set[%s] failed.\n", rule1->name_rule);
							continue;
						}
						rule1->ref_set = ref_set;
					}
					if(rule2->ID == ref_id) {
						/* got it */
						set_add_rule(rule1->ref_set, rule2);
					}
				}
			}
		}
	}

	/* init all set's */
	for(i=0; i<NP_FLOW_DIR_MAX; i++) {
		/* base sets */
		for(j=0; j<NP_SET_BASE_MAX; j++) {
			snprintf(name, sizeof(name), "base: %d-%d", i, j);
			set_init(&rule_sets_base[i][j], name);
		}
	}
	/* rule in-match ref. */
	list_for_each(itr1, &all_rules) {
		np_rule_t *rule = list_entry(itr1, np_rule_t, list);
		if(rule->ref_set) {
			snprintf(name, sizeof(name), "in-ref: %s", rule->name_rule);
			set_init(rule->ref_set, name);
		}
	}
	/* cross rule matched ref. */
	for(i=0; i<NP_RULE_SETS_HASH; i++) {
		np_rule_set_t *hash_set = rule_sets_refs[i];
		if(!hash_set) {
			continue;
		}
		snprintf(name, sizeof(name), "hash-ref: %d", i);
		set_init(hash_set, name);
	}

	#if 1
	/* dump rules */
	for(i=0; i<NP_FLOW_DIR_MAX; i++) {
		for(j=0; j<NP_SET_BASE_MAX; j++)
		 set_dump(&rule_sets_base[i][j]);
	}
	for(i=0; i<NP_RULE_SETS_HASH; i++) {
		np_rule_set_t *hash_set = rule_sets_refs[i];
		if(hash_set) {
			set_dump(hash_set);
		}
	}
	#endif

	return 0;
}

static int l4_match(l4_match_t *l4, nt_packet_t *npt)
{
	uint32_t saddr, daddr;
	uint16_t sport, dport, proto;

	saddr = npt->iph->saddr;
	daddr = npt->iph->daddr;
	proto = npt->l4_proto;

	/* check proto */
	if(l4->proto && l4->proto != proto) {
		return NP_FALSE;
	}
	switch(proto) {
		case IPPROTO_TCP: {
			sport = npt->tcp->source;
			dport = npt->tcp->dest;
		} break;
		case IPPROTO_UDP: {
			sport = npt->udp->source;
			dport = npt->udp->dest;
		} break;
		default: {
			sport = dport = 0;
		} break;
	}

	/* must check addrs. */
	if(l4->addrs[0]) {
		int i=0, m = 0;
		while(l4->addrs[i++]) {
			if((ntohl(saddr) == l4->addrs[i]) || 
				(ntohl(daddr) == l4->addrs[i])) 
			{
				m = 1; break;
			}
		}
		if(!m) {
			return NP_FALSE;
		}
	}

	/* must check ports. */
	if(l4->ports[0]) {
		int i=0, m=0;
		while(l4->ports[i++]) {
			if((ntohs(sport) == l4->ports[i]) || 
				(ntohs(dport) == l4->ports[i])) 
			{
				m = 1; break;
			}
		}
		if(!m) {
			return NP_FALSE;
		}
	}

	return NP_TRUE;
}

static int lnm_match(len_match_t *lnm, nt_packet_t *npt)
{
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
			uint32_t n;
			switch(lnm->width) {
				case 1: {
					n = npt->l7_ptr[lnm->offset];
					n += lnm->fixed;
					if(n == npt->l7_len) {
						return NP_TRUE;
					}
				}break;
				case 2: {
					n = (((uint16_t)(npt->l7_ptr[lnm->offset])<<8 & 0xff00) |
						     ((uint16_t)(npt->l7_ptr[lnm->offset+1]) & 0x00ff));
					if((ntohs(n) + lnm->fixed == npt->l7_len) ||
						(n+lnm->fixed == npt->l7_len)) 
					{
						return NP_TRUE;
					}
				}break;
				case 4: {
					n = (((uint32_t)(npt->l7_ptr[lnm->offset])<<24 & 0xff000000) | 
					((uint32_t)(npt->l7_ptr[lnm->offset+1])<<16 & 0x00ff0000) |
					((uint32_t)(npt->l7_ptr[lnm->offset+2])<<8 & 0x0000ff00) |
					((uint32_t)(npt->l7_ptr[lnm->offset+3]) & 0x000000ff));
					if((ntohl(n) + lnm->fixed == npt->l7_len) || 
						(n+lnm->fixed == npt->l7_len)) 
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

	return NP_FALSE;
}

static int cont_match(content_match_t *cont, nt_packet_t *npt)
{
	int start = 0, end = 0, offset = 0, l7dlen;
	uint8_t *l7data = NULL, *wrapper = NULL;

	l7data = npt->l7_ptr;
	l7dlen = npt->l7_len;

	if(cont->spec_len && cont->spec_len != l7dlen) {
		np_debug("l7: cont length miss match.\n");
		return NP_FALSE;
	}
	if(cont->wrap_len > 0) {
		if(l7dlen < (cont->wrap_begin + cont->wrap_len)) {
			np_debug("l7: cont fake wrapper dlen.\n");
			return NP_FALSE;
		}
		start = cont->wrap_begin;
		end = l7dlen;
		if(cont->wrap_end) {
			end = l7dlen > cont->wrap_end ? cont->wrap_end : l7dlen;
		}
		if(start <= end) {
			np_debug("l7: cont fake wrapper len.\n");
			return NP_FALSE;
		}
		if(cont->wrap_rex) {
			/* regexp match */
			if(wrapper) {
				offset = wrapper - l7data;
			}
		}
		if(cont->wrap_bmh) {
			/* BMH wrapper single string. */
			if(wrapper) {
				offset = wrapper - l7data;
			}
		}
	}

	if(cont->patt_len > 0) {
		switch(cont->type_match) {
			case MHTP_OFFSET: {
				offset += cont->offset;
				/* compare offset. */
				if(offset < 0) {
					/* revert match. */
					if(l7dlen + offset < 0) {
						np_debug("l7: cont offset fixed faild: %d-%d\n", offset, l7dlen);
						return NP_FALSE;
					}
					offset += l7dlen;
				}
				/* fixed match */
				if(l7dlen < offset + cont->patt_len) {
					np_debug("l7: cont fixed length miss match.\n");
					return NP_FALSE;
				}
				return memcmp(l7data + offset, cont->patt, cont->patt_len) == 0 ? NP_TRUE : NP_FALSE;
			}break;
			case MHTP_REGEXP: {
				if(!cont->rex) {
					np_error("l7: cont rex nil.\n");
					return NP_FALSE;
				}
				return NP_TRUE;
			}break;
			case MHTP_SEARCH: {
				if(!cont->bmh) {
					np_error("l7: cont bmh nil.\n");
					return NP_FALSE;
				}
				return NP_TRUE;
			}break;
			case MHTP_HTTP_CTX: {
				return NP_TRUE;
			}break;
			default: {
				np_error("l7: cont not supported type: %d\n", cont->type_match);
				return NP_FALSE;
			}break;
		}
	}

	return NP_TRUE;
}

static int l7_match(l7_match_t *l7, nt_packet_t *npt)
{
	len_match_t *lnm = &l7->lnm;

	if(npt->l7_len == 0) {
		np_debug("l7: zero data len.\n");
		return NP_FALSE;
	}
	if(l7->dir && npt->dir != l7->dir) {
		np_debug("l7: pkt in flow dir miss match.\n");
		return NP_FALSE;
	}
	if(lnm->type != NP_LNM_NONE && !lnm_match(lnm, npt)) {
		np_debug("l7: length info miss match.\n");
		return NP_FALSE;
	}
	if(l7->ctm_num > 0) {
		int i, m = 0;
		for(i=0; i<l7->ctm_num; i++) {
			m = cont_match(&l7->ctm[i], npt);
			if(m && l7->ctm_relation == NP_CTM_OR) {
				np_debug("l7 ctm OR matched.\n");
				return NP_TRUE;
			}
			if(!m && l7->ctm_relation == NP_CTM_AND) {
				np_debug("l7 ctm AND miss matched.\n");
				return NP_FALSE;
			}
		}
		if(m && l7->ctm_relation == NP_CTM_AND) {
			np_debug("l7 ctm AND matched.\n");
			return NP_TRUE;
		}
	}
	return NP_FALSE;
}

static int rule_matched_cb(void *np, void *prule)
{
	np_rule_t *rule = prule;
	
	np_debug("rule: %s, matched.\n", rule->name_rule);
	return NP_TRUE;
}

int rule_one_match(np_rule_t *rule, nt_packet_t *npt, 
	int(*matched_cb)(void *nt, void *rule))
{
	int n;

	RULE_DBG(rule, "dir: %d rule: %s\n", npt->dir, rule->name_rule);

	/* do match process. */
	if(rule->enable_l4) {
		n = l4_match(&rule->l4, npt);
		if(!n) {
			/* miss match. */
			RULE_DBG(rule, "l4: miss match.\n");
			return NP_FALSE;
		}
	}
	/* do match l7 */
	if(rule->enable_l7) {
		n = l7_match(&rule->l7, npt);
		if(!n) {
			RULE_DBG(rule, "l7: miss match.\n");
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

int rules_match(nt_packet_t *npt)
{
	uint16_t proto = 0;
	np_rule_t *rule;
	np_rule_set_t *hash_set = NULL;
	np_rule_set_t *base_set = &rule_sets_base[npt->dir][np_proto_to_set(npt->l4_proto)];

	rule = rules_set_match(base_set, npt);
	if(rule) {
		np_debug("base match: %s\n", rule->name_rule);
	}

	if(rule && rule->ref_set) {
		rule = rules_set_match(rule->ref_set, npt);
		if(rule) {
			np_debug("inner-ref match: %s\n", rule->name_rule);
		}
	}

	proto = nt_flow_proto(npt->fi);
	// np_assert(proto >= NP_RULE_SETS_HASH);
	hash_set = rule_sets_refs[proto % NP_RULE_SETS_HASH];
	if(hash_set) {
		rule = rules_set_match(hash_set, npt);
		if(rule) {
			np_debug("hash-ref match: %s\n", rule->name_rule);
		}
	}
	return 0;
}

int nproto_init(void)
{
	int ret;

	mwmSysInit(NP_MWM_STR);

	memset(&inner_rules, 0, sizeof(inner_rules));
	memset(&rule_sets_base, 0, sizeof(rule_sets_base));
	memset(&rule_sets_refs, 0, sizeof(rule_sets_refs));

	ret = inner_rules_init();
	if(ret) {
		np_error("inner rules init failed.\n");
		return ret;
	}

	ret = rules_build();
	if(ret){
		np_error("rules build.\n");
		return ret;
	}
	return 0;
}

void nproto_cleanup(void)
{
	rules_cleanup();
	mwmSysClean(NP_MWM_STR);
}
