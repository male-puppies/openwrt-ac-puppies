
#include "mwm.h"

#define MAX_REF_RULES 8
#define MAX_L4_ADDRS 8
#define MAX_L4_PORTS 31

#define MAX_L7_LEN_LIST 15
#define MAX_L7_LEN_RANGE 16

#define MAX_CT_MATCH_NUM 16

typedef struct {
	uint32_t addrs[MAX_L4_ADDRS];
	uint16_t ports[MAX_L4_PORTS];
	uint16_t proto;
} l4_match_t;

typedef struct {
	int16_t offset;
	int16_t fixed;
	uint8_t width; //byte, short, int -> 1,2,4
} len_match_t;

typedef struct {

} content_match_t;

typedef struct {
	uint8_t dir;
	
	/* length info */
	uint8_t len_type;
	uint16_t len_list[MAX_L7_LEN_LIST];
	uint16_t len_range[MAX_L7_LEN_RANGE][2];
	len_match_t len_match;

	/* content info */
	uint8_t ct_match_num;
	uint8_t ct_match_relation; /* or|and */
	content_match_t ct_match[MAX_CT_MATCH_NUM];
} l7_match_t;

typedef struct {
	/* rule name, app name(xunlei, web-chrome), service: http, mail, game. */
	char *name_rule, *name_app, *name_service;

	uint16_t ID;
	/* this rule ref to other/base rules. */
	uint16_t ID_REFs[MAX_REF_RULES];
	/* 
	* base: start match as unknown, or ref to someone.
	* ref: 0: current-package/1: cross-package-in-session. 
	* 		bit-map: 0/1/2/3.
	*/
	uint8_t base_rule;
	uint8_t ref_type;

	/* enable the l4/l7 match process */
	uint8_t enable_l4, enable_l7;

	/* l4 header match */
	l4_match_t l4;

	/* payload data match */
	l7_match_t l7;
} nproto_rule_t;

/* 
** rule set:
** 	UDP
**	TCP ->
		HTTP
		Not-HTTP
	Others
*/
typedef struct {
	uint16_t num_rules;
	uint16_t num_capacity; /* the capacity of this set */
	nproto_rule_t *rules[]; /* the dmalloc array pointer */
	mwm_t *pmwm; /* rules with 4 char search patterns. */
} np_rule_set_t;
