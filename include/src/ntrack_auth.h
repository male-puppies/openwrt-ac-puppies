#pragma once

#include <linux/nos_track.h>
#include <ntrack_comm.h>
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
	AUTH_UNKNOWN = 0,
	AUTH_REQ,
	AUTH_REJ,
	AUTH_OK,
} auth_status_t;
#define AUTH_STATUS_MASK (0x000000ff)
#define AUTH_STATUS(flags) (flags & AUTH_STATUS_MASK)

typedef struct {
	uint32_t magic, id;
	/* contents */
} auth_msg_t;

/*
* AUTH_UNKNOWN -> AUTH_REQ 	-> AUTH_REJ 
* 							-> AUTH_OK
*/
static inline uint32_t nt_auth_status(user_info_t *ui)
{
	return AUTH_STATUS(ui->hdr.flags);
}

static inline uint32_t nt_auth_set_status(user_info_t *ui, uint32_t status)
{
	uint32_t s_priv = AUTH_STATUS(ui->hdr.flags);
	ui->hdr.flags &= ~ AUTH_STATUS_MASK;
	ui->hdr.flags |= AUTH_STATUS(status);
	return s_priv;
}

static inline void dump_user(user_info_t *ui)
{
	nt_print("%u.%u.%u.%u - %x\n", HIPQUAD(ui->ip), ui->hdr.flags);
}
/* END Common */

#ifdef __KERNEL__
/* kernel conf json */
/*
[
	{
		Name: Web,
		IPSets: ["webauth", "default"],
		Flags: 0/1
	}, {
		Name: Auto,
		IPSets: [],
		Flags: 0/1
	}
]
*/
/* KERNEL use for parse json */
/* ipset hash:ip hash:mac check src address from skb. */
#define MAX_USR_SET 4
#define RULE_NAME_SIZE 64
typedef struct {
	uint32_t flags; /* bypass, weixin init bypass, baidu/google bypass... */
	uint32_t magic; /* conf update the magic changed. */
	uint32_t num_idx; /* ipset's count */
	ip_set_id_t uset_idx[MAX_USR_SET];
	char name[RULE_NAME_SIZE];
} auth_rule_t; 

#define MAX_URL_RULES 64
typedef struct {
	int num_rules;
	auth_rule_t rules[MAX_URL_RULES];
} G_AUTHCONF_t;

int l3filter(struct iphdr* iph);
int auth_check_http(struct iphdr *iph, 
			struct sk_buff *skb);
int user_need_redirect(struct nos_user_info *ui, 
			struct sk_buff *skb);
int ntrack_redirect(struct nos_user_info *ui, 
			struct sk_buff *skb,
			struct net_device *in,
			struct net_device *out);

/* timestamp api */
static inline utimes_t user_update_timestamp(user_info_t *ui)
{
	uint32_t utimes_t = ui->hdr.time_stamp;
	
	ui->hdr.time_stamp = jiffies;
	return utimes_t;
}

static inline utimes_t user_timeout(user_info_t *ui)
{
	return time_after(jiffies, (ui->hdr.time_stamp + USR_TS_KEEP_ALIVE));
}

#endif //__KERNEL__
