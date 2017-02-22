local uci = luci.model.uci.cursor()
local util = luci.util

local f, s, o
local config = 'fastd'
local groupname = 'n2n_vpn'
local vpnname = 'n2n_vpn'

function splitRemoteEntry(p)
	local host, port, x

	p = p:gsub("["..'"'.."]", '')

	x = p:find(" ") or (#p + 1)
	host = p:sub(1, x-1)

	p = p:sub(x+1)
	x = p:find(" ") or (#p + 1)
	port = p:sub(x+1)

	return host, port
end

function splitPeerString(p)
	local host, port, key, x

	x = p:find(':') or (#p + 1)
	host = p:sub(1,x-1)

	p = p:sub(x+1)
	x = p:find('/') or (#p + 1)
	port = p:sub(1,x-1)
	key = p:sub(x+1)

	return host, port, key
end

function getPeerStrings()
	peers = {}

	uci:foreach('fastd', 'peer',
	function(s)
		if s['group'] == groupname then
			local host, port = splitRemoteEntry(table.concat(s['remote']))
			peers[#peers+1] = host .. ':' .. port .. '/' .. s['key']
		end
	end
	)

	return peers
end


local f = SimpleForm('mesh_vpn', translate('Mesh VPN'))
f.template = "admin/expertmode"

local s = f:section(SimpleSection)

local o = s:option(Value, 'mode')
o.template = "gluon/cbi/mesh-vpn-fastd-mode"

local methods = uci:get('fastd', 'mesh_vpn', 'method')
if util.contains(methods, 'null') then
	o.default = 'performance'
else
	o.default = 'security'
end

s = f:section(SimpleSection, nil, translate('Your node can connect to other nodes directly. ' 
.. 'One of the participating nodes of a Node-to-Node connection has to be configured with a fixed fastd port.'
.. 'This port then has to be forwarded in the local home router which the node is using for Mesh VPN.'
))

o = s:option(Flag, "enabled", translate("Enabled"))
o.default = uci:get_bool(config, groupname, "enabled") and o.enabled or o.disabled
o.rmempty = false

o = s:option(DynamicList, "hostname", translate("Remote"), translate("Format") ..": HOSTNAME:PORT/KEY")
o:write(nil, getPeerStrings())
o:depends("enabled", '1')

o = s:option(Flag, "fixedport", translate("Fixed VPN Port"))
o.default = (uci:get(config, vpnname, "bind")) and o.enabled or o.disabled
o:depends("enabled", '1')
o.rmempty = false

p = uci:get(config, vpnname, "bind") or '0'
x = p:find(":") or (#p + 1)

o = s:option(Value, "localport", translate("Port"))
o.default = p:sub(x+1) or 10000
o.datatype = "uinteger"
o.rmempty = false
o:depends("fixedport", '1')

function f.handle(self, state, data)
	if state == FORM_VALID then
		local site = require 'gluon.site_config'

		local methods = {}
		if data.mode == 'performance' then
			table.insert(methods, 'null')
		end

		for _, method in ipairs(site.fastd_mesh_vpn.methods) do
			if method ~= 'null' then
				table.insert(methods, method)
			end
		end

		uci:set('fastd', 'mesh_vpn', 'method', methods)


		-- delete all existin p2p peers
		uci:foreach('fastd', 'peer',
		function(s)
			if s['group'] == groupname then
				uci:delete(config, s['.name'])
			end
		end
		)

		-- iterate over dynamic list if enabled
		if data.enabled == '1' and #data.hostname > 0 then
			for v,peer in pairs(data.hostname) do
				-- TODO: add sanity checks
				local host, port, key = splitPeerString(peer)

				-- hostname is cleaned to be valid as a section name
				uci:section(config, 'peer', groupname .. '_' .. host:gsub('%W',''),
				{
					net = vpnname,
					key = key,
					group = groupname,
					remote = { '"'..host..'"'..' port '..port },
					enabled = 1,
				}
				)
			end
		end

		uci:set(config, groupname, "enabled", data.enabled)

		if data.fixedport == '1' and data.localport and tonumber(data.localport) > 0 and tonumber(data.localport ) <= 65535 then
			uci:set(config, vpnname, 'bind', 'any:'..data.localport)
		else
			uci:delete(config, vpnname, 'bind')
		end

		uci:save("fastd")
		uci:commit("fastd")
	end
end

return f
