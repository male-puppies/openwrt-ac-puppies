#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <errno.h>
#include <string.h>
#include <rule_table.h>
#include "rule_print.h"
#include "rule_ipc.h"


static void free_sock(int sockfd)
{
	if (sockfd != -1) {
		close(sockfd);
	}
}


static int create_sock()
{
	int sockfd = -1;
	
	sockfd = socket(AF_INET, SOCK_RAW, IPPROTO_RAW);
	if (sockfd < 0) {
		AC_ERROR("create sockfd failed:%s\n", strerror(errno));
		return -1;
	}

	if (fcntl(sockfd, F_SETFD, FD_CLOEXEC) == -1) {
		AC_ERROR("Could not set close on exec: %s\n",strerror(errno));
		free_sock(sockfd);
		return -1;
	}	
	return sockfd;
}


/*
send data to kernel by setsock
cmd:option_name, which indicates the unique command
data:option_value, which will be send to kernel
len:option_len, which indicates the len of data
*/
int do_rule_ipc_set(int cmd, void *data, unsigned int len)
{
	int ret = -1, sockfd = -1;
	
	sockfd = create_sock();
	if (sockfd == -1) {
		return -1;
	}
	
	ret = setsockopt(sockfd, IPPROTO_IP, cmd, data, (socklen_t)len);
	if (ret < 0) {
		AC_ERROR("setsockopt [%d] failed for %s\n", cmd, strerror(errno));
	}
	free_sock(sockfd);

	return ret;
}


/*
get data from kernel by getsock
cmd:option_name, which indicates the unique command
data:option_value, which will bring data from kernel
len:option_len, which indicates the len of memory pointed by data
*/
int do_rule_ipc_get(int cmd, void *data, unsigned int len)
{
	int ret = -1, sockfd = -1;
	
	sockfd = create_sock();
	if (sockfd == -1) {
		return -1;
	}
	
	ret = getsockopt(sockfd, IPPROTO_IP, cmd, data, &len);
	if (ret < 0) {
		AC_ERROR("getsockopt failed for %s\n", strerror(errno));
	}
	free_sock(sockfd);

	return ret;
}