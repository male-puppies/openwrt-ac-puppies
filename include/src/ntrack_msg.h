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
	en_MSG_t_PCAP = 1,
	en_MSG_t_NODE,
	en_MSG_t_AUTH,
};

typedef struct {
	uint16_t type;
	uint16_t prio;
	uint16_t data_len;
	uint16_t crc;
} nmsg_hdr_t;

static inline void* nmsg_data(nmsg_hdr_t *hdr)
{
	return (void*)((char*)hdr + sizeof(nmsg_hdr_t));
}

#ifdef __KERNEL__
/* 
* ntrack message queue init/fini.
*/
int nmsg_init(void);
void nmsg_cleanup(void);

/* 
* init the message header, setup type & content length.
*/
static inline nmsg_hdr_t *nmsg_hdr_init(nmsg_hdr_t *hdr, int type, uint16_t data_len)
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
int nmsg_enqueue(nmsg_hdr_t *hdr, void *buff, uint32_t key);

#else /* __KERNEL__ */

/* init the ntrack message system, for libpps.so call by others */
int nt_message_init(ntrack_t *nt);

typedef int (*nmsg_cb_t)(void *p);

/*
* process the kernel message.
*/
int nt_message_process(uint32_t *running, nmsg_cb_t cb);


#endif /* KERNEL */

