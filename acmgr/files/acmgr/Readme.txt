readme

{
	"cmd":	"aclog",
	"ruletype":	"CONTROL",
	"subtype":	"RULE",
	"actions":	["REJECT"],
	"user":	{
		"mac":	"11:22:33:44:55:66",
		"ip":	"192.168.0.1"
	},
	"flow":	{
		"src_ip":	3232235521,
		"dst_ip":	3232235522,
		"src_port":	100,
		"dst_port":	101,
		"proto":	0
	},
	"rule":	{
		"rule_id":	1000,
		"src_zone":	0,
		"dst_zone":	1,
		"proto_id":	123456,
		"src_ipgrp_bits":	[0, 1, 3],
		"dst_ipgrp_bits":	[0, 4, 8, 12]
		or
		"set_name":MACWHITELIST/IPWHITELIST/MACBLACKLIST/IPBLACKLIST
	},
	"time_stamp":	2003607180
}