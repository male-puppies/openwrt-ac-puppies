
#include "rules.h"

int inner_rules_init(void)
{
	extern np_rule_t inner_http_req, inner_http_rep;

	np_rule_register(&inner_http_req);
	np_rule_register(&inner_http_rep);

	return 0;
}