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

ntrack_t ntrack;

int nl_sock = -1;
static int nl_init(void)
{
	struct sockaddr_nl local;
	nl_sock = socket(PF_NETLINK, SOCK_RAW, NETLINK_NTRACK);
	if(nl_sock < 0) {
		nt_error("socket error: %s\n", strerror(errno));
		exit(-1);
	}
	int bufsize = 1 << 18;
	int ret = setsockopt(nl_sock, SOL_SOCKET, SO_RCVBUF, &bufsize, sizeof(int));
	if (ret < 0) {
		nt_error("set buffer size failed: %s\n",strerror(errno));
		exit(-1);
	}
	memset(&local, 0, sizeof(local));
	local.nl_family = AF_NETLINK;
	local.nl_pid = getpid();
	local.nl_groups = 0;

	if(bind(nl_sock, (struct sockaddr*)&local, sizeof(local)) != 0) {
		nt_error("bind error: %s\n", strerror(errno));
		exit(-1);
	}

	return nl_sock;
}

struct m2k {
	struct nlmsghdr hdr;
	char data[4096];
};

int xmit(char *data)
{
	struct sockaddr_nl kpeer;
	struct m2k message;
	int ret;

	if(nl_sock<0 || !data) {
		nt_error("sock closed or data nil\n");
		return -1;
	}

	memset(&kpeer, 0, sizeof(kpeer));
	kpeer.nl_family = AF_NETLINK;
	kpeer.nl_pid = 0;
	kpeer.nl_groups = 0;

	memset(&message, 0, sizeof(message));
	message.hdr.nlmsg_len = NLMSG_LENGTH(strlen(data));
	message.hdr.nlmsg_flags = 0;
	message.hdr.nlmsg_type = 0;
	message.hdr.nlmsg_seq = 0;
	message.hdr.nlmsg_pid = getpid();

	memcpy(NLMSG_DATA(&message), data, strlen(data));
	nt_info("message send to kernel: %d bytes.\n", strlen(data));
	ret = sendto(nl_sock, 
		&message, 
		message.hdr.nlmsg_len, 0, 
		(struct sockaddr*)&kpeer, sizeof(kpeer));
	if(!ret) {
		nt_error("send error: %s\n", strerror(errno));
		return -1;
	}

	return 0;
}

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

char *conf_str = " \
	[{\
		\"Name\": \"Web\", \
		\"IPSets\": [\"WebAuth\", \"Default\"], \
		\"Flags\": 1 \
	}, \
	{ \
		\"Name\": \"Auto\", \
		\"IPSets\": [\"AutoAuth\"], \
		\"Flags\": 0 \
	}]";

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

	nl_init();

	xmit(conf_str);

	nt_message_process(&running, fn_message_disp);

	return 0;
}
