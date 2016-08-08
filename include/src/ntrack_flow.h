#pragma once

#include <linux/ip.h>
#include <linux/nos_track.h>
#include <ntrack_comm.h>
#include <ntrack_log.h>

#define FMT_FLOW_STR "fid: %u-%u [%u.%u.%u.%u:%u -> %u.%u.%u.%u:%u-%u]"
#define FMT_FLOW(fi) \
			(fi)->id, (fi)->magic, \
			NIPQUAD((fi)->tuple.ip_src), ntohs((fi)->tuple.port_src), \
			NIPQUAD((fi)->tuple.ip_dst), ntohs((fi)->tuple.port_dst), \
			(fi)->tuple.proto

/* -------------------------- */
enum em_flow_flags {
	/* byte: normal flags. */
	FG_FLOW_NPROTO_FIN		= 1<<0, /* identify finished. */
	FG_FLOW_NPROTO_BEHIVOR	= 1<<1, /* behivor identify need. */
	FG_FLOW_TRACE			= 1<<2, /* recored url/content need. */
	/* next byte: drop flags. */
	FG_FLOW_DROP_AUTH		= 1<<8, /* droped by auth not successued */
	FG_FLOW_DROP_L4_FW		= 1<<9, /* droped by layer 4 firewall. */
	FG_FLOW_DROP_L7_FW		= 1<<10, /* droped by layer 7 firewall, such as user ACL rules. */
	FG_FLOW_DROP_CTX_FILTER	= 1<<11, /* droped by content filter, eg: keywords filter... */
};

static inline int nt_flow_nproto_fin(const flow_info_t *fi)
{
	return fi->hdr.flags & FG_FLOW_NPROTO_FIN;
}

static inline void nt_flow_nproto_fin_set(flow_info_t *fi)
{
	fi->hdr.flags |= FG_FLOW_NPROTO_FIN;
}

static inline int nt_flow_track(const flow_info_t *fi) 
{
	return fi->hdr.flags & FG_FLOW_TRACE;
}

static inline void nt_flow_track_set(flow_info_t *fi)
{
	fi->hdr.flags |= FG_FLOW_TRACE;
}

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

void nt_flow_nproto_update(flow_info_t *fi, uint16_t proto_new);

static inline uint16_t nt_flow_nproto(const flow_info_t *fi)
{
	return fi->hdr.proto;
}

static inline nt_flow_nproto_t* nt_flow_priv_nproto(flow_info_t *fi)
{
	return (nt_flow_nproto_t*)&fi->private[0];
}

static inline nt_flow_authd_t* nt_flow_priv_authd(flow_info_t *fi)
{
	return (nt_flow_authd_t*)&fi->private[sizeof(nt_flow_nproto_t)];
}

#define NT_FLOW_CMM_HDR_SIZE sizeof(nt_flow_nproto_t) + sizeof(nt_flow_authd_t)
static inline void* nt_flow_priv_data(flow_info_t *fi, size_t *size)
{
	/* assert size */
	STATIC_ASSERT(sizeof(fi->private) > (NT_FLOW_CMM_HDR_SIZE));

	*size = sizeof(fi->private) - (NT_FLOW_CMM_HDR_SIZE);
	return (void*)&fi->private[NT_FLOW_CMM_HDR_SIZE];
}

enum __em_flow_dir {
	NP_FLOW_DIR_ANY = 0,
	NP_FLOW_DIR_C2S,
	NP_FLOW_DIR_S2C,
	NP_FLOW_DIR_MAX,
};
#define SET_DIR_STR(idx) flow_dir_name[idx]

static inline int nt_flow_dir(flow_tuple_t *tuple, struct iphdr *iph)
{
	int dir = NP_FLOW_DIR_C2S;

	if(__be32_to_cpu(iph->saddr) == tuple->ip_dst) {
		dir = NP_FLOW_DIR_S2C;
	}
	return dir;
}
