#pragma once

#include <linux/module.h>
#include <linux/vmalloc.h>
#include <linux/netfilter.h>
#include <linux/ip.h>
#include <linux/version.h>

#include <linux/netfilter/xt_set.h>

#include <net/ip.h>
#include <net/netfilter/nf_conntrack.h>

#include <ntrack_auth.h>
#include <ntrack_log.h>

#define CT_CAP_LEN_MAX 1600

typedef struct {
	uint32_t fid, fmagic;
	uint16_t dlen;
	uint8_t data[CT_CAP_LEN_MAX];
} pkt_cap_t;