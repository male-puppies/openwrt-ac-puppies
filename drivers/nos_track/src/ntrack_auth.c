#include <linux/module.h>
#include <linux/vmalloc.h>
#include <linux/netfilter.h>
#include <linux/ip.h>

#include <linux/netfilter/xt_set.h>

#include <net/ip.h>
#include <net/netfilter/nf_conntrack.h>

#include <ntrack_auth.h>
#include <ntrack_log.h>


int auth_check_http(struct iphdr *iph, struct sk_buff *skb)
{
	struct tcphdr *tcph;
	char *l4data;
	int l4len;

	if (iph->protocol != IPPROTO_TCP) {
		return 0;
	}

	tcph = (struct tcphdr *)((char*)iph + (iph->ihl << 2));
	l4len = skb->len - (iph->ihl << 2) - (tcph->doff << 2);
	l4data = skb->data + (iph->ihl << 2) + (tcph->doff << 2);

	if((l4len > 3 && !strncasecmp(l4data, "GET", 3)) || 
		(l4len > 4 && !strncasecmp(l4data, "POST", 4))) {
		return 1;
	}

	return 0;
}