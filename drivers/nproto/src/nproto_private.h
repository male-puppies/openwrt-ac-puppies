#include <linux/nos_track.h>
#include <ntrack_comm.h>
#include <ntrack_packet.h>
#include <ntrack_nproto.h>

#include "nproto_log.h"

int test_init(void);

void test_exit(void);

int nproto_init(void);

void nproto_cleanup(void);

int nproto_rules_match(nt_packet_t *pkt);

void nproto_update_flow(flow_info_t *fi, uint16_t proto_new);