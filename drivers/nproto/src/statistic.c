#include "nproto_private.h"

inline void stat_flow(flow_info_t *fi, 
		int16_t dir, int16_t nbytes)
{
	flow_hdr_t *hdr = &fi->hdr;
	if(dir) {
		hdr->recv_pkts ++;
		hdr->recv_bytes += nbytes;
	} else {
		hdr->xmit_pkts ++;
		hdr->xmit_bytes += nbytes;
	}
}

inline void stat_user(
		user_info_t *ui, 
		user_info_t *pi,
		int16_t dir, int16_t nbytes)
{
	user_hdr_t *uh = &ui->hdr;
	user_hdr_t *ph = &pi->hdr;
	if(dir) {
		uh->xmit_pkts ++;
		uh->xmit_bytes += nbytes;
		ph->recv_pkts ++;
		ph->recv_bytes += nbytes;
	} else {
		ph->xmit_pkts ++;
		ph->xmit_bytes += nbytes;
		uh->recv_pkts ++;
		uh->recv_bytes += nbytes;
	}
}
