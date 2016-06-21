// #define __DEBUG

#include <linux/udp.h>
#include <linux/tcp.h>

#include <linux/nos_track.h>

#include "mwm.h"
#include "rules.h"
#include "pcre.h"

#define RULE_DBG_ID NP_INNER_RULE_SSL

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
np_rule_t *inner_rules[NP_INNER_RULE_MAX];
np_rule_set_t *rule_sets_refs[NP_RULE_SETS_HASH] = {NULL,};
np_rule_set_t rule_sets_base[NP_FLOW_DIR_MAX][NP_SET_BASE_MAX];

static LIST_HEAD(all_rules);

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
			if(ctm->type_wrap == MHTP_REGEXP) {
				if(!ctm->wrap_len) {
					ctm->wrap_len = strlen(ctm->wrap);
				}
				if(ctm->wrap_len && !ctm->wrap_rex) {
					pcre_t *rex = pcre_create(ctm->wrap, ctm->wrap_len);
					if(!rex) {
						np_error("[%s] rex wrap create failed.\n", rule->name_rule);
						continue;
					}
					ctm->wrap_rex = rex;
				}
			}
			if(ctm->type_match == MHTP_REGEXP) {
				if(!ctm->patt_len) {
					ctm->patt_len = strlen(ctm->patt);
				}
				if(ctm->patt_len && !ctm->rex) {
					pcre_t *rex = pcre_create(ctm->patt, ctm->patt_len);
					if(!rex) {
						np_error("[%s] rex match create failed.\n", rule->name_rule);
						continue;
					}
					ctm->rex = rex;
				}	
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
			if(ctm->type_wrap != MHTP_REGEXP &&
				ctm->type_match != MHTP_REGEXP) 
			{
				continue;
			}
			if(ctm->wrap_rex) {
				np_debug("[%s] destroy rex wrap.\n", rule->name_rule);
				pcre_destroy(ctm->wrap_rex);
				ctm->wrap_rex = NULL;
			}
			if(ctm->rex) {
				np_debug("[%s] destroy rex match.\n", rule->name_rule);
				pcre_destroy(ctm->rex);
				ctm->rex = NULL;
			}
		}
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

static int lnf_match(np_rule_t *rule, len_match_t *lnm, nt_packet_t *npt)
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

static int cont_match(np_rule_t *rule, content_match_t *cont, nt_packet_t *npt)
{
	int start = 0, end = 0, offset = 0, l7dlen;
	uint8_t *l7data, *wrapper;

	l7data = wrapper = npt->l7_ptr;
	l7dlen = npt->l7_len;

	if(cont->spec_len && cont->spec_len != l7dlen) {
		RULE_DBG(rule, NULL, "l7: cont length miss.\n");
		return NP_FALSE;
	}
	if(cont->wrap_len > 0) {
		int wp;
		if(l7dlen < (cont->wrap_begin + cont->wrap_len)) {
			RULE_DBG(rule, NULL, "l7: cont fake wrapper dlen.\n");
			return NP_FALSE;
		}
		start = cont->wrap_begin;
		end = l7dlen;
		if(cont->wrap_end) {
			end = l7dlen > cont->wrap_end ? cont->wrap_end : l7dlen;
		}
		if(start <= end) {
			RULE_DBG(rule, NULL, "l7: cont fake wrapper len.\n");
			return NP_FALSE;
		}
		if(cont->wrap_rex) {
			/* regexp match */
			wp = pcre_find(cont->wrap_rex, l7data, l7dlen);
			if(wp>=0) {
				/* deubg */
				l7data += wp;
				l7dlen -= l7data - wrapper;
				if(l7dlen <= 0) {
					RULE_DBG(rule, NULL, "l7: wrapper - short length.\n");
					return NP_FALSE;
				}
			}
		}
		if(cont->wrap_bmh) {
			/* FIXME: BMH wrapper single string. */
		}
	}

	if(cont->patt_len > 0) {
		int mlen;
		/* fixup & compare offset. */
		offset = cont->offset;
		if(offset < 0) {
			/* revert match. */
			offset += l7dlen;
			if(offset <= 0) {
				RULE_DBG(rule, NULL, "l7: cont offset fixed faild: %d-%d\n", offset, l7dlen);
				return NP_FALSE;
			}
		}
		mlen = l7dlen - offset;
		if(mlen < cont->patt_len) {
			RULE_DBG(rule, NULL, "l7: cont fixed length miss.[%d->%d:%d]\n", l7dlen, offset, cont->patt_len);
			return NP_FALSE;
		}
		switch(cont->type_match) {
			case MHTP_OFFSET: {
				/* fixed match */
				return memcmp(l7data + offset, cont->patt, cont->patt_len) == 0 ? NP_TRUE : NP_FALSE;
			} break;
			case MHTP_REGEXP: {
				int m = 0;
				if(!cont->rex) {
					np_error("l7: cont rex nil.\n");
					return NP_FALSE;
				}
				if(cont->deep && mlen > cont->deep) {
					mlen = cont->deep;
				}
				m = pcre_find(cont->rex, l7data + offset, mlen);
				if(m>=0) {
					RULE_DBG(rule, NULL, "l7: rex match at: %d\n", m);
					return NP_TRUE;
				}
				return NP_FALSE;
			} break;
			case MHTP_SEARCH: {
				if(!cont->bmh) {
					np_error("l7: cont bmh nil.\n");
					return NP_FALSE;
				}
				return NP_TRUE;
			} break;
			case MHTP_HTTP_CTX: {
				return NP_TRUE;
			} break;
			default: {
				np_error("l7: cont not supported type: %d\n", cont->type_match);
				return NP_FALSE;
			} break;
		}
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
	if(lnm->type != NP_LNM_NONE && !lnf_match(rule, lnm, npt)) {
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
	np_rule_t *rule, *last_matched = NULL;
	uint16_t proto = nt_flow_proto(npt->fi);
	np_rule_set_t *hash_set = NULL;
	np_rule_set_t *base_set = &rule_sets_base[npt->dir][np_proto_to_set(npt->l4_proto)];

	rule = rules_set_match(base_set, npt);
	if(rule) {
		last_matched = rule;
		nt_flow_proto_update(npt->fi, rule->ID, NULL);
		np_debug("base match: %s\n", rule->name_rule);
	}

	if(rule && rule->ref_set) {
		rule = rules_set_match(rule->ref_set, npt);
		if(rule) {
			last_matched = rule;
			nt_flow_proto_update(npt->fi, rule->ID, NULL);
			np_debug("inner-ref match: %s\n", rule->name_rule);
		}
	}

	np_assert(proto < NP_RULE_SETS_HASH);
	hash_set = rule_sets_refs[proto % NP_RULE_SETS_HASH];
	if(hash_set) {
		rule = rules_set_match(hash_set, npt);
		if(rule) {
			last_matched = rule;
			nt_flow_proto_update(npt->fi, rule->ID, NULL);
			np_debug("hash-ref match: %s\n", rule->name_rule);
		}
	}

	if(last_matched && RULE_IS_FIN(last_matched)) {
		RULE_DBG(last_matched, NULL, "--- finished flow. --- \n");
		return last_matched->ID;
	}
	return 0;
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
	memset(&rule_sets_base, 0, sizeof(rule_sets_base));
	memset(&rule_sets_refs, 0, sizeof(rule_sets_refs));

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
