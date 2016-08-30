#pragma once

#include <linux/ip.h>
#include <linux/nos_track.h>
#include <ntrack_comm.h>
#include <ntrack_log.h>

#define FMT_FLOW_STR "fid: %u-%u [%u.%u.%u.%u:%u -> %u.%u.%u.%u:%u-%u:%08x]"
#define FMT_FLOW(fi) \
			(fi)->id, (fi)->magic, \
			NIPQUAD((fi)->tuple.ip_src), ntohs((fi)->tuple.port_src), \
			NIPQUAD((fi)->tuple.ip_dst), ntohs((fi)->tuple.port_dst), \
			(fi)->tuple.proto, (fi)->hdr.flags

static inline uint32_t flow_srcip(flow_info_t *fi)
{
	return fi->tuple.ip_src;
}

static inline uint32_t flow_dstip(flow_info_t *fi)
{
	return fi->tuple.ip_dst;
}

static inline uint16_t flow_sport(flow_info_t *fi)
{
	return fi->tuple.port_src;
}

static inline uint16_t flow_dport(flow_info_t *fi)
{
	return fi->tuple.port_dst;
}

/* -------------------------- */
#define FLOW_STAT_SHIFT		(0)
#define FLOW_STAT_MASK		(0x000000FFU << FLOW_STAT_SHIFT)
#define FLOW_DROP_SHIFT 	(8)
#define FLOW_DROP_MASK 		(0x000000FFU << FLOW_DROP_SHIFT)
#define FLOW_ACCEPT_SHIFT	(16)
#define FLOW_ACCEPT_MASK 	(0x000000FFU << FLOW_ACCEPT_SHIFT)
enum em_flow_flags {
	/* byte: normal flags. */
	FG_FLOW_NPROTO_FIN		= 1<<(FLOW_STAT_SHIFT + 0), /* identify finished. */
	FG_FLOW_NPROTO_BEHIVOR	= 1<<(FLOW_STAT_SHIFT + 1), /* behivor identify need. */
	FG_FLOW_TRACE			= 1<<(FLOW_STAT_SHIFT + 2), /* recored url/content need. */
	FG_FLOW_AUDIT			= 1<<(FLOW_STAT_SHIFT + 3), /* audit need. */
	FG_FLOW_AUDIT_FIN		= 1<<(FLOW_STAT_SHIFT + 4), /* do audit table finished . */
	FG_FLOW_CONTROL_FIN		= 1<<(FLOW_STAT_SHIFT + 5), /* do control table finished. */
	/* next byte: drop flags. */
	FG_FLOW_DROP_AUTH		= 1<<(FLOW_DROP_SHIFT + 0), /* droped by auth not successued */
	FG_FLOW_DROP_L4_FW		= 1<<(FLOW_DROP_SHIFT + 1), /* droped by layer 4 firewall, such as blacklist. */
	FG_FLOW_DROP_L7_FW		= 1<<(FLOW_DROP_SHIFT + 2), /* droped by layer 7 firewall, such as user ACL rules. */
	FG_FLOW_DROP_CTX_FILTER	= 1<<(FLOW_DROP_SHIFT + 3), /* droped by content filter, eg: keywords filter... */
	/* next byte: accept flags. */
	FG_FLOW_ACCEPT_L4_FW	= 1<<(FLOW_ACCEPT_SHIFT + 0), /* accepted by layer 4 firewall, such as whitelist*/
	FG_FLOW_ACCEPT_L7_FW	= 1<<(FLOW_ACCEPT_SHIFT + 1), /* accepted by layer 7 firewall, such as user ACL rules. */
};

static inline uint32_t nt_flow_flags(const flow_info_t *fi)
{
	return fi->hdr.flags;
}

/* just for test, do not use this api directly !!!
** use api spec target: nproto_fin, track, ...  */
static inline void nt_flow_flags_set(flow_info_t *fi, uint32_t flags)
{
	fi->hdr.flags = flags;
}

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

static inline int nt_flow_audited(const flow_info_t *fi)
{
	return fi->hdr.flags & FG_FLOW_AUDIT;
}

static inline void nt_flow_audit_set(flow_info_t *fi)
{
	fi->hdr.flags |= FG_FLOW_AUDIT;
}

static inline void nt_flow_audit_clr(flow_info_t *fi)
{
	fi->hdr.flags &= ~FG_FLOW_AUDIT;
}

