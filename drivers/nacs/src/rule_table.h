/*	
* Description of basic data structures which are used in both userspace and kernel space.
*/

#ifndef _RULE_TABLE_H
#define _RULE_TABLE_H

#include <linux/types.h>
#include <linux/kernel.h>
#ifndef __KERNEL__
#include <limits.h>
#endif

/*'kernel.h' contains some often-used function prototypes etc*/
#define __ALIGN_KERNEL(x, a)		__ALIGN_KERNEL_MASK(x, (typeof(x))(a) - 1)
#define __ALIGN_KERNEL_MASK(x, mask)	(((x) + (mask)) & ~(mask))
/* this is a dummy structure to find out the alignment requirement for a struct
 * containing all the fundamental data types that are used in ipt_entry,
 * ip6t_entry and arpt_entry.  This sucks, and it is a hack.  It will be my
 * personal pleasure to remove it -HW
 */
struct _ac_align {
	__u8 u8;
	__u16 u16;
	__u32 u32;
	__u64 u64;
};
/*Notice:all data in flexible array must be aligned with AC_ALIGN*/
#define AC_ALIGN(s) __ALIGN_KERNEL((s), __alignof__(struct _ac_align))

#ifndef ETH_ALEN
#define ETH_ALEN	6	/*Octets in one ethernet addr*/
#endif

/*rule type*/
enum rule_type {
	RULE_TYPE_CONTROL = 0,
	RULE_TYPE_AUDIT,
	/*new type add here*/
	RULE_TYPE_MAX
};

/*there are four type sets totally*/
#define AC_MACWHITELIST_SET 	0
#define AC_IPWHITELIST_SET		1
#define AC_MACBLACKLIST_SET 	2
#define AC_IPBLACKLIST_SET 		3
#define AC_IPSET_TYPE_MAX		4

/*we use ipset to matain mac&ip blacklist or whitelist,
  In kernel, we reference these sets by name;
*/
enum control_ipset_type {
	CONTROL_MACWHITELIST_SET	= AC_MACWHITELIST_SET,
	CONTROL_IPWHITELIST_SET		= AC_IPWHITELIST_SET,
	CONTROL_MACBLACKLIST_SET	= AC_MACBLACKLIST_SET,
	CONTROL_IPBLACKLIST_SET		= AC_IPBLACKLIST_SET,
	/*new type add here*/
	CONTROL_IPSET_TYPE_MAX
};

enum audit_ipset_type {
	AUDIT_MACWHITELIST_SET	= AC_MACWHITELIST_SET,
	AUDIT_IPWHITELIST_SET	= AC_IPWHITELIST_SET,
	/*new type add here*/
	AUDIT_IPSET_TYPE_MAX
};


/*ID are index used in kernel space, Tweak with id_t
if you want to increase the max number of sets.*/
typedef __u8	flow_id_t;
typedef __u32 	proto_id_t;
#ifndef __KERNEL__
/*this must be same with that of kernel*/
typedef __u16	ip_set_id_t;
#define IPSET_INVALID_ID		65535	
#else
#include <linux/netfilter/ipset/ip_set.h>
#endif

/*notice:(AC_IPSET_MAXNAMELEN + 1) for c string*/
#define AC_IPSET_MAXNAMELEN 31
#define AC_RULE_MAXID       USHRT_MAX
#define AC_RULE_MINID		0

#define AC_IPGRP_MAXID  	63
#define AC_IPGRP_MINID		0

#define AC_ZONE_MAXID		255
#define AC_ZONE_MINID		0

#define AC_PROTO_MAXID 		UINT_MAX
#define AC_PROTO_MINID		0
/*protoid sorted style, we will make proto ids sorted in desc or asc for searching fast*/
enum ac_protoid_sort {
	AC_PROTOID_SORT_DESC,
	AC_PROTOID_SORT_ASC,
	AC_PROTOID_SORT_MAX
};

/*type of flow config*/
enum ac_flow_type {
	AC_FLOW_TYPE_SRCZONEID = 0,
	AC_FLOW_TYPE_SRCIPGRPID,
	AC_FLOW_TYPE_DSTZONEID,
	AC_FLOW_TYPE_DSTIPGRPID,
	/*new type add here*/
	AC_FLOW_TYPE_MAX,
};

/*ip group*/
struct ac_ipgrp {
	flow_id_t id;
};

/*zone*/
struct ac_zone {
	flow_id_t id;
};

/*Notice: Every type of match should be aligned with AC_ALIGN
both in user-space and kernel-space*/

