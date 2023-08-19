local timer = require('timer')
local sourcequery = require("sourcequery2")

sourcequery.CreateServer(3177)

sourcequery.Servercallback:on('message', function(data, Host, Port)
	print('message',data , Host, Port)
end)

sourcequery.SendServerQuery("188.120.231.157", 27015)

timer.setInterval(5000, function()
	sourcequery.SendServerQuery("188.120.231.157", 27015)
end)