static inline int nt_flow_audit_fin(const flow_info_t *fi)
{
	return fi->hdr.flags & FG_FLOW_AUDIT_FIN;
}

static inline void nt_flow_audit_fin_set(flow_info_t *fi)
{
	fi->hdr.flags |= FG_FLOW_AUDIT_FIN;
}

static inline void nt_flow_audit_fin_clr(flow_info_t *fi)
{
	fi->hdr.flags &= ~FG_FLOW_AUDIT_FIN;
}

static inline int nt_flow_control_fin(const flow_info_t *fi)
{
	return fi->hdr.flags & FG_FLOW_CONTROL_FIN;
}

static inline void nt_flow_control_fin_set(flow_info_t *fi)
{
	fi->hdr.flags |= FG_FLOW_CONTROL_FIN;
}

static inline void nt_flow_control_fin_clr(flow_info_t *fi)
{
	fi->hdr.flags &= ~FG_FLOW_CONTROL_FIN;
}

static inline void nt_flow_drop_set(flow_info_t *fi, uint32_t drop)
{
	fi->hdr.flags |= FLOW_DROP_MASK & drop;
}

static inline void nt_flow_drop_clr(flow_info_t *fi, uint32_t drop)
{
	fi->hdr.flags &= ~(FLOW_DROP_MASK & drop);
}

static inline int nt_flow_droped(flow_info_t *fi)
{
	return fi->hdr.flags & FLOW_DROP_MASK;
}

static inline void nt_flow_accept_set(flow_info_t *fi, uint32_t drop)
{
	fi->hdr.flags |= FLOW_ACCEPT_MASK & drop;
}

static inline void nt_flow_accept_clr(flow_info_t *fi, uint32_t drop)
{
	fi->hdr.flags &= ~(FLOW_ACCEPT_MASK & drop);
}

static inline int nt_flow_accepted(flow_info_t *fi)
{
	return fi->hdr.flags & FLOW_ACCEPT_MASK;
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

/* ########################## */
/* NACS in Flow node. */
typedef struct {
	/*
	** NACS stored in flow private area.
	*/
	uint32_t magic;	/* version of nacs config */
}nt_flow_nacs_t;
/* split into module's private */
#define NT_FLOW_OFF_NPROTO 		0
#define NT_FLOW_OFF_AUTHD 		sizeof(nt_flow_nproto_t)
#define NT_FLOW_OFF_NACS 		sizeof(nt_flow_nproto_t) + sizeof(nt_flow_nacs_t)
/* total defined struct size */
#define NT_FLOW_CMM_HDR_SIZE sizeof(nt_flow_nproto_t) \
			+ sizeof(nt_flow_authd_t) \
			+ sizeof(nt_flow_nacs_t)
/* END NACS */

static inline uint16_t nt_flow_nproto(const flow_info_t *fi)
{
	return fi->hdr.proto;
}

static inline nt_flow_nproto_t* nt_flow_priv_nproto(flow_info_t *fi)
{
	return (nt_flow_nproto_t*)&fi->private[NT_FLOW_OFF_NPROTO];
}

static inline nt_flow_authd_t* nt_flow_priv_authd(flow_info_t *fi)
{
	return (nt_flow_authd_t*)&fi->private[NT_FLOW_OFF_AUTHD];
}

static inline nt_flow_nacs_t* nt_flow_priv_nacs(flow_info_t *fi)
{
	return (nt_flow_nacs_t*)&fi->private[NT_FLOW_OFF_NACS];
}

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

enum  __em_user_dir {
	NP_USER_XMIT = 0,
	NP_USER_RECV,
};

static inline int16_t nt_flow_dir(flow_tuple_t *tuple, struct iphdr *iph)
{
	int16_t dir = NP_FLOW_DIR_C2S;

	if(__be32_to_cpu(iph->saddr) == tuple->ip_dst) {
		dir = NP_FLOW_DIR_S2C;
	}
	return dir;
}
#define FLOW_DIR_IS_C2S(dir) ((dir) == NP_FLOW_DIR_C2S ? 1 : 0)

static inline int16_t nt_user_dir(user_info_t *ui, struct iphdr *iph)
{
	if(__be32_to_cpu(iph->saddr) == ui->ip) {
		return NP_USER_XMIT;
	} else {
		return NP_USER_RECV;
	}
}
#define USER_DIR_IS_XMIT(dir) ((dir) == NP_USER_XMIT ? 1 : 0)