#include "nquery.h"

typedef struct {
	uint32_t id, magic;
} tuple_t;

int dump_user(user_info_t *ui, void *p)
{
	tuple_t *tuple = p;

	if(tuple->id >= 0 && (uint32_t)tuple->id == ui->id) {
		nt_dump(&ui->hdr, sizeof(ui->hdr), FMT_USER_STR"\n", FMT_USER(ui));
	} else {
		nt_print(FMT_USER_STR" recv:[%llu, %llu] xmit:[%llu, %llu]\n",
			FMT_USER(ui),
			ui->hdr.recv_pkts, ui->hdr.recv_bytes,
			ui->hdr.xmit_pkts, ui->hdr.xmit_bytes);
	}
}

void dump_userinfo(int id, int magic)
{
	int res;
	tuple_t tuple;

	tuple.id = id;
	tuple.id = magic;
	res = nt_trav_user(pntrack, 0, 0, &tuple, dump_user);
	if(res < 0) {
		exit(-1);
	}
}

int dump_flow(flow_info_t *fi, void *p)
{
	tuple_t *tuple = p;

	user_info_t* ui = nt_get_user_by_flow(pntrack, fi);
	nt_print(FMT_FLOW_STR" l7: %d, recv:[%llu, %llu] xmit:[%llu, %llu]\n\t"FMT_USER_STR"\n",
		FMT_FLOW(fi), nt_flow_nproto(fi),
		fi->hdr.recv_pkts, fi->hdr.recv_bytes,
		fi->hdr.xmit_pkts, fi->hdr.xmit_bytes,
		FMT_USER(ui));

	return 0;
}

void dump_flowinfo(int fid, int magic)
{
	int res;
	tuple_t tuple;

	tuple.id = fid;
	tuple.magic = magic;
	res = nt_trav_flow(pntrack, 0, 0, &tuple, dump_flow);
	if(res < 0) {
		exit(-1);
	}
}
