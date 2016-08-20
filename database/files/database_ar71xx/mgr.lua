local g_ins
local function new(conn, myconn, ud, cfg)
	g_ins = {conn = conn, myconn = myconn, ud = ud, cfg = cfg}
end

local function ins()
	return g_ins
end

return {new = new, ins = ins}
