/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Wed, 15 Jun 2016 18:31:41 +0800
 */
#ifndef _NOS_ZONE_H_
#define _NOS_ZONE_H_
#include <linux/netdevice.h>

#define MAX_IF_INDEX 256
#define INVALID_ZONE_ID 0xFF
#define ZONE_ID_MASK 0xFF
extern unsigned int get_if_zone(const struct net_device *dev);
extern void set_if_zone(const struct net_device *dev, unsigned int zone_id);
extern void reset_if_zone(void);

extern int nos_zone_init(void);
extern void nos_zone_exit(void);

#endif /* _NOS_ZONE_H_ */
