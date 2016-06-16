/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Wed, 15 Jun 2016 18:31:41 +0800
 */
#ifndef _NOS_ZONE_H_
#define _NOS_ZONE_H_
#include <linux/netdevice.h>

#define MAX_IF_INDEX 256
#define INVALID_ZONE_ID 255
#define ZONE_ID_MASK 255

struct zone_t {
	int id;
	char if_name[IFNAMSIZ];
};

int nos_zone_init(void);
void nos_zone_exit(void);

#endif /* _NOS_ZONE_H_ */
