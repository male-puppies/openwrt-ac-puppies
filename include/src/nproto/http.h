#pragma once

enum __em_http_headers {
	NP_HTTP_END = 0,
	NP_HTTP_URL,
	NP_HTTP_Host,
	NP_HTTP_Referer,
	NP_HTTP_Content, 
	NP_HTTP_Accept, 
	NP_HTTP_User_Agent, 
	NP_HTTP_Http_Encoding, 
	NP_HTTP_Transfer_Encoding, 
	NP_HTTP_Content_Len, 
	NP_HTTP_Cookie, 
	NP_HTTP_X_Session_Type, 
	NP_HTTP_Method, 
	NP_HTTP_Response, 
	NP_HTTP_Server, 
	NP_HTTP_End_Header, 
	NP_HTTP_MAX,
};


typedef struct {
	uint16_t hdrs_off[NP_HTTP_MAX];
} nproto_http_t;