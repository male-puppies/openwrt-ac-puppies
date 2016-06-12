#pragma once

#include <ntrack_log.h>

#include <nproto/comm.h>
#include <nproto/http.h>
#include <nproto/tencent_qq.h>

#include <linux/ip.h>
#include <linux/tcp.h>
#include <linux/udp.h>

typedef struct {
	/* ntarck */
	const flow_info_t *fi;
	const user_info_t *ui;
	const user_info_t *pi; /* peer info */
	/* l3/l4 */
	const struct iphdr *iph;
	union {
		const struct tcphdr *tcp;
		const struct udphdr *udp;
		const uint8_t *generic_l4_ptr;	/* is set only for non tcp-udp traffic */
    };
    
	/* upper proto */
	uint8_t l4_proto;
	uint8_t dir: 4, parser_ok: 1; /* dir: C2S, S2C; */
	// uint8_t tcp_retransmission;

	uint16_t l3_len;
	uint16_t l4_len;
	uint16_t l7_len;
	uint8_t *l7_ptr;
	uint64_t timestamps;

	/* userspace this point to ntrack_priv, kernel -> skb->ntrack_priv */
	void *priv; 
#ifndef __KERNEL__
	/* result of nproto parser */
	unsigned char ntrack_priv[NTRACK_PKT_PRIV_SIZE];
#endif

	/* frame data need transmit to others. */
	uint16_t dlen;
	uint8_t data[0]; /* dynamic buffer. */
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

static inline nt_pkt_nproto_t *nt_pkt_nproto(nt_packet_t *pkt)
{
	#ifndef __KERNEL__
	STATIC_ASSERT((sizeof(nt_pkt_nproto_t)) < sizeof(pkt->ntrack_priv));
	#endif
	return (nt_pkt_nproto_t*)pkt->priv;
}

#ifdef __KERNEL__
#include <linux/skbuff.h>
static inline nt_pkt_nproto_t *nt_skb_nproto(struct sk_buff *skb, nt_packet_t *npt)
{
	STATIC_ASSERT((sizeof(nt_pkt_nproto_t)) < sizeof(skb->ntrack_priv));
	if(npt) {
		npt->priv = (void*)&skb->ntrack_priv[0];
	}
	return (nt_pkt_nproto_t*)skb->ntrack_priv;
}
#endif