#include <linux/module.h>
#include <linux/netfilter.h>
#include <linux/ip.h>

#include <net/ip.h>
#include <net/tcp.h>

#include <linux/nos_track.h>
#include <ntrack_log.h>
#include <ntrack_msg.h>
#include <ntrack_auth.h>


int auth_reset(struct sk_buff *oskb, struct net_device *dev)
{
	int len;
	struct sk_buff *nskb;
	struct tcphdr *otcph, *ntcph;
	struct ethhdr *neth, *oeth;
	struct iphdr *niph, *oiph;
	unsigned int csum, header_len;

	oeth = (struct ethhdr *)skb_mac_header(oskb);
	oiph = ip_hdr(oskb);
	otcph = (struct tcphdr *)(skb_network_header(oskb) + (oiph->ihl << 2));

	header_len = sizeof(struct ethhdr) + sizeof(struct iphdr) + sizeof(struct tcphdr);
	nskb = alloc_skb(header_len, GFP_NOWAIT);
	if (!nskb) {
		nt_error("alloc_skb fail\n");
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

	/* iphdr */
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

	/* tcp crc */
	len = ntohs(niph->tot_len) - (niph->ihl<<2);
	csum = csum_partial((char*)ntcph, len, 0);
	ntcph->check = tcp_v4_check(len, niph->saddr, niph->daddr, csum);
	skb_reset_network_header(nskb);

	/* ether header. */
	neth = (struct ethhdr *)skb_push(nskb, sizeof(struct ethhdr));
	memcpy(neth, oeth, sizeof(struct ethhdr));

	/* forward transmit. */
	nskb->dev = dev;
	dev_queue_xmit(nskb);
	return 0;
}

int auth_http(
	const char *url, int urllen, 
	struct sk_buff *oskb, 
	struct net_device *indev) 
{
	struct sk_buff *nskb;
	struct ethhdr *neth, *oeth;
	struct iphdr *niph, *oiph;
	struct tcphdr *otcph, *ntcph;
	int len;
	unsigned int csum, header_len;
	char *data;

	oeth = (struct ethhdr *)skb_mac_header(oskb);
	oiph = ip_hdr(oskb);
	otcph = (struct tcphdr *)(skb_network_header(oskb) + (oiph->ihl<<2));

	header_len = sizeof(struct ethhdr) + sizeof(struct iphdr) + sizeof(struct tcphdr);
	nskb = alloc_skb(header_len + urllen, GFP_NOWAIT);
	if (!nskb) {
		nt_error("alloc_skb fail\n");
		return -ENOMEM;
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

	/* iphdr */
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

	/* tcp crc */
	len = ntohs(niph->tot_len) - (niph->ihl<<2);
	csum = csum_partial((char*)ntcph, len, 0);
	ntcph->check = tcp_v4_check(len, niph->saddr, niph->daddr, csum);
	skb_reset_network_header(nskb);

	/* ether hdr */
	neth = (struct ethhdr *)skb_push(nskb, sizeof(struct ethhdr));
	memcpy(neth->h_dest, oeth->h_source, 6);
	memcpy(neth->h_source, oeth->h_dest, 6);
	neth->h_proto = htons(ETH_P_IP);
	skb_reset_mac_header(nskb);

	// nt_debug("redirect: %s\n", indev->name);

	/* redirect transmit. */
	nskb->dev = indev;
	dev_queue_xmit(nskb);
	return 0;
}

#define URL_STR_FMT "http://1.0.0.8/webauth.cgi?ip=%s&mac=%s&in=%s&uid=%s&magic=%s"

const char http_redir_fmt[] = "HTTP/1.1 302 Moved Temporarily\r\n"\
	"Location: "URL_STR_FMT"\r\n"\
	"Content-Type: text/html;\r\n"\
	"Connection: close\r\n"\
	"Cache-Control: no-cache\r\n\r\n"\
	"<html><meta http-equiv=\"refresh\" content=\"0;url="URL_STR_FMT"\"></html>";

const int redirect_len = sizeof(http_redir_fmt) + \
	(2 * IFNAMSIZ) + \
	(2 * sizeof("255.255.255.255")) + \
	(2 * sizeof("00:01:02:03:04:05")) + \
	(2 * sizeof("4294967295")) + \
	(2 * sizeof("4294967295")); //eth + ip + mac + 4 * (uint32-string)

/* 
* 构造一个URL重定向包, 从in接口发出去 
* @return 0, success, or -ERROR-NO.
*/
int ntrack_redirect(struct nos_user_info *ui, 
			struct sk_buff *skb,
			struct net_device *in,
			struct net_device *out)
{
	int ret = 0;
	char *url;
	int len;
	char str_ip4[] = "255.255.255.255";
	char str_mac[] = "aa:bb:cc:dd:ee:ff";
	char str_id[16], str_magic[16];
	struct ethhdr *eth = (struct ethhdr*)skb_mac_header(skb);

	if(!in) {
		nt_error("in dev not nil.!!!\n");
		return -EINVAL;
	}

	url = kmalloc(redirect_len, GFP_NOWAIT);
	if(!url) {
		nt_error("kmalloc failed.\n");
		ret = -ENOMEM;
		goto __finished;
	}

	snprintf(str_ip4, sizeof(str_ip4), "%u.%u.%u.%u", HIPQUAD(ui->ip));
	snprintf(str_id, sizeof(str_id), "%u", ui->id);
	snprintf(str_magic, sizeof(str_magic), "%u", ui->magic);
	if(eth) {
		snprintf(str_mac, sizeof(str_mac), FMT_MAC_STR, FMT_MAC(eth->h_source));
	}
	len = snprintf(url, redirect_len, http_redir_fmt, 
		str_ip4, str_mac, in->name, str_id, str_magic,
		str_ip4, str_mac, in->name, str_id, str_magic);

	nt_assert(len > 0 && len <= redirect_len);
	nt_debug("send redirect http[%d] length: %d\n", redirect_len, len);
	
	if(auth_http(url, len, skb, in)) {
		nt_error("error send redirect url.\n");
		ret = -EINVAL;
		goto __finished;
	}

	/* 构造一个reset包, 从out接口发出去 */
	if (out)
		auth_reset(skb, out);

__finished:
	if(url) {
		kfree(url);
	}
	return ret;
}