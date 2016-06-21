
#include "rules.h"

int inner_rules_init(void)
{
	extern np_rule_t \
	inner_http_req, inner_http_rep, \
	inner_pop3, inner_smtp, \
	inner_ssh, inner_ssl, \
	inner_ftp, inner_dhcp, \
	inner_RDP, inner_SIP, inner_SMB;

	np_rule_register(&inner_http_req);
	np_rule_register(&inner_http_rep);
	np_rule_register(&inner_pop3);
	np_rule_register(&inner_smtp);
	np_rule_register(&inner_ssh);
	np_rule_register(&inner_ssl);
	np_rule_register(&inner_ftp);
	np_rule_register(&inner_dhcp);
	np_rule_register(&inner_SMB);
	np_rule_register(&inner_RDP);
	np_rule_register(&inner_SIP);

	return 0;
}