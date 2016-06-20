#pragma once

#include <linux/ip.h>
#include <linux/nos_track.h>
#include <ntrack_comm.h>
#include <ntrack_log.h>

#define FMT_FLOW_STR "fid: %u-%u [%u.%u.%u.%u:%u -> %u.%u.%u.%u:%u-%u]"
#define FMT_FLOW(fi) \
			(fi)->id, (fi)->magic, \
			HIPQUAD((fi)->tuple.ip_src), (fi)->tuple.port_src, \
			HIPQUAD((fi)->tuple.ip_dst), (fi)->tuple.port_dst, \
			(fi)->tuple.proto
			
/* ########################## */
/* nproto identify in Flow node. */

typedef struct {
	/* 
	** PT_SOCK4, PT_SOCK5, PT_HTTP.
	** PS_UNKNOWN, PS_PORT, PS_ADDR_PORT, PS_FINISH.
	*/
	uint8_t wrap_type:4, wrap_status:4;
	
} nt_flow_nproto_t;
/* END nproto identify. */

/* ########################## */
/* USER AUTHD in Flow node. */
typedef struct {
	/*
	** auth data stored in flow private area.
	*/
	void *p;
} nt_flow_authd_t;
/* END USER AUTHD */

#define NT_FLOW_CMM_HDR_SIZE sizeof(nt_flow_nproto_t) + sizeof(nt_flow_authd_t)

static inline void nt_flow_proto_update(
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

static inline uint16_t nt_flow_proto(const flow_info_t *fi)
{
	return fi->hdr.proto;
}

static inline void* nt_flow_priv(flow_info_t *fi, size_t *size)
{
	/* assert size */
	STATIC_ASSERT(sizeof(fi->private) > (NT_FLOW_CMM_HDR_SIZE));

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
	NP_FLOW_DIR_ANY = 0,
	NP_FLOW_DIR_C2S,
	NP_FLOW_DIR_S2C,
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
