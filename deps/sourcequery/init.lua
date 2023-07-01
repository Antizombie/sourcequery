local Buffer = require('buffer').Buffer
local dgram = require('dgram')
local sock = dgram.createSocket('udp4')
local PrintTable = require('PrintTable')

local SimplePacket = "\xFF\xFF\xFF\xFF"
local MultiPacket = "\xFF\xFF\xFF\xFE"
local SourceEngineQuery = "Source Engine Query\0"
--[[Requests
The server responds to 5 queries:]]
local A2S_INFO = "\x54" --'T' Basic information about the server.
local A2S_PLAYER = "\x55" --'U' Details about each player on the server.
local A2S_RULES = "\x56" --'V' The rules the server is using.
local A2A_PING = "\x69" --'i' Ping the server. (DEPRECATED)
local A2S_SERVERQUERY_GETCHALLENGE = "\x57" --'W' Returns a challenge number for use in the player and rules query. (DEPRECATED)

local Querys = 0

local ServersCache = {}

local function StopServer(force)
	if force or Querys == 0 then
		sock:close()
	end
end

local function CreateServer(BindPort,BindIP,server1)
	BindPort = BindPort or math.random(20000,25000)
	BindIP = BindIP or "0.0.0.0"
	sock:bind(BindPort,BindIP)
	sock:setTimeout(1000)

	sock:on('message', function(data, rinfo)
		local Port = rinfo['port']
		local Host = rinfo['ip']
		ServersCache[Host..":"..Port] = nil
		Querys = Querys - 1
		if #data == 9 and string.match(data, SimplePacket..".....") then
			local datasend = SimplePacket..A2S_INFO..SourceEngineQuery..string.sub(data, 6, 9)
			sock:send(datasend , Port, Host)
			Querys = Querys + 1
			ServersCache[Host..":"..Port] = {}
		elseif #data > 9 then
			local server = {}
			server[Host..":"..Port]={}
			local index3 = 1
			for i=1,4 do
				index, index2 = string.find(data,"[%z]+",index3)
					if index == nil then break end
				index3 = index2 + 1
			end
			server[Host..":"..Port]["Header"]=string.sub(data,5,5)
			server[Host..":"..Port]["Protocol"]=string.byte(string.sub(data,6,6))

			data2 = string.sub(data, 7,  index2-1)
			for w in data2:gmatch("([^%z]+)") do
				server[Host..":"..Port][#server[Host..":"..Port] + 1] = w 
			end
			local bs = Buffer:new( string.sub(data,index2+3,index2+5))

			for i=1,bs.length do
				Newst = #server[Host..":"..Port] + 1
				server[Host..":"..Port][Newst] = bs[i]
			end

			local NameDate = {[1]="HostName",[2]="Map",[3]="Folder",[4]="Game",[5]="Players",[6]="MaxPlayers",[7]="Bots"}

			for i = 1,#server[Host..":"..Port] do 
				server[Host..":"..Port][ NameDate[i] ] = server[Host..":"..Port][i]
				server[Host..":"..Port][i] = nil
			end
			server1(server)
		end
	end)
	sock:on('timeout', function()
		Querys = Querys - 1
		server1(ServersCache)
	end)
end

local function SendServerQuery(Host, Port)
	Port = Port or 27015
	sock:send(SimplePacket..A2S_INFO..SourceEngineQuery, Port, Host)
	ServersCache[Host..":"..Port] = {}
	ServersCache[Host..":"..Port]["Header"] = "I"
	ServersCache[Host..":"..Port]["Protocol"] = 0
	ServersCache[Host..":"..Port]["HostName"] = "Timeout Host"
	ServersCache[Host..":"..Port]["Map"] = "None"
	ServersCache[Host..":"..Port]["Folder"] = "None"
	ServersCache[Host..":"..Port]["Game"] = "None"
	ServersCache[Host..":"..Port]["Players"] = 0
	ServersCache[Host..":"..Port]["MaxPlayers"] = 0
	ServersCache[Host..":"..Port]["Bots"] = 0
	Querys = Querys + 1
end


return {
  CreateServer = CreateServer,
  SendServerQuery = SendServerQuery,
  StopServer = StopServer,
}