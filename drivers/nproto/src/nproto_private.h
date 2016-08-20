#include <linux/nos_track.h>
#include <ntrack_comm.h>
#include <ntrack_packet.h>
#include <ntrack_nproto.h>

#include "nproto_log.h"

#define DRIVER_NAME "nproto"
extern int rule_trace_id;

int test_init(void);
void test_exit(void);
int nproto_init(void);
void nproto_cleanup(void);
int nproto_rules_match(nt_packet_t *pkt);
void nproto_update_flow(flow_info_t *fi, uint16_t proto_new);
int nproto_rules_dump_name(char *out, int olen, char *buffer, int bufsz, int offset);
int nproto_proc_init(void);
void nproto_proc_exit(void);