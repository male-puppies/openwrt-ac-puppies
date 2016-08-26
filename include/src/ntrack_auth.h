#pragma once

#include <linux/nos_track.h>
#include <ntrack_log.h>

#ifdef __KERNEL__
#include <linux/list.h>
#include <linux/netfilter/xt_set.h>
#else
#include <stdint.h>
#endif

/* U & K Common */
#define NETLINK_NTRACK 28

/* auth node api */
#define USR_TS_KEEP_ALIVE HZ * 30
typedef enum {
	AUTH_NONE = 0,
	AUTH_OK = 1,
	AUTH_BYPASS = 2,
	AUTH_REQ = 3,
} auth_status_t;

/* authd user keepalive message */
typedef struct {
	uint32_t magic, id;
	/* FIXME: contents */
} auth_msg_t;

typedef struct {
	/* auth data store in user node. */
	void *p;
} nt_authd_t;

static inline uint32_t nt_auth_status(user_info_t *ui)
{
	return ui->hdr.status;
}

static inline uint32_t nt_auth_set_status(user_info_t *ui, uint8_t status)
{
	uint8_t s_priv = ui->hdr.status;

	ui->hdr.status = status;
	return s_priv;
}

/*
* [-- nt_authd_t --+-- priv --]
*/
static inline void *nt_user_priv(user_info_t *ui)
{
	return &ui->private[sizeof(nt_authd_t)];
}

static inline nt_authd_t *nt_user_authd(user_info_t *ui)
{
	return (nt_authd_t*)ui->private;
}

static inline void dump_user(user_info_t *ui)
{
	nt_print("[%u.%u.%u.%u] gid:%d flags:%x\n", 
		NIPQUAD(ui->ip), ui->hdr.u_grp_id, ui->hdr.flags);
}
/* END Common */

#ifdef __KERNEL__

int l3filter(struct iphdr* iph);

#endif //__KERNEL__
