#pragma once

#ifdef __KERNEL__
#include <linux/list.h>
#include <ntrack_rbf.h>
#else
#include <stdint.h>
#endif

#include <ntrack_comm.h>

/*
* ntrack message system defines.
*/
enum {
	en_MSG_PCAP = 1,
	en_MSG_NODE,
	en_MSG_AUTH,
	en_MSG_NACS,
};

typedef struct {
	uint16_t type;
	uint16_t prio;
	uint16_t data_len;
	uint16_t crc;
} nt_msghdr_t;

static inline void* nt_msg_data(nt_msghdr_t *hdr)
{
	return (void*)((char*)hdr + sizeof(nt_msghdr_t));
}

#ifdef __KERNEL__
/* 
* init the message header, setup type & content length.
*/
static inline nt_msghdr_t *nt_msghdr_init(nt_msghdr_t *hdr, int type, uint16_t data_len)
{
	memset(hdr, 0, sizeof(*hdr));
	hdr->type = type;
	hdr->data_len = data_len;
	return hdr;
}

/*
* @hdr  inited message hdr, with the data length info.
* @buff message content.
* @key 	hash key for SMP delivery.
* @return success 0, -num failed.
*/
int nt_msg_enqueue(nt_msghdr_t *hdr, void *buff, uint32_t key);

#else /* __KERNEL__ */

/* init the ntrack message system, for libpps.so call by others */
int nt_base_init(ntrack_t *nt);
int nt_message_init(rbf_t **);

/* flush out the stat results. */
int nt_stat_flush(ntrack_t *nt);

typedef int (*nmsg_cb_t)(void *p);

/*
* process the kernel message.
*/
int nt_message_process(rbf_t *rbfp, uint32_t *running, nmsg_cb_t cb);


#endif /* KERNEL */

