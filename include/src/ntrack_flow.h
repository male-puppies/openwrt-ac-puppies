#pragma once

typedef struct {
	/* 
	** PT_SOCK4, PT_SOCK5, PT_HTTP.
	** PS_UNKNOWN, PS_PORT, PS_ADDR_PORT, PS_FINISH.
	*/
	uint8_t prx_type:4, prx_status:4;

} nt_flow_nproto_t;

typedef struct {
	/*
	** auth data stored in flow private area.
	*/
} nt_flow_authd_t;

static void inline nt_flow_update_proto(
	flow_info_t *fi, uint16_t proto, 
	void (*cb)(flow_info_t *, uint16_t))
{
	if(fi->hdr.proto != proto) {
		if(cb){
			cb(fi, proto);
		}
	}
	fi->hdr.proto = proto;
}
