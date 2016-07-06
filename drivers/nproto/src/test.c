#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/list.h>
#include <linux/skbuff.h>
#include <asm/smp.h>

#include <linux/nos_track.h>
#include <ntrack_comm.h>
#include <ntrack_packet.h>
#include <ntrack_nproto.h>
#include <ntrack_log.h>

extern int nproto_rules_match(nt_packet_t *pkt);

static int nt_init(struct nos_track *nt, struct iphdr *iph, void *l4ptr)
{
	static flow_info_t flow;
	static user_info_t user, peer;

	if(!nt->flow) {
		struct tcphdr *tcp;
		struct udphdr *udp;
		struct nos_flow_tuple *tuple = &flow.tuple;

		nt->flow = &flow;
		memset(&flow, 0, sizeof(flow));
		flow.id = 0xBBEEEEDD;
		tuple->ip_src = __be32_to_cpu(iph->saddr);
		tuple->ip_dst = __be32_to_cpu(iph->daddr);
		tuple->proto = iph->protocol;
		if(iph->protocol == IPPROTO_TCP) {
			tcp = l4ptr;
			tuple->port_src = __be16_to_cpu(tcp->source);
			tuple->port_dst = __be16_to_cpu(tcp->dest);
		} else {
			udp = l4ptr;
			tuple->port_src = __be16_to_cpu(udp->source);
			tuple->port_dst = __be16_to_cpu(udp->dest);
		}

		np_info("reinit flow:"FMT_FLOW_STR"\n", FMT_FLOW(nt->flow));
	}
	if(!nt->ui_src) {
		nt->ui_src = &user;
		user.ip = __be32_to_cpu(iph->saddr);
		user.id = 0xEEDDEEDD;
	}
	if(!nt->ui_dst) {
		nt->ui_dst = &peer;
		peer.ip = __be32_to_cpu(iph->daddr);
		peer.id = 0xAAEEDDBB;
	}
	return 0;
}

static nt_pkt_nproto_t npk_proto;
static int test_pkt_init(const char *data, int dlen, struct nos_track *nt, nt_packet_t *pkt)
{
	int l4len = 0, l7len = 0;
	uint8_t *l4ptr = NULL, *l7ptr = NULL;
	struct iphdr *iph = (struct iphdr*)data;

	/* init the packet parser. */
	pkt->priv = &npk_proto;
	memset(nt_pkt_nproto(pkt), 0, sizeof(nt_pkt_nproto_t));

	/* check skb length > (iphdr+udp/tcp) */
	if(!(iph->version == 4 && iph->ihl >= 5)) {
		np_debug("not ip proto, or length < 20.\n");
		return -EINVAL;
	}

	if((dlen < (iph->ihl * 4)) || 
		(dlen < ntohs(iph->tot_len)) || 
		(ntohs(iph->tot_len) < (iph->ihl * 4)) || 
		((iph->frag_off & htons(0x1FFF)) != 0)) 
	{
		np_debug("frame length error: %d\n", dlen);
		return -EINVAL;
	}

	l4ptr = ((uint8_t *)iph + (iph->ihl * 4));
	l4len = ntohs(iph->tot_len) - (iph->ihl * 4);
	switch(iph->protocol) {
		case IPPROTO_TCP: {
			pkt->tcp = (const struct tcphdr*)l4ptr;
			l7len = l4len - (pkt->tcp->doff * 4);
			l7ptr = l4ptr + (pkt->tcp->doff * 4);
		} break;
		case IPPROTO_UDP: {
			pkt->udp = (const struct udphdr*)l4ptr;
			l7len = l4len - sizeof(struct udphdr);
			l7ptr = l4ptr + sizeof(struct udphdr);
		} break;
		default: {
			/* icmp ... */
			pkt->generic_l4_ptr = l4ptr;
			l7len = l4len;
			l7ptr = l4ptr;
		} break;
	}

	if(l7len<=0) {
		// np_dump(l4ptr, l4len, "dump: %d\n", iph->protocol);
		// np_debug("no l7 payload data. %d\n", l7len);
		return -EINVAL;
	}

	/* data length & ptr's */
	pkt->iph = iph;
	pkt->l3_len = dlen;
	pkt->l4_proto = iph->protocol;
	pkt->l4_len = l4len;

	/* payload */
	pkt->l7_len = l7len;
	pkt->l7_ptr = l7ptr;

	/* test nt inited. */
	nt_init(nt, iph, l4ptr);

	/* ntrack nodes. */
	pkt->fi = nt->flow;
	pkt->ui = nt->ui_src;
	pkt->pi = nt->ui_dst;

	/* C->S, S->C. */
	pkt->dir = nt_flow_dir(&nt->flow->tuple, iph);
	return 0;
}

static struct nos_track ntrack;
static int test_nt_init(void) 
{
	memset(&ntrack, 0, sizeof(ntrack));

	return 0;
}
int test_run_pkt(const char *data, int dlen)
{
	int n;
	nt_packet_t pkt;

	n = test_pkt_init(data, dlen, &ntrack, &pkt);
	if(n) {
		// np_debug("packet init failed: %d\n", n);
		// np_dump(data, dlen, "dump: \n");
		return n;
	}
	if(!nt_flow_nproto_fin(pkt.fi)) {
		n = nproto_rules_match(&pkt);
	}
	return n;
}

/* config netlink sockets */
static struct sock *nl_sock = NULL;
struct {
    __u32 pid;
}user_process;

void test_recv(struct sk_buff *__skb)
{
	struct sk_buff *skb;
	struct nlmsghdr *nlh = NULL;

	skb = skb_get(__skb);

	if(skb->len >= sizeof(struct nlmsghdr)){
        nlh = (struct nlmsghdr *)skb->data;
        if(NLMSG_OK(nlh, __skb->len)) {
        	char *data = (char *)NLMSG_DATA(nlh);
        	int dlen = nlh->nlmsg_len - NLMSG_HDRLEN;
            user_process.pid = nlh->nlmsg_pid;
            // np_debug("pid: %d, dlen=%d\n", user_process.pid, dlen);
            if(dlen<20) {
            	/* io commands */
            	if(strcmp(data, "init") == 0) {
            		test_nt_init();
            	}
            } else {
            	test_run_pkt(data, dlen);
            }
        }
    }

	kfree_skb(skb);
}

int test_init(void)
{
	struct netlink_kernel_cfg cfg = {
		.input	= test_recv,
	};

	test_nt_init();
	nl_sock = netlink_kernel_create(&init_net, NETLINK_NPROTO, &cfg);
	if(!nl_sock) {
		np_error("netlink create failed.\n");
		return -EINVAL;
	}

	return 0;
}

void test_exit(void)
{
	if (nl_sock) {
		netlink_kernel_release(nl_sock);
	}
}
