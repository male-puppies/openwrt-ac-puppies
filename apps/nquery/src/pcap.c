
#define _GNU_SOURCE
#include <sched.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <fcntl.h>
#include <errno.h>
#include <pcap/pcap.h>

#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <arpa/inet.h>

#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <linux/netlink.h>

#include <ntrack_rbf.h>
#include <ntrack_log.h>
#include <ntrack_nproto.h>

static int nl_sock = -1;
static int sock_init(void)
{
	struct sockaddr_nl local;
	int sock = socket(PF_NETLINK, SOCK_RAW, NETLINK_NPROTO);
	if(sock < 0) {
		nt_error("socket error: %s\n", strerror(errno));
		exit(-1);
	}
	int bufsize = 1 << 18;
	int ret = setsockopt(sock, SOL_SOCKET, SO_RCVBUF, &bufsize, sizeof(int));
	if (ret < 0) {
		nt_error("set buffer size failed: %s\n",strerror(errno));
		exit(-1);
	}
	memset(&local, 0, sizeof(local));
	local.nl_family = AF_NETLINK;
	local.nl_pid = getpid();
	local.nl_groups = 0;

	if(bind(sock, (struct sockaddr*)&local, sizeof(local)) != 0) {
		nt_error("bind error: %s\n", strerror(errno));
		exit(-1);
	}

	return sock;
}

struct m2k {
	struct nlmsghdr hdr;
	char data[4096];
};

int nt_nl_xmit(u_char *data, int dlen)
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
	message.hdr.nlmsg_len = NLMSG_LENGTH(dlen);
	message.hdr.nlmsg_flags = 0;
	message.hdr.nlmsg_type = 0;
	message.hdr.nlmsg_seq = 0;
	message.hdr.nlmsg_pid = getpid();

	memcpy(NLMSG_DATA(&message), data, dlen);
	ret = sendto(nl_sock, 
		&message, 
		message.hdr.nlmsg_len, 0, 
		(struct sockaddr*)&kpeer, sizeof(kpeer));
	if(!ret) {
		nt_error("send error: %s\n", strerror(errno));
		return -1;
	}
	nt_print(" %d", dlen);

	return 0;
}

int pcap_init(void)
{
	nl_sock = sock_init();
	if(nl_sock < 0) {
		nt_error("sock init failed.\n");
		return -ENOMEM;
	}
	return 0;
}

static void pkt_hander(u_char *user, const struct pcap_pkthdr *pkthdr, 	const u_char *packet)
{
	const struct ethhdr* ether;
	const struct iphdr* iph;
	const struct tcphdr* tcp;
	char saddr[INET_ADDRSTRLEN];
	char daddr[INET_ADDRSTRLEN];
	uint32_t source, dest;
	u_char *data;
	int dlen = 0;

	ether = (struct ethhdr*)packet;
	if (ntohs(ether->h_proto) == ETH_P_IP) {
	    iph = (struct iphdr*)(packet + sizeof(struct ethhdr));

	    // inet_ntop(AF_INET, &(iph->saddr), saddr, INET_ADDRSTRLEN);
	    // inet_ntop(AF_INET, &(iph->daddr), daddr, INET
	    
	    data = (u_char*)iph;
	    dlen = pkthdr->len - sizeof(struct ethhdr);

		if(nt_nl_xmit(data, dlen)) {
			nt_error("xmit to kernel failed.\n");
	    	nt_dump(data, dlen, "dump: %d\n", dlen);
		} else {
			// usleep(500);
		}
	}
}

int pcap_run(char *fpcap)
{
	char errbuf[PCAP_ERRBUF_SIZE];

	pcap_t *pcap = pcap_open_offline(fpcap, errbuf);
	if(!pcap) {
		nt_error("open %s failed.\n", fpcap);
		return -EINVAL;
	}

	nt_nl_xmit("init", sizeof("init"));
	if(pcap_loop(pcap, 0, pkt_hander, NULL) < 0) {
		nt_error("loop pcap failed.\n");
		return -EINVAL;
	}

	return 0;
}