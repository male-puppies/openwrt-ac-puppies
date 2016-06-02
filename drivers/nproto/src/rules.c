
#include "mwm.h"
#include "rules.h"

/* inner data struct's */
np_rule_set_t rule_sets_base[NP_SET_BASE_MAX];
np_rule_set_t rule_sets_refs[NP_SET_REFs_MAX];
nproto_rule_t *inner_rules[NP_INNER_RULE_MAX];

static int rule_compile(nproto_rule_t *rule)
{
	/* init bmh/regexp struct. */

	/* setup callback's */

	return 0;
}

static int hash_refs(nproto_rule_t *rule)
{
	int i;
	int x = 0;

	for(i=0; i<rule->MAX_REF_IDs; i++) {
		if(!rule->ID_REFs[i]) 
			break;
		x += rule->ID_REFs[i];
	}
	/* error rule. */
	if(x == 0) {
		return -EINVAL;
	}

	return x % NP_SET_REFs_MAX;
}

static int rule_insert(np_rule_set_t *set, nproto_rule_t *rule)
{
	return 0;
}

static int np_rule_register(nproto_rule_t *rule)
{
	/* compile */
	if(rule_compile(rule)){
		np_error("compile %d: %s\n", rule->ID, rule->name_rule);
		return -EINVAL;
	}

	/* insert in-to correct set's */
	if(!rule->base_rule) {
		/* ref other base rule. */
		int idx = hash_refs(rule);
		if(idx < 0 || idx >= NP_SET_REFs_MAX) {
			np_error("not base rule, but ref is nil. %d\n", idx);
			return -EINVAL;
		}
		return rule_insert(&rule_sets_refs[idx], rule);
	}

	/* base rule && http */
	if(rule->enalbe_http) {
		return rule_insert(&rule_sets_base[NP_SET_BASE_HTTP], rule);
	}

	/* base rule, to inner set's */
	if (rule->enalbe_l4) {
		l4_match_t *l4 = &rule->l4;
		if(l4->proto == IPPROTO_UDP) {
			return rule_insert(&rule_sets_base[NP_SET_BASE_UDP], rule);
		} else if(l4->proto == IPPROTO_TCP) {
			return rule_insert(&rule_sets_base[NP_SET_BASE_TCP], rule);
		} else {
			return rule_insert(&rule_sets_base[NP_SET_BASE_OTHER], rule);
		}
	}

	return 0;
}

static int init_inner(void)
{
	extern nproto_rule_t \
		inner_http, \
		inner_smtp, \
		inner_pop;

	np_rule_register(&inner_http);
}

int np_rules_init(void)
{
	memset(&rule_sets_base, 0, sizeof(rule_sets_base));
	memset(&inner_rules, 0, sizeof(inner_rules));

	init_inner();
	return 0;
}

