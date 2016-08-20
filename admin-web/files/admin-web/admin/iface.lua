local js = require("cjson.safe")
local log = require("common.log")
local rds = require("common.rds")
local query = require("common.query")
local adminlib = require("admin.adminlib")
local network = require("admin.network")

local r1 = log.real1
local reply_e, reply = adminlib.reply_e, adminlib.reply
local validate_get, validate_post = adminlib.validate_get, adminlib.validate_post
local gen_validate_num, gen_validate_str = adminlib.gen_validate_num, adminlib.gen_validate_str

local validate_type = gen_validate_num(2, 3)
local validate_zid = gen_validate_num(0, 255)
local validate_zids = gen_validate_str(2, 256)
local validate_des = gen_validate_str(1, 32, true)
local validate_name = gen_validate_str(1, 32, true)

local function query_u(p, timeout)	return query.query_u("127.0.0.1", 50003, p, timeout) end

local cmd_map = {}

local function run(cmd) 	local _ = (cmd_map[cmd] or cmd_map.numb)(cmd) 	end
function cmd_map.numb(cmd) 	reply_e("invalid cmd " .. cmd) 					end

local function query_common(m, cmd)
	m.cmd = cmd
	local r, e = query_u(m)
	if not r then
		return reply_e(e)
	end
	ngx.say(r)
end

function cmd_map.iface_get()
	local m, e = validate_get({})
	if not m then return reply_e(e) end
	return query_common(m, "iface_get")
end
local s = [[
{
            "name": "custom",
            "network": {
                "lan0": {
                    "mac": "00:00:00:00:00:01",
                    "proto": "static",
                    "dns": "",
                    "mtu": "",
                    "ports": [
                        1,
                        2,
                        3,
                        4
                    ],
                    "pppoe_account": "",
                    "pppoe_password": "",
                    "gateway": "",
                    "dhcpd": {
                        "enabled": 1,
                        "leasetime": "12h",
                        "dns": "172.16.0.1",
                        "end": "172.16.200.254",
                        "start": "172.16.0.100",
                        "staticlease": {},
                        "dynamicdhcp": 1
                    },
                    "metric": "",
                    "ipaddr": "172.16.0.1/16"
                },
                "wan0": {
                    "mac": "00:00:00:00:00:01",
                    "proto": "dhcp",
                    "dns": "",
                    "mtu": "",
                    "ports": [
                        5
                    ],
                    "pppoe_account": "",
                    "pppoe_password": "",
                    "gateway": "",
                    "dhcpd": {
                        "enabled": 0,
                        "leasetime": "12h",
                        "dns": "",
                        "end": "",
                        "start": "",
                        "staticlease": {},
                        "dynamicdhcp": 1
                    },
                    "metric": "",
                    "ipaddr": ""
                }
            }
        }
]]
function cmd_map.iface_set()
	ngx.req.read_body()
	local p = ngx.req.get_post_args()
	local arg = p.arg
	local cfg, e = network.validate(arg)
	if not cfg then
		return reply_e(e)
	end
	return query_common({cmd = "iface_set", network = cfg}, "iface_set")
end

return {run = run}

