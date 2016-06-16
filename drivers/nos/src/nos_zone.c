/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Wed, 15 Jun 2016 18:31:41 +0800
 */
#include <linux/netdevice.h>
#include "nos_zone.h"

static unsigned int if_zone_map[MAX_IF_INDEX];
unsigned int get_if_zone(const struct net_device *dev)
{
	if (!dev)
		return INVALID_ZONE_ID;
	if (dev->ifindex < MAX_IF_INDEX) {
		return if_zone_map[dev->ifindex] & ZONE_ID_MASK;
	}
	return INVALID_ZONE_ID;
}

void set_if_zone(const struct net_device *dev, unsigned int zone_id)
{
	if (dev->ifindex < MAX_IF_INDEX) {
		if_zone_map[dev->ifindex] = zone_id & ZONE_ID_MASK;
	}
}

void reset_if_zone(void)
{
	int i;
	for (i = 0; i < MAX_IF_INDEX; i++) {
		if_zone_map[i] = INVALID_ZONE_ID;
	}
}

int nos_zone_init(void)
{
	reset_if_zone();
	return 0;
}

void nos_zone_exit(void)
{
}
