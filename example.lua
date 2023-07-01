local sourcequery = require("sourcequery")
local timer = require('timer')

local servers = {}

local function ServerListUpdate(server)
	for k, v in pairs( server ) do
		servers[k]=v
	end
end

sourcequery.CreateServer(nil, nil, ServerListUpdate)

sourcequery.SendServerQuery("188.120.231.157", 27015)
sourcequery.SendServerQuery("188.120.231.157", 27016)
sourcequery.SendServerQuery("188.120.231.157", 27017)

timer.setInterval(10000, function()
	sourcequery.SendServerQuery("188.120.231.157", 27015)
	sourcequery.SendServerQuery("188.120.231.157", 27016)
	sourcequery.SendServerQuery("188.120.231.157", 27017)
end)