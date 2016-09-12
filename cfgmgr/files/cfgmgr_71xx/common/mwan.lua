local js = require("cjson.safe")
local common = require("common")
local network = require("cfgmgr.network")

local read, save_safe = common.read, common.save_safe

local function load_mwan()
	local mwan_path = '/etc/config/mwan.json'
	local mwan_s = read(mwan_path) or '{}'
	local mwan_m = js.decode(mwan_s)	assert(mwan_m)

	local network_m = network.load()

	local res = {
		ifaces = {},
		policy = mwan_m.policy or "balanced",
		main_iface = mwan_m.main_iface or {},
	}

	for iface, _ in pairs(network_m.network) do
		if iface:find("^wan") then
			local iface_exist = false
			local new_ifc = nil
			for _, ifc in ipairs(mwan_m.ifaces or {}) do
				if ifc.name == iface then
					iface_exist = true
					new_ifc = ifc
					break
				end
			end
			if iface_exist then
				table.insert(res.ifaces, new_ifc)
			else
				table.insert(res.ifaces, {name = iface, bandwidth = 100, enable = 1, track_ip = {}})
			end
		end
	end

	table.sort(res.main_iface)
	table.sort(res.ifaces, function(a, b) return a.name < b.name end)

	return res
end

local function save_mwan(config)
	local _ = config and save_safe("/etc/config/mwan.json", js.encode(config))
end

return {
	load = load_mwan,
	save = save_mwan,
}
