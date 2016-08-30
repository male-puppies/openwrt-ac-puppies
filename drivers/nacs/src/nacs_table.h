#ifndef _NACS_TABLE_H
#define _NACS_TABLE_H
#include <ntrack_flow.h>

int nacs_table_init(void);
void nacs_table_fini(void);

int do_replace_table(const void __user *user, unsigned int len);
int do_replace_set(const void __user *user, unsigned int len);

int do_get_table_info(void __user *user, int *len);
int do_get_set_info(void __user *user, int *len);
int do_get_entries(void __user *user, int *len) ;
int do_get_sets(void __user *user, int *len);

int do_ac_table_hk(
	struct net_device *in,
	struct net_device *out,
	struct sk_buff *skb,
	flow_info_t *fi,
	user_info_t *ui,
	user_info_t *pi);

int do_ac_table_cb(
	struct net_device *in,
	struct net_device *out,
	struct sk_buff *skb,
	flow_info_t *fi,
	user_info_t *ui,
	user_info_t *pi,
	uint32_t proto_new);
#endif