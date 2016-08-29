#include <linux/nos_track.h>
#include <ntrack_comm.h>
#include <ntrack_packet.h>
#include <ntrack_nproto.h>

#include "nproto_log.h"
#include "rules.h"

#define DRIVER_NAME "nproto"
extern int rule_trace_id;

int test_init(void);
void test_exit(void);

int stat_init(void);
void stat_flow(flow_info_t *fi, int16_t dir, int16_t nbytes);
void stat_user(user_info_t *ui, user_info_t *pi, int16_t dir, int16_t nbytes);

int nproto_init(void);
void nproto_cleanup(void);
int nproto_proc_init(void);
void nproto_proc_exit(void);
void nproto_update(nt_packet_t *pkt, np_rule_t *rule);
int nproto_rules_match(nt_packet_t *pkt);
int nproto_rules_dump_name(char __user *out, int olen, char *buffer, int bufsz, int offset);