/*infomation of traffic flow match, its elems contains four part:
partA:source zone id
partB:source ipgroup id
partC:dest zone id
partD:dest ipgroup id
*/
struct ac_flow_match {
	__u16	number[AC_FLOW_TYPE_MAX];	/*number of every type elements*/
	__u16	match_size;					/*total size of this match and should be aligned*/
	unsigned char elems[0] __attribute__((aligned(__alignof__(struct _ac_align)))); 	/*(maybe) contains several elements(zoneid,ipgrpid)*/
};

/*
*Information of proto match
*Notice: the type of the protoid, which stored in elems, is flow_id_t 
*/
struct ac_proto_match {
	__u16	number;			/*number of elements*/
	__u16	match_size;		/*total size of this match and should be aligned*/
	__u16	protoid_sort;	/*sorted type:asc or desc*/
	unsigned char elems[0] __attribute__((aligned(__alignof__(struct _ac_align))));		/*(maybe) contains several elements(protoid)*/
};

/*Action of access control.
we can combine them in code, eg, AC_REJECT|AC_AUDIT;
But AC_REJECT | AC_ACCEPT is invalid;
Please don't change the postion of these types*/
enum ac_action_type {
	AC_ACTION_ACCEPT = 0,
	AC_ACTION_AUDIT,
	AC_ACTION_REJECT ,
	/*new type add here*/
	AC_ACTION_MAX
};

#define AC_IGNORE		0						/*NO ACTION*/
#define AC_ACCEPT		(1 << AC_ACTION_ACCEPT) /*permitted*/
#define AC_AUDIT		(1 << AC_ACTION_AUDIT)	/*log a record*/
#define AC_REJECT		(1 << AC_ACTION_REJECT)	/*forbidden*/

/*information of target*/
struct ac_target {
	unsigned int size;	/*total size of target and should be aligned*/
	unsigned int flags; /*tell code what do to when matched:AC_REJECT, AC_ACCEPT, AC_AUDIT*/
};

/*A entire rule entry.It contains three parts.
PartA:flow_match;
PartB:proto_match 
PartC:target perform if rule match
notice:when multiple entries contained in ac_table_info, the next_offset will change accordingly
*/
struct ac_entry
{
	__u16 entry_id;				/*one rule correspond one entry*/
	__u16 proto_match_offset;	/* Size of ac_entry  + flow_match */
	__u16 target_offset;		/* Size of ac_entry  + flow_match + proto_match */
	__u16 next_offset;			/* Size of ac_entry + (flow & proto)matches + target*/
	unsigned char elems[0] __attribute__((aligned(__alignof__(struct _ac_align))));			/* The matches (if any), then the target. */
};

/*
*the replace table info message structure 
*which is transmited between userspace and kernelspace 
*/
struct ac_repl_table_info {
	unsigned int category;	/*distinguish audit table and control table*/
	unsigned int size;		/*total size of entries*/
	unsigned int number;	/* Number of entries of per table*/
	char entries[0];		/* ipt_entry tables*/
};

#ifdef __KERNEL__
/* The table itself.
In user space, we  user ac_repl_table_info;
However, in kernel space, We should care about Per-cpu, maybe there several repeated instances
*/
struct ac_table_info
{
	unsigned int category;	/*distinguish audit table and control table*/
	unsigned int size;		/*total size of entries*/
	unsigned int number;	/* Number of entries of per table*/
	/* ipt_entry tables*/
	char entries[0] ____cacheline_aligned;
};
#endif

/*a special entry for ipset, it contains ipset_id(like match), and flags(like target)*/
struct ac_hybrid_entry {
	__u16 size;							/*size of current entry*/
	ip_set_id_t ipset_id;				/*ipset id*/
	unsigned int flags;					/*tell code what do to when matched:AC_REJECT, AC_ACCEPT, AC_AUDIT*/
};

#ifdef __KERNEL__
/*white/black ip/mac set name, which should be create with ipset*/
struct ac_set_info 
{
	unsigned int category;	/*distinguish audit sets and control set*/
	unsigned int size;		/*total size of entries*/
	unsigned int number;	/*fixed value: CONTROL_IPSET_TYPE_MAX or AUDIT_IPSET_TYPE_MAX*/
	unsigned int updated;	/*bitmap:every bit represets a set;if bit set, set name need been updated*/
	union {
		struct {
				char ipset_name[CONTROL_IPSET_TYPE_MAX][AC_IPSET_MAXNAMELEN + 1];
			}control;
		struct {
				char ipset_name[AUDIT_IPSET_TYPE_MAX][AC_IPSET_MAXNAMELEN + 1];
			}audit;
	}u;
	/* ac_hybrid_entry with fix number CONTROL_IPSET_TYPE_MAX  or  AUDIT_IPSET_TYPE_MAX*/
	char entries[0] ____cacheline_aligned;
};
#endif

