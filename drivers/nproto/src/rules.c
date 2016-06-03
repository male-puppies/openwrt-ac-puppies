
#include "mwm.h"
#include "rules.h"

#define NP_MWM_STR "nproto"

/* inner data struct's */
np_rule_set_t rule_sets_base[NP_FLOW_DIR_MAX][NP_SET_BASE_MAX];
np_rule_t *inner_rules[NP_INNER_RULE_MAX];

static LIST_HEAD(all_rules);

static int rule_compile(np_rule_t *rule)
{
	/* init bmh/regexp struct. */
	return 0;
}

static void rule_release(np_rule_t *rule)
{
	/* release the dmalloc mem. */
}

static int set_add_rule_normal_sorted(np_rule_set_t *set, np_rule_t *rule)
{
	if(rule->priority == NP_RULE_PRI_MIN) {
		set->rules[set->num_rules] = *rule;
	} else if(rule->priority == NP_RULE_PRI_MAX) {
		if(set->num_rules > 0)
			memmove(&set->rules[1], set->rules, sizeof(np_rule_t) * set->num_rules);
		set->rules[0] = *rule;
	} else {
		/* find the insert position */
		int L = 0;
		int H = set->num_rules - 1;
		int M, C;
		while(L <= H) {
			M = (L + H) / 2;
			if(set->rules[M].priority == rule->priority) {
				H = M;
				break;
			} else {
				if(set->rules[M].priority < rule->priority) {
					H = M - 1; /* < */
				} else {
					L = M + 1; /* > */
				}
			}
		}
		/* move [H],([H+1]),[H+2]... */
		C = set->num_rules - (H + 1);
		if(C > 0) {
			memmove(&set->rules[H + 2], &set->rules[H + 1], sizeof(np_rule_t) * C);
		}
		set->rules[H + 1] = *rule;
	}
	set->num_rules ++;
	return 0;
}

#define NP_SET_GROW_COUNT 64
static int set_add_rule_normal(np_rule_set_t *set, np_rule_t *rule)
{
	if(set->num_rules >= set->capacity) {
		uint32_t nsize = (set->capacity + NP_SET_GROW_COUNT) * sizeof(np_rule_t);
		np_rule_t *po[] = set->rules;
		np_rule_t *pn[] = (np_rule_t *[])vmalloc(nsize);
		if (!pn) {
			np_error("re-alloc mem failed: %d\n", nsize);
			return -ENOMEM;
		}
		memcpy(pn, po, set->capacity * sizeof(np_rule_t));
		set->rules = pn;
		set->capacity += NP_SET_GROW_COUNT;
		vfree(po);
	}

	return set_add_rule_normal_sorted(set, rule);
}

static int set_add_rule(np_rule_set_t *set, np_rule_t *rule)
{
	int i, n;

	np_assert(set);
	np_assert(rule);

	/* check l7 search && patt len > 4 */
	if(!rule->enalbe_l7) {
		set_add_rule_normal(set, rule);
	}

	for(i=0; i<rule->l7.ctm_num; i++) {
		mwm_t *mwm = rule->pmwm;
		content_match_t *ct = &l7->ctm[i];

		/* search & patt length >= 4 */
		if(!(ct->type == MHTP_SEARCH && ct->patt_len >= 4))
			continue;

		/* init mwm st.. */
		if(!mwm) {
			mwm = mwmNew();
			if(mwm) {
				np_error("create mwm failed.\n");
				return set_add_rule_normal(set, rule);
			}
			rule->pmwm = mwm;
		}
		/* add patters & rule to mwm. */
		n = mwmAddPatternEx(mwm, ct->patt, ct->patt_len, ct->offset, ct->deep, rule);
		if(n<0) {
			np_error("mwm prepare %s error.\n", rule->name_rule, rule->ID);
			return set_add_rule_normal(set, rule);
		} else {
			np_info("mwm add rule[%d:%s] ct[%d]\n", rule->name_rule, rule->ID, i);
		}
	}

	return 0;
}

