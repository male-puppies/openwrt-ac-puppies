#pragma once

#include <linux/ip.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <linux/nos_track.h>

#include <ntrack_log.h>
#include <nproto/comm.h>
#include <nproto/http.h>
#include <nproto/tencent_qq.h>

#define FMT_PKT_STR "FID:%4u %u.%u.%u.%u:%u -> %u.%u.%u.%u:%u,len:%d"
#ifdef __KERNEL__
#define FMT_PKT(p) 	((p)->fi->id), \
					NIPQUAD((p)->iph->saddr), \
			((p)->l4_proto == IPPROTO_TCP?ntohs((p)->tcp->source):ntohs((p)->udp->source)), \
					NIPQUAD((p)->iph->daddr), \
			((p)->l4_proto == IPPROTO_TCP?ntohs((p)->tcp->dest):ntohs((p)->udp->dest)), \
			((p)->l7_len)
#else 
		/* FIXME: xxx */
		//FMT_PKT(p) (...)
#endif

typedef struct {
#ifdef __KERNEL__
	/* ntarck */
	flow_info_t *fi;
	user_info_t *ui;
	user_info_t *pi; /* peer info */
#else
	uint32_t fid, fmagic;
#endif

	/* l3/l4 */
	const struct iphdr *iph;
	union {
		const struct tcphdr *tcp;
		const struct udphdr *udp;
		const uint8_t *generic_l4_ptr;	/* is set only for non tcp-udp traffic */
    };
    
	/* upper proto */
	uint8_t l4_proto;
	uint8_t dir: 4; /* dir: C2S, S2C; */
	// uint8_t tcp_retransmission;

	int16_t l3_len;
	int16_t l4_len;
	int16_t l7_len;
	uint8_t *l7_ptr;
	uint64_t timestamps;

#ifdef __KERNEL__
	/* userspace this point to ntrack_priv, kernel -> skb->ntrack_priv */
	void *priv; 
#else
	/* result of nproto parser */
	unsigned char ntrack_priv[NTRACK_PKT_PRIV_SIZE];
#endif
} nt_packet_t;


typedef struct {
	/* 
	** data union of this proto type,
	** example: http, this is the results of line parser.
				qq, this is the qq number & others.
	*/
	uint8_t du_type;
	union {
		/* HTTP GET/POST header line parser. */
		nproto_http_t http;
		nproto_qq_t qq;
	} du;
} nt_pkt_nproto_t;

#ifdef __KERNEL__
#include <linux/skbuff.h>
#include <linux/types.h>
#include <linux/if.h>

/*
	skb->ntrack_priv[] layout: [tbq_packet_ctrl|nt_pkt_nproto_t]
*/
#define NOS_QOS_LINE_MAX    (8)
struct tbq_packet_ctrl {
	struct tbq_bucket_sched *bucket_sched;
	struct tbq_user_sched *user_sched;
	uint32_t rule_mask;
	uint32_t pkt_len;
};

#define TBQ_PACKET_CTL_OFFSET 0
static inline struct tbq_packet_ctrl *tbq_packet_ctrl_get(struct sk_buff *skb)
{
	return (struct tbq_packet_ctrl *)&skb->ntrack_priv[TBQ_PACKET_CTL_OFFSET];
}

#define NT_PKT_NPROTO_OFFSET (sizeof(struct tbq_packet_ctrl))
static inline nt_pkt_nproto_t *nt_skb_nproto(struct sk_buff *skb, nt_packet_t *npt)
{
	STATIC_ASSERT((NT_PKT_NPROTO_OFFSET + sizeof(nt_pkt_nproto_t)) < sizeof(skb->ntrack_priv));
	if(npt) {
		npt->priv = (void*)&skb->ntrack_priv[NT_PKT_NPROTO_OFFSET];
	}
	return (nt_pkt_nproto_t*)&skb->ntrack_priv[NT_PKT_NPROTO_OFFSET];
}

static inline nt_pkt_nproto_t *nt_pkt_nproto(nt_packet_t *pkt)
{
	return (nt_pkt_nproto_t*)pkt->priv;
}
#endif /* __KERNEL__ */

/* http packet parse APIs. */
static inline char *np_http_hdr(nt_packet_t* pkt, int em_hdr, int *len)
{
	int16_t offset, end;
	nt_pkt_nproto_t *np = nt_pkt_nproto(pkt);
	nproto_http_t *http = &np->du.http;

	/* do not fetch NP_HTTP_END use api, 
	*	as l7 ptr & length is fixed 
	*	by the http-base rule's callback. 
	*/
	if(em_hdr <= 0 || em_hdr >= NP_HTTP_MAX) {
		return NULL;
	}

	offset = http->headers_range[em_hdr][0];
	end = http->headers_range[em_hdr][1];
	if(end - offset <= 0) {
		return NULL;
	}

	*len = end - offset;
	return &pkt->l7_ptr[offset];
}