struct ac_repl_set_info {
	unsigned int category;	/*distinguish audit sets and control set*/
	unsigned int size;		/*total size of entries*/
	unsigned int number;	/*fixed value: CONTROL_IPSET_TYPE_MAX or AUDIT_IPSET_TYPE_MAX*/
	unsigned int updated;	/*bitmap:every bit represets a set;if bit set, set name need been updated*/
	union {
		struct {
				char ipset_name[CONTROL_IPSET_TYPE_MAX][AC_IPSET_MAXNAMELEN + 1];
			}control;
		struct {
				char ipset_name[AUDIT_IPSET_TYPE_MAX][AC_IPSET_MAXNAMELEN + 1];
			}audit;
	}u;
	/* ac_hybrid_entry with fix number CONTROL_IPSET_TYPE_MAX *  or  AUDIT_IPSET_TYPE_MAX*/
	char entries[0];		
};

/*get info of entries, then, we can use this to fetch details of entries*/
struct ac_get_entries_info {
	unsigned int category;	/*distinguish audit entries and control entries*/
	unsigned int number;	/*number of entries*/
	unsigned int size;		/*total size of all entries*/
};

struct ac_get_sets_info {
	unsigned int category;	/*distinguish audit sets and control sets*/
	unsigned int number;	/*number of sets*/
	unsigned int updated; 	/*bitmap*/
	unsigned int size;		/*total size of all sets*/
};


/* pos is normally a struct ac_entry. */
#define ac_entry_foreach(pos, ehead, esize) \
	for ((pos) = (typeof(pos))(ehead); \
	     (pos) < (typeof(pos))((char *)(ehead) + (esize)); \
	     (pos) = (typeof(pos))((char *)(pos) + (pos)->next_offset))


/* can only be ac_flow_match, so no use of typeof here */
#define ac_fmatch_foreach(pos, entry) \
	for ((pos) = (struct ac_proto_match *)entry->elems; \
	     (pos) < (struct ac_proto_match *)((char *)(entry) + \
	             (entry)->proto_match_offset); \
	     (pos) = (struct ac_proto_match *)((char *)(pos) + \
	             (pos)->u.match_size))

/* can only be ac_proto_match, so no use of typeof here */
#define ac_pmatch_foreach(pos, entry) \
	for ((pos) = (struct ac_proto_match *)((char*)entry + (entry)->proto_match_offset); \
	     (pos) < (struct ac_proto_match *)((char *)(entry) + \
	             (entry)->target_offset); \
	     (pos) = (struct ac_proto_match *)((char *)(pos) + \
	             (pos)->u.match_size))


/*
*ATTENTION: check linux/in.h before adding new number here.
*/
#define AC_SO_BASE_CTL 4096
#define AC_SO_SET_REPLACE_TABLE		(AC_SO_BASE_CTL)
#define AC_SO_SET_REPLACE_SET		(AC_SO_BASE_CTL + 1)
#define AC_SO_SET_MAX				AC_SO_SET_REPLACE_SET

#define AC_SO_GET_TABLE_INFO		(AC_SO_BASE_CTL)
#define AC_SO_GET_SET_INFO			(AC_SO_BASE_CTL + 1)
#define AC_SO_GET_ENTRIES			(AC_SO_BASE_CTL	+ 2)
#define AC_SO_GET_SETS      		(AC_SO_BASE_CTL	+ 3)
#define AC_SO_GET_MAX				AC_SO_GET_SETS

#ifdef __KERNEL__
#include <linux/spinlock.h>
#include <linux/cache.h>
/*align with L1_CACHE_BYTES 32, 64 or others*/
#define SMP_ALIGN(x) (((x) + SMP_CACHE_BYTES-1) & ~(SMP_CACHE_BYTES-1))
struct ac_table
{	/* Lock for the curtain */
	rwlock_t lock;				
	/* Man behind the curtain... */	
	struct ac_table_info *priv_tables[RULE_TYPE_MAX];	
	struct ac_set_info *priv_sets[RULE_TYPE_MAX];
	/* Set to THIS_MODULE. */
	struct module *me;				
};
#endif /*__KERNEL__*/

#endif	/*__RULE_TABLE_H*/