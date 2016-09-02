#pragma once

#include <linux/nos_track.h>
#include <ntrack_flow.h>
#include <ntrack_log.h>

/* KERNEL & USER comm use. */
#define USER_PRIV_SIZE 		sizeof((user_info_t*)(void*(0))->private)
#define FLOW_PRIV_SIZE 		sizeof((flow_info_t*)(void*(0))->private)

static inline uint32_t magic_valid(uint32_t m)
{
	return m % 2 == 0;
}

#ifdef __KERNEL__
/* kernel node opt apis */
static inline flow_info_t * nt_flow(struct nos_track *nt)
{
	flow_info_t *fi = nt->flow;
	nt_assert(fi);
	nt_assert(fi->id >= 0 && fi->id < nos_flow_info_max);
	return fi;
}

static inline user_info_t * nt_user(struct nos_track *nt)
{
	user_info_t *ui = nt->ui_src;
	nt_assert(ui);
	nt_assert(ui->id >= 0 && ui->id < nos_user_info_max);
	return ui;
}

static inline user_info_t * nt_peer(struct nos_track *nt)
{
	user_info_t *ui = nt->ui_dst;
	nt_assert(ui);
	nt_assert(ui->id >= 0 && ui->id < nos_user_info_max);
	return ui;
}

#else /* __KERNEL__ */

/* node track base address mmmap used. */
typedef struct {
	uint32_t fi_count, ui_count;
	flow_info_t *fi_base;
	user_info_t *ui_base;
} ntrack_t;

/* callback as traversal
	@return < 0, stop traversal, 
		otherwise continue next. 
*/
typedef int(*nt_trav_flow_cb_t)(flow_info_t *fi, void *p);
typedef int(*nt_trav_user_cb_t)(user_info_t *ui, void *p);

/* traversal flow / user buy segment. */
int nt_trav_flow(ntrack_t *nt,
		int32_t off_count,
		int32_t max_count,
		void *udata,
		nt_trav_flow_cb_t cb_fn);
int nt_trav_user(ntrack_t *nt,
		int32_t off_count,
		int32_t max_count,
		void *udata,
		nt_trav_user_cb_t cb_fn);

/* userspace node opt apis */
static inline flow_info_t * nt_get_flow_by_id(ntrack_t *nt, uint32_t id, uint32_t magic)
{
	flow_info_t *fi = &nt->fi_base[id];

	nt_assert(id >= 0 && id < nt->fi_count);
	/* check magic */
	if (fi->magic != magic) {
		return NULL;
	}
	return fi;
}

static inline user_info_t * nt_get_user_by_id(ntrack_t *nt, uint32_t id, uint32_t magic)
{
	user_info_t *ui = &nt->ui_base[id];

	nt_assert(id >= 0 && id < nt->ui_count);
	/* check magic */
	if (ui->magic != magic) {
		return NULL;
	}
	return ui;
}

static inline user_info_t * nt_get_user_by_flow(ntrack_t *nt, flow_info_t *fi)
{
	uint32_t uid = fi->ui_src_id;

	nt_assert(uid >=0 && uid < nt->ui_count);
	return &nt->ui_base[uid];
}
/* end node track */
#endif /* __KERNEL__ */
