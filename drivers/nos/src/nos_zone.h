/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Wed, 15 Jun 2016 18:31:41 +0800
 */
#ifndef _NOS_ZONE_H_
#define _NOS_ZONE_H_
#include <linux/netdevice.h>
#include <ntrack_comm.h>

#define MAX_IF_INDEX 4096
#define INVALID_ZONE_ID 255
#define ZONE_ID_MASK 255

struct zone_t {
	unsigned int id;
	char if_name[IFNAMSIZ];
};

int nos_zone_init(void);
void nos_zone_exit(void);

unsigned int nos_zone_match(const struct net_device *dev);

#endif /* _NOS_ZONE_H_ */
