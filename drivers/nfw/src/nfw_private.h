#include <linux/nos_track.h>
#include <ntrack_comm.h>
#include <ntrack_nproto.h>

#include "nfw_log.h"

void fw_log(const char *fmt, ...);

int nfw_dbg_init(void);
void nfw_dbg_exit(void);
int nfw_droplist_match(flow_info_t *fi);