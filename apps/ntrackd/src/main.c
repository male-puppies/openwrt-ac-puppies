#define _GNU_SOURCE
#include <sched.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <fcntl.h>
#include <errno.h>

#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/socket.h>

#include <linux/netlink.h>

#include <ntrack_rbf.h>
#include <ntrack_log.h>
#include <ntrack_msg.h>
#include <ntrack_auth.h>

/* update conf to kernel modules */
extern int nt_nl_init(void);
extern int nt_nl_xmit(void *data);

/* kernel user node message delivery to authd. */
extern int nt_unotify_init(void);
extern int nt_unotify(void *buff, int len);

ntrack_t ntrack;

static int fn_message_disp(void *p)
{
	// nt_dump(p, 128, "cap:\n");
	nmsg_hdr_t *hdr = p;
	switch(hdr->type) {
		case en_MSG_t_PCAP:
		break;
		case en_MSG_t_NODE:
		break;
		case en_MSG_t_AUTH:
		{
			user_info_t *ui;
			auth_msg_t *auth = nmsg_data(hdr);
			
			nt_info("message uid: %u, magic: %u\n", auth->id, auth->magic);

			ui = nt_get_user_by_id(&ntrack, auth->id, auth->magic);
			if(ui) {
				dump_user(ui);
				nt_unotify((void*)auth, sizeof(auth_msg_t));
			}else{
				nt_error("[%u:%u]->not found userinfo.\n", auth->id, auth->magic);
			}
		}
		break;
		default:
		{
			nt_error("unknown message. %d\n", hdr->type);
		}
		break;
	}
	
	return 0;
}

char *auth_conf = " \
	{ \
		\"Type\": \"AuthRules\", \
		\"Rules\": [{\
			\"Name\": \"Web\", \
			\"IPSets\": [\"WebAuth\", \"Default\"], \
			\"Flags\": 1 \
		}, \
		{ \
			\"Name\": \"Auto\", \
			\"IPSets\": [\"AutoAuth\"], \
			\"Flags\": 0 \
		}] \
	}";

char *weix_conf = " \
	{ \
		\"Type\": \"WeiXin\", \
		[] \
	}";

int main(int argc, char *argv[])
{
	cpu_set_t set;
	int running = 1;

	if(argc < 2) {
		nt_error("ntrackd <core_num>\n");
		exit(0);
	}

	CPU_ZERO(&set);

	CPU_SET(atoi(argv[1]), &set);
	if(sched_setaffinity(getpid(), sizeof(set), &set) == -1) {
		nt_error("set c affinity.\n");
		exit(EXIT_FAILURE);
	}

	if (nt_message_init(&ntrack)) {
		nt_error("ntrack message init failed.\n");
		return 0;
	}

	/* debug */
	nt_dump(ntrack.ui_base, 128, "user base: %p\n", ntrack.ui_base);
	nt_dump(ntrack.fi_base, 128, "flow base: %p\n", ntrack.fi_base);

	nt_nl_init();
	nt_unotify_init();

	nt_nl_xmit(auth_conf);

	nt_message_process(&running, fn_message_disp);

	return 0;
}
