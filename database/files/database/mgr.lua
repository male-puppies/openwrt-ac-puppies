local g_ins
local function new(conn, ud, cfg)
	g_ins = {conn = conn, ud = ud, cfg = cfg}
end

local function ins()
	return g_ins
end 

return {new = new, ins = ins}
