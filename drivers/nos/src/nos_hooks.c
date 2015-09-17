#include "nos.h"
#include "nos_debug.h"
#include <net/ip.h>
#define DRV_VERSION	"0.1.1"
#define DRV_DESC	"nos package mangle & auth driver"

struct nos_global g_nos;

void print_macxx(const unsigned char *mac) {
	loginfo("%02x:%02x:%02x:%02x:%02x:%02x\n", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}

static inline unsigned char *mac_source(struct sk_buff *skb) {
	return ((struct ethhdr *)skb_mac_header(skb))->h_source;
}

typedef struct pse_hdr_st {
	unsigned int saddr, daddr;
	unsigned char mbz, proto;
	unsigned short len;
} pse_hdr_st;

unsigned short tcp_v4_check(int len, unsigned int saddr,
		unsigned int daddr, unsigned int base)
{
	struct pse_hdr_st psd;

	psd.saddr = saddr;
	psd.daddr = daddr;
	psd.mbz = 0;
	psd.proto = IPPROTO_TCP;
	psd.len = htons(len);

	return csum_fold(csum_partial(&psd, sizeof(psd), base));
}
static int auth_reset(struct sk_buff *skb, const struct net_device *dev)
{
	int len;
	struct sk_buff *nskb;
	struct tcphdr *otcph, *ntcph;
	struct ethhdr *neth, *oeth;
	struct iphdr *niph, *oiph;
	unsigned int csum, header_len; 

	oeth = (struct ethhdr *)skb_mac_header(skb);
	oiph = ip_hdr(skb);
	otcph = (struct tcphdr *)(skb_network_header(skb) + (oiph->ihl << 2));

	header_len = sizeof(struct ethhdr) + sizeof(struct iphdr) + sizeof(struct tcphdr);
	nskb = alloc_skb(header_len, GFP_KERNEL);
	if (!nskb) {
		logerr("alloc_skb fail\n");
		return -1;
	}
	
	skb_reserve(nskb, header_len);
	ntcph = (struct tcphdr *)skb_push(nskb, sizeof(struct tcphdr));
	memset(ntcph, 0, sizeof(struct tcphdr));
	ntcph->source = otcph->source;
	ntcph->dest = otcph->dest;
	ntcph->seq = otcph->seq;
	ntcph->ack_seq = otcph->ack_seq;
	ntcph->doff = sizeof(struct tcphdr) / 4;
	((u_int8_t *)ntcph)[13] = 0;
	ntcph->rst = 1; 
	ntcph->ack = otcph->ack; 
	ntcph->window = htons(0);
	
	niph = (struct iphdr *)skb_push(nskb, sizeof(struct iphdr)); 
	memset(niph, 0, sizeof(struct iphdr));
	niph->saddr = oiph->saddr;
	niph->daddr = oiph->daddr; 
	niph->version = oiph->version;
	niph->ihl = 5;
	niph->tos = 0;
	niph->tot_len = htons(sizeof(struct iphdr) + sizeof(struct tcphdr));
	niph->ttl = 0x80;
	niph->protocol = oiph->protocol;
	niph->id = 0; 
	niph->frag_off = 0x0040;
	ip_send_check(niph);
	
	len = ntohs(niph->tot_len) - (niph->ihl<<2);
	csum = csum_partial((char*)ntcph, len, 0);
	ntcph->check = tcp_v4_check(len, niph->saddr, niph->daddr, csum);
	
	neth = (struct ethhdr *)skb_push(nskb, sizeof(struct ethhdr)); 
	memcpy(neth, oeth, sizeof(struct ethhdr)); 
	
	nskb->dev = (struct net_device *)dev;
	dev_queue_xmit(nskb);
	return 0;
}

static int auth_URL(const char *url, int urllen, struct sk_buff *skb, const struct net_device *dev) {
	struct sk_buff *nskb;
	struct ethhdr *neth, *oeth;
	struct iphdr *niph, *oiph;
	struct tcphdr *otcph, *ntcph;
	int len;
	unsigned int csum, header_len; 
	char *data;

	oeth = (struct ethhdr *)skb_mac_header(skb);
	oiph = ip_hdr(skb);
	otcph = (struct tcphdr *)(skb_network_header(skb) + (oiph->ihl<<2));

	header_len = sizeof(struct ethhdr) + sizeof(struct iphdr) + sizeof(struct tcphdr);
	nskb = alloc_skb(header_len + urllen, GFP_KERNEL);
	if (!nskb) {
		logerr("alloc_skb fail\n");
		return -1;
	}

	skb_reserve(nskb, header_len); 

	data = (char *)skb_put(nskb, urllen);
	memcpy(data, url, urllen);
	
	ntcph = (struct tcphdr *)skb_push(nskb, sizeof(struct tcphdr)); 
	memset(ntcph, 0, sizeof(struct tcphdr));
	ntcph->source = otcph->dest;
	ntcph->dest = otcph->source;
	ntcph->seq = otcph->ack_seq;
	ntcph->ack_seq = htonl(ntohl(otcph->seq) + ntohs(oiph->tot_len) - (oiph->ihl<<2) - (otcph->doff<<2));
	ntcph->doff = 5;
	ntcph->ack = 1;
	ntcph->psh = 1;
	ntcph->fin = 1;
	ntcph->window = 65535;
	
	niph = (struct iphdr *)skb_push(nskb, sizeof(struct iphdr)); 
	memset(niph, 0, sizeof(struct iphdr));
	niph->saddr = oiph->daddr;
	niph->daddr = oiph->saddr; 
	niph->version = oiph->version;
	niph->ihl = 5;
	niph->tos = 0;
	niph->tot_len = htons(sizeof(struct iphdr) + sizeof(struct tcphdr) + urllen);
	niph->ttl = 0x80;
	niph->protocol = oiph->protocol;
	niph->id = 0x2658; 
	niph->frag_off = 0x0040;
	ip_send_check(niph);
	
	len = ntohs(niph->tot_len) - (niph->ihl<<2);
	csum = csum_partial((char*)ntcph, len, 0);
	ntcph->check = tcp_v4_check(len, niph->saddr, niph->daddr, csum);

	neth = (struct ethhdr *)skb_push(nskb, sizeof(struct ethhdr));  
	memcpy(neth->h_dest, oeth->h_source, 6);
	memcpy(neth->h_source, oeth->h_dest, 6);
	neth->h_proto = htons(ETH_P_IP);  
	nskb->dev = (struct net_device *)dev;
	dev_queue_xmit(nskb);
	return 0; 
}
/*
iptables -t nat -A PREROUTING -p tcp -d 10.10.10.10 --dport 80 -j DNAT --to 192.168.1.1:8080
*/

#define URLFMT "HTTP/1.1 302 Moved Temporarily\r\nLocation: http://10.10.10.10/index.html?mac=%02x:%02x:%02x:%02x:%02x:%02x&ip=%u.%u.%u.%u\r\nContent-Type: text/html;\r\nCache-Control: no-cache\r\nContent-Length: 0\r\n\r\n"
#define URLFMT_SIZE (sizeof(URLFMT) + sizeof("00:00:00:00:00:00") + sizeof("255.255.255.255") + 1)
static int auth_redirect(const char *url, int urllen, struct sk_buff *skb,
					const struct net_device *in,
					const struct net_device *out)
{
	/* 构造一个URL重定向包, 从in接口发出去 */
	if(auth_URL(url, urllen, skb, in)){
		logerr("error send redirect url.\n");
		return -1;
	}
	
	/* 构造一个reset包, 从out接口发出去 */
	if (out)
		auth_reset(skb, out);
	return 0;
}

static unsigned int nos_do(struct nos_track* nos, struct sk_buff* skb, const struct net_device *in,	const struct net_device *out)
{
	int paylen, ret;
	unsigned char *mac, *payload;
	struct user_node *user; 
	struct iphdr *iph;
	struct tcphdr *tcph;
	struct udphdr *udph;

	if (!check_dir(in->name, out->name)) {
		return NF_ACCEPT;
	}

	mac = mac_source(skb); 	BUG_ON(!mac);
	iph = (struct iphdr *)skb->data; 
	user = user_hash_find(mac);
	if (user) {
		user->jf = jiffies;
		user->ip = iph->saddr;
		if (user->status == 1) {
			loginfo("online\n");
			print_macxx(mac);
			return NF_ACCEPT;
		}
	} else {
		struct user_node *n = kmalloc(sizeof(struct user_node), GFP_ATOMIC); 	BUG_ON(!n);
		memset(n, 0, sizeof(struct user_node));
		n->jf = jiffies;
		n->ip = iph->saddr;
		memcpy(n->mac, mac, ETH_ALEN);
		ret = user_hash_add(n); 		BUG_ON(ret != 1);
		loginfo("new n %d ", ret); 
		print_macxx(mac);
	}
	
	if (iph->protocol == IPPROTO_UDP) {
		udph = (struct udphdr *)(skb->data + (iph->ihl << 2));
		if (ntohs(udph->dest) == 53) {
			return NF_ACCEPT;
		}
		return NF_DROP;
	}

	tcph = (struct tcphdr *)(skb->data + (iph->ihl << 2));
	if (tcph->syn || tcph->fin || tcph->rst) { 
 		return NF_ACCEPT;
	}

	paylen = skb->len - (iph->ihl << 2) + (tcph->doff << 2);
	payload = skb->data + (iph->ihl << 2) + (tcph->doff << 2);
	if (paylen <= 0 || strncasecmp(payload, "GET", 3))
		return NF_DROP; 
	
	{
	char buff[URLFMT_SIZE];
	ret = snprintf(buff, sizeof(buff), URLFMT, mac[0], mac[1], mac[2], mac[3], mac[4], mac[5], NIPQUAD(iph->saddr));
	buff[ret] = 0;
	loginfo("%s", buff);
	auth_redirect(buff, ret, skb, in, out); 
	}
	return NF_DROP;
}

static unsigned int nos_hook_fw(const struct nf_hook_ops *ops, 
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out, 
		int (*okfn)(struct sk_buff *))
{
	unsigned int res = NF_ACCEPT;
	
	struct nf_conn *ct;
	struct iphdr *iph;
	struct sk_buff *linear_skb = NULL, *use_skb = NULL;
	enum ip_conntrack_info ctinfo;

	struct nos_track* nos;

	ct = nf_ct_get(skb, &ctinfo);
	if (!ct) {
		NOS_DBG("null ct.\n");
		return NF_ACCEPT;
	}

	if(nf_ct_is_untracked(ct)) {
		NOS_DBG("--------------- untracked ct.\n");
		return NF_ACCEPT;
	}

	//TCP, UDP, ICMP, supported.
	iph = ip_hdr(skb);
	if ((iph->protocol != IPPROTO_TCP) 
		&& (iph->protocol != IPPROTO_UDP) 
		&& (iph->protocol != IPPROTO_ICMP)) {
		return NF_ACCEPT;
	}

	//loopback, lbcast filter.
	if (ipv4_is_lbcast(iph->saddr) || 
		ipv4_is_lbcast(iph->daddr) ||
			ipv4_is_loopback(iph->saddr) || 
			ipv4_is_loopback(iph->daddr) ||
			ipv4_is_multicast(iph->saddr) ||
			ipv4_is_multicast(iph->daddr) || 
			ipv4_is_zeronet(iph->saddr) ||
			ipv4_is_zeronet(iph->daddr))
	{
		return NF_ACCEPT;
	}

	//这里如果不线性化检查, OUTPUT抓取的数据包, 数据区可能为空.
	if(skb_is_nonlinear(skb)) {
		linear_skb = skb_copy(skb, GFP_ATOMIC);
		if (linear_skb == NULL) {
			NOS_DBG("skb cpy linear failed.\n");
			return NF_ACCEPT;
		}
		use_skb = linear_skb;
	} else {
		use_skb = skb;
	}

	nos = nos_track_get(ct);
	if (!nos) {
		//模块调试, 插入时该连接已经无法跟踪了.
		NOS_DBG("flow track node not found.");
		goto __failed_out;
	}

	/* 存取flow & user & peer 节点 */
	res = nos_do(nos, use_skb, in, out);

__failed_out:
	if(linear_skb) {
		kfree_skb(linear_skb);
	}

	return res;
}

static struct nf_hook_ops nos_nf_hook_ops[] = {
	{
		.hook = nos_hook_fw,
		.owner = THIS_MODULE,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_FORWARD,
		.priority = NF_IP_PRI_LAST,
	},
};

static int __init nos_module_init(void)
{
	int ret = 0;
	nos_global_init();
	ret = nos_sysfs_register();
	if (ret != 0) {
		goto cleanup_global;
	}
	ret = nf_register_hooks(nos_nf_hook_ops, ARRAY_SIZE(nos_nf_hook_ops));
	if (ret != 0) {
		logerr("nf_register_hook failed: %d\n", ret);
		goto unregister_sysfs;
	}
	loginfo("nos_init() OK +\n");
	return 0;

unregister_sysfs:
	nos_sysfs_unregister();
cleanup_global:
	nos_global_cleanup();
	return ret;
}

static void __exit nos_module_fini(void)
{
	nos_sysfs_unregister();
	nf_unregister_hooks(nos_nf_hook_ops, ARRAY_SIZE(nos_nf_hook_ops));
	nos_global_cleanup();
	loginfo("nos_fini() OK\n");
}

module_init(nos_module_init);
module_exit(nos_module_fini);

MODULE_DESCRIPTION(DRV_DESC);
MODULE_VERSION(DRV_VERSION);
MODULE_AUTHOR("Gabor Juhos <juhosg@openwrt.org>");
MODULE_LICENSE("GPL v2");
