#pragma once

#ifdef __KERNEL__
#include <linux/ip.h>
#endif

#include <linux/nos_track.h>

/* ########################## */
/* nproto identify in Flow node. */
#include <nproto/comm.h>
#include <nproto/http.h>
#include <nproto/tencent_qq.h>

typedef struct {
	/* 
	** PT_SOCK4, PT_SOCK5, PT_HTTP.
	** PS_UNKNOWN, PS_PORT, PS_ADDR_PORT, PS_FINISH.
	*/
	uint8_t wrap_type:4, wrap_status:4;

	/* 
	** data union of this proto type,
	** example: http, this is the results of line parser.
				QQ, this is the qq number & others.
	*/
	uint8_t du_type;
	union {
		/* HTTP GET/POST header line parser. */
		nproto_http_t http;
		nproto_qq_t qq;
	} du;
} nt_flow_nproto_t;
/* END nproto identify. */

/* ########################## */
/* USER AUTHD in Flow node. */
typedef struct {
	/*
	** auth data stored in flow private area.
	*/
} nt_flow_authd_t;
/* END USER AUTHD */

#define NT_FLOW_CMM_HDR_SIZE sizeof(nt_flow_nproto_t) + sizeof(nt_flow_authd_t)

static inline void nt_flow_update_proto(
	flow_info_t *fi, uint16_t proto, 
	void (*cb)(flow_info_t *, uint16_t))
{
	if(fi->hdr.proto != proto) {
		if(cb){
			cb(fi, proto);
		}
	}
	fi->hdr.proto = proto;
}

static inline void* nt_flow_priv(flow_info_t *fi, int *size)
{
	/* assert size */
	assert(sizeof(fi->private) > (NT_FLOW_CMM_HDR_SIZE));

	*size = sizeof(fi->private) - (NT_FLOW_CMM_HDR_SIZE);
	return (void*)&fi->private[NT_FLOW_CMM_HDR_SIZE];
}

static inline nt_flow_nproto_t* nt_flow_nproto(flow_info_t *fi)
{
	return (nt_flow_nproto_t*)&fi->private[0];
}

static inline nt_flow_authd_t* nt_flow_authd(flow_info_t *fi)
{
	return (nt_flow_authd_t*)&fi->private[sizeof(nt_flow_nproto_t)];
}

enum __em_flow_dir {
	NP_FLOW_DIR_C2S = 0,
	NP_FLOW_DIR_S2C,
	NP_FLOW_DIR_ANY,
	NP_FLOW_DIR_MAX,
};

static inline int nt_flow_dir(flow_tuple_t *tuple, struct iphdr *iph)
{
	int dir = NP_FLOW_DIR_C2S;

	if(__be32_to_cpu(iph->saddr) == tuple->ip_dst) {
		dir = NP_FLOW_DIR_S2C;
	}
	return dir;
}