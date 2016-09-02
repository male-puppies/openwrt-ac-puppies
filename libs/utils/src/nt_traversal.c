#include "lib_private.h"

int nt_trav_user(ntrack_t *nt, 
	int32_t off_count, 
	int32_t max_count, 
	void *udata, 
	nt_trav_user_cb_t callback)
{
	int i, res, count;

	count = 0;
	for(i = off_count; i<nt->ui_count; i++) {
		user_info_t *ui = &nt->ui_base[i];

		count ++;
		if(max_count && count >= max_count) {
			return i;
		}
		if(!magic_valid(ui->magic)) {
			// nt_warn("[%d %d] magic invalid.\n", ui->id, ui->magic);
			continue;
		}
		/* check ui use api */
		ui = nt_get_user_by_id(nt, ui->id, ui->magic);
		if(!ui) {
			nt_error("[%d %d] not found.\n", ui->id, ui->magic);
			continue;
		}
		res = callback(ui, udata);
		if(res < 0) {
			nt_warn("stoped as " FMT_USER_STR " return: %d\n", FMT_USER(ui), res);
			return i;
		}
	}

	return i;
}

int nt_trav_flow(ntrack_t *nt, 
	int32_t off_count, 
	int32_t max_count, 
	void *udata, 
	nt_trav_flow_cb_t callback)
{
	int i, res, count;

	count = 0;
	for(i = off_count; i<nt->fi_count; i++) {
		flow_info_t *fi = &nt->fi_base[i];

		count ++;
		if(max_count && count >= max_count) {
			return i;
		}
		if(!magic_valid(fi->magic)) {
			// nt_warn("[%d %d] magic invalid.\n", fi->id, fi->magic);
			continue;
		}
		/* check fi use api */
		fi = nt_get_flow_by_id(nt, fi->id, fi->magic);
		if(!fi) {
			nt_error("[%d %d] not found.\n", fi->id, fi->magic);
			continue;
		}
		res = callback(fi, udata);
		if(res < 0) {
			nt_warn("stoped as " FMT_FLOW_STR " return: %d\n", FMT_FLOW(fi), res);
			return i;
		}
	}

	return i;
}