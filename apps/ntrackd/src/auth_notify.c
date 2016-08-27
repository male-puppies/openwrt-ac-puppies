#include <ntrack_rbf.h>
#include <ntrack_log.h>
#include <ntrack_msg.h>
#include <ntrack_auth.h>
#include <stdlib.h>
#include <strings.h>

char *trans_authmsg(ntrack_t *ntrack, auth_msg_t *auth, int *len)
{
	user_info_t *ui;
	char buf[128], *msg_buf = NULL;
	int n;
	n = sprintf(buf, "{\"cmd\":\"keepalive\",\"magic\":%u,\"uid\":%u}", auth->magic, auth->id);
	msg_buf = (char*)malloc(n);

	if (!msg_buf) {
		nt_error("trans_authmsg failed: no memory\n");
		return msg_buf;
	}
	memcpy(msg_buf, buf, n);
	nt_debug("message uid: %u, magic: %u\n", auth->id, auth->magic);
	ui = nt_get_user_by_id(ntrack, auth->id, auth->magic);
	if(ui) {
		dump_user(ui);
	} else {
		free(msg_buf);
		msg_buf = NULL;
		nt_error("[%u:%u]->not found userinfo.\n", auth->id, auth->magic);
	}
	*len = msg_buf ? n : 0;
	return msg_buf;
}
