#pragma once

#include <nproto/comm.h>
#include <nproto/http.h>
#include <nproto/tencent_qq.h>

#ifdef __KERNEL__
#include <linux/skbuff.h>
#endif

typedef struct {
	/* FIXME: header ... */
	uint16_t dlen;
	uint8_t data[1500];

	/* result of nproto parser */
	unsigned char ntrack_priv[NTRACK_PKT_PRIV_SIZE];
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
static inline nt_pkt_nproto_t *nt_pkt_nproto(struct sk_buff *skb)
{
	STATIC_ASSERT((sizeof(nt_pkt_nproto_t)) < sizeof(skb->ntrack_priv));
	return (nt_pkt_nproto_t*)skb->ntrack_priv;
}
#else
static inline nt_pkt_nproto_t *nt_pkt_nproto(struct nt_packet_t *pkt)
{
	return pkt->ntrack_priv;
}
#endif
