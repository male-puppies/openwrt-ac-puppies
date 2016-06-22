local js = require("cjson.safe")
local template = require("sync.template")

local user_sync
local function sync(action, init) 
	if init then
		user_sync = template.new("user", "username") 
		return user_sync:sync(action, init)
	end

	return user_sync:sync(action)
end 

return {sync = sync}