static int np_rule_register(np_rule_t *rule)
{
	int dir = 0, proto = NP_SET_BASE_OTHER;
	/* compile && check valid */
	if(rule_compile(rule)){
		np_error("compile %d: %s\n", rule->ID, rule->name_rule);
		return -EINVAL;
	}

	/* add to global list. */
	list_add_tail(&rule->list, &all_rules);

	if(!rule->base_rule) {
		return 0;
	}

	/* base rule, to inner set's */
	if (rule->enalbe_l4) {
		l4_match_t *l4 = &rule->l4;
		if(l4->proto == IPPROTO_UDP) {
			proto = NP_SET_BASE_UDP;
		} else if(l4->proto == IPPROTO_TCP) {
			proto = NP_SET_BASE_TCP;
		} else {
			proto = NP_SET_BASE_OTHER;
		}
	}

	if(rule->enalbe_l7) {
		dir = rule->l7.dir;
	}

	/* invalid rule pars. */
	np_assert(dir < NP_FLOW_DIR_MAX);
	np_assert(proto < NP_SET_BASE_MAX);

	np_info("base rule: %s, id: %d\n", rule->name_rule, rule->ID);
	return set_add_rule(&rule_sets_base[dir][proto], rule);
}

static void set_clean(np_rule_set_t *set)
{
	mwmFree(set->pmwm);
}

static int set_init(np_rule_set_t *set)
{
	int ret = mwmPrepPatterns(set->pmwm);
	if(ret < 0) {
		np_error("init mwm - set[%d]\n", i);
		return -EINVAL;
	} else if(ret == 0) {
		mwmFree(set->pmwm);
		set->pmwm = NULL;
	} else {
		mwmGroupDetails(set->pmwm);
	}

	return 0;
}

static void rules_cleanup(void)
{
	int i, j;
	struct list_head *itr;

	/* clean rule set's */
	for(i=0; i<NP_FLOW_DIR_MAX; i++) {
		for(j=0; j<NP_SET_BASE_MAX; j++){
			set_clean(&rule_sets_base[i][j]);
		}
	}
	list_for_each(itr, &all_rules) {
		np_rule_t *rule = list_entry(itr, np_rule_t, list);
	
		/* cleanup refs. */
		rule_release(rule);
		set_clean(&rule->ref_set);
	}
}

static int rules_build(void)
{
	int i, j;
	struct list_head *itr1, *itr2;

	/* build each ref's */
	list_for_each(itr1, &all_rules) {
		np_rule_t *rule1 = list_entry(itr1, np_rule_t, list);
		/* each ref id find the target rule. */
		for(i=0; i<sizeof(rule1->ID_REFs)/sizeof(rule1->ID_REFs[0]); i++) {
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
				if(rule2->ID == ref_id) {
					/* got it */
					set_add_rule(&rule1->ref_set, rule2);
				}
			}
		}
	}

	/* init all set's */
	for(i=0; i<NP_FLOW_DIR_MAX; i++) {
		for(j=0; j<NP_SET_BASE_MAX; j++)
		set_init(&rule_sets_base[i][j]);
	}
	list_for_each(itr1, &all_rules) {
		np_rule_t *rule = list_entry(itr, np_rule_t, list);
		set_init(&rule->ref_set);
	}

__error_exit:
	rules_cleanup();

	return 0;
}

static int inner_rules_init(void)
{
	extern np_rule_t \
		inner_http_req, \
		inner_http_rep, \
		inner_smtp, \
		inner_pop;

	np_rule_register(&inner_http_req);
	np_rule_register(&inner_http_rep);

	return 0;
}

int nproto_init(void)
{
	int ret;

	mwmSysInit(NP_MWM_STR);

	memset(&inner_rules, 0, sizeof(inner_rules));
	memset(&rule_sets_base, 0, sizeof(rule_sets_base));

	ret = inner_rules_init();
	if(ret) {
		np_error("inner rules init failed.\n");
		goto __error;
	}

	ret = rules_build();
	if(ret){
		np_error("rules build.\n");
		goto __error;
	}

	return 0;

__error:
	rules_cleanup();
	return ret;
}

void nproto_cleanup(void)
{
	rules_cleanup();
	mwmSysClean(NP_MWM_STR);
}