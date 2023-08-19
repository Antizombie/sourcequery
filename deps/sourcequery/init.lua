local Buffer = require('buffer').Buffer
local sock = require('dgram').createSocket('udp4')
local Emitter = require('core').Emitter
local string = string

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
local S2C_CHALLENGE = "\x41" -- Cервер может ответить клиенту вызовом с использованием S2C_CHALLENGE ('A' или 0x41) после, номер вызова, нужно повторить запрос с номером вызова.
local A2S_INFO_Response = "\x49"
local END_string = "\x00"

local ServerNil = {}
ServerNil.A2S_INFO = {
	["Header"] = "I",
	["Protocol"] = 0,
	["HostName"] = "Timeout Host",
	["Map"] = "None",
	["Folder"] = "None",
	["Game"] = "None",
	["ID"] = 0,
	["Players"] = 0,
	["MaxPlayers"] = 0,
	["Bots"] = 0,
	["ServerType"] = "d",
	["Environment"] = "l",
	["Visibility"] = 0,
	["VAC"] = 0,
	["Version"] = 0,
}

local function StopServer(force)
	sock:close()
end

local function ExtractPayload(sourcePackage)
	sourcePackage = Buffer:new(sourcePackage)
	local Header = sourcePackage:readInt32BE(1)
	if Header == -1 then
		return sourcePackage:toString(5)
	elseif Header == -2 then
		print("Ещё не реализовал ответ из нескольких пакетов")
	else
		print("В этом пакете нет корректного заголовка")
	end
end

local IS = {}

function IS:cfind()
	local index = string.find(self.value, "\x00", 1)
	if index then
		local cfind = string.sub(self.value, 1, index - 1)
		self.value = string.sub(self.value, index + 1)
		return cfind
	end
	return nil
end

function IS:cbyte()
	local cbyte = string.byte(self.value, 1)
	self.value = string.sub(self.value, 2)
	return cbyte
end

function IS:csub(finish)
	local csub = string.sub(self.value, 1, finish)
	self.value = string.sub(self.value, finish + 1)
	return csub
end

function IS:parseSignedInt16()
	local data = self.value
	local byte1 = string.byte(data, 1)
	local byte2 = string.byte(data, 2)
	local value = byte2 * 256 + byte1
	if value > 32767 then
		value = value - 65536
	end
	self.value = string.sub(data, 3)
	return value
end

local function createIS(str)
	local initializedString = { value = str or "" }
	setmetatable(initializedString, {
		__index = IS,
		__tostring = function(self)
			return self.value
		end,
		__concat = function(a, b)
			return tostring(a)..tostring(b)
		end

	})
	return initializedString
end

local function Parse_A2S_INFO(payload, Port, Host)
	local ServerTemp = ServerNil.A2S_INFO
	ServerTemp.Protocol = payload:cbyte()
	ServerTemp.HostName = payload:cfind()
	ServerTemp.Map = payload:cfind()
	ServerTemp.Folder = payload:cfind()
	ServerTemp.Game = payload:cfind()
	ServerTemp.ID = payload:parseSignedInt16()
	ServerTemp.Players = payload:cbyte()
	ServerTemp.MaxPlayers = payload:cbyte()
	ServerTemp.Bots = payload:cbyte()
	ServerTemp.ServerType = payload:csub(1)
	ServerTemp.Environment = payload:csub(1)
	ServerTemp.Visibility = payload:cbyte()
	ServerTemp.VAC = payload:cbyte()
	if ServerTemp.ID == 2400 then -- The Ship
		ServerTemp.GameMode = payload:csub(1)
		ServerTemp.WitnessCount = payload:csub(1)
		ServerTemp.WitnessTime = payload:csub(1)
	end
	ServerTemp.Version = payload:cfind()
	if #tostring(payload) > 0 then
		local EDF = payload:cbyte()
		if bit.band(EDF, 128) ~= 0 then
			ServerTemp.PORT = payload:parseSignedInt16()
		end
		if bit.band(EDF, 16) ~= 0 then
			payload:csub(9) -- Не допетрил как нормально вывести "long long" - 64 bit unsigned integer 
		end
		if bit.band(EDF, 64) ~= 0 then
			ServerTemp.SourceTVport = payload:parseSignedInt16()
			ServerTemp.SourceTVname = payload:cfind()
		end
		if bit.band(EDF, 32) ~= 0 then
			ServerTemp.Tags = payload:cfind()
		end
		if bit.band(EDF, 1) ~= 0 then
			payload:csub(9) -- Не допетрил как нормально вывести "long long" - 64 bit unsigned integer 
		end
	end
	return ServerTemp
end

local Servercallback = Emitter:extend()
function Servercallback:initialize(callback)
	if callback then
		self:on('message', callback)
	end
end

sock:on('message', function(data, rinfo)
	local Port = rinfo['port']
	local Host = rinfo['ip']
	local Payload = createIS(ExtractPayload(data))
	local Header = Payload:csub(1, 1)
	if Header == S2C_CHALLENGE then
		sock:send(SimplePacket..A2S_INFO..SourceEngineQuery..Payload, Port, Host)
		return
	end
	if Header == A2S_INFO_Response then
		local server = Parse_A2S_INFO(Payload)
		Servercallback:emit('message', server)
	end
end)

local function CreateServer(BindPort,BindIP)
	BindPort = BindPort or math.random(20000, 25000)
	BindIP = BindIP or "0.0.0.0"
	sock:bind(BindPort,BindIP)
end

local function SendServerQuery(Host, Port)
	Port = Port or 27015
	sock:send(SimplePacket..A2S_INFO..SourceEngineQuery, Port, Host)
end

return {
	CreateServer = CreateServer,
	SendServerQuery = SendServerQuery,
	StopServer = StopServer,
	Servercallback = Servercallback,
}
