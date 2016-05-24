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

int nl_sock = -1;
int nt_nl_init(void)
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

int nt_nl_xmit(void *data)
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

