--[[
Copyright 2014 Nils Schneider <nils@nilsschneider.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0
]]--

local uci = require("simple-uci").cursor()
local sysconfig = require 'gluon.sysconfig'
local util = require 'gluon.util'

local wan = uci:get_all("network", "wan")
local wan6 = uci:get_all("network", "wan6")
local dns_static = uci:get_first("gluon-wan-dnsmasq", "static")

local f = Form(translate("WAN connection"))

local s = f:section(Section)

local ipv4 = s:option(ListValue, "ipv4", translate("IPv4"))
ipv4:value("dhcp", translate("Automatic (DHCP)"))
ipv4:value("static", translate("Static"))
ipv4:value("none", translate("Disabled"))
ipv4.default = wan.proto

local ipv4_addr = s:option(Value, "ipv4_addr", translate("IP address"))
ipv4_addr:depends(ipv4, "static")
ipv4_addr.default = wan.ipaddr
ipv4_addr.datatype = "ip4addr"

local ipv4_netmask = s:option(Value, "ipv4_netmask", translate("Netmask"))
ipv4_netmask:depends(ipv4, "static")
ipv4_netmask.default = wan.netmask or "255.255.255.0"
ipv4_netmask.datatype = "ip4addr"

local ipv4_gateway = s:option(Value, "ipv4_gateway", translate("Gateway"))
ipv4_gateway:depends(ipv4, "static")
ipv4_gateway.default = wan.gateway
ipv4_gateway.datatype = "ip4addr"


s = f:section(Section)

local ipv6 = s:option(ListValue, "ipv6", translate("IPv6"))
ipv6:value("dhcpv6", translate("Automatic (RA/DHCPv6)"))
ipv6:value("static", translate("Static"))
ipv6:value("none", translate("Disabled"))
ipv6.default = wan6.proto

local ipv6_addr = s:option(Value, "ipv6_addr", translate("IP address"))
ipv6_addr:depends(ipv6, "static")
ipv6_addr.default = wan6.ip6addr
ipv6_addr.datatype = "ip6addr"

local ipv6_gateway = s:option(Value, "ipv6_gateway", translate("Gateway"))
ipv6_gateway:depends(ipv6, "static")
ipv6_gateway.default = wan6.ip6gw
ipv6_gateway.datatype = "ip6addr"

if dns_static then
	s = f:section(Section)

	local dns = s:option(DynamicList, "dns", translate("Static DNS servers"))
	dns.default = uci:get_list("gluon-wan-dnsmasq", dns_static, "server")
	dns.datatype = "ipaddr"
	dns.optional = true

	function dns:write(data)
		uci:set_list("gluon-wan-dnsmasq", dns_static, "server", data)
		uci:commit("gluon-wan-dnsmasq")
	end
end

s = f:section(Section)

local mesh_wan = s:option(Flag, "mesh_wan", translate("Enable meshing on the WAN interface"))
mesh_wan.default = not uci:get_bool("network", "mesh_wan", "disabled")

function mesh_wan:write(data)
	uci:set("network", "mesh_wan", "disabled", not data)
end

if sysconfig.lan_ifname then
	s = f:section(Section)

	local mesh_lan = s:option(Flag, "mesh_lan", translate("Enable meshing on the LAN interface"))
	mesh_lan.default = not uci:get_bool("network", "mesh_lan", "disabled")

	function mesh_lan:write(data)
		uci:set("network", "mesh_lan", "disabled", not data)

		local interfaces = uci:get_list("network", "client", "ifname")

		for lanif in sysconfig.lan_ifname:gmatch('%S+') do
			if data then
				util.remove_from_set(interfaces, lanif)
			else
				util.add_to_set(interfaces, lanif)
			end
		end

		uci:set_list("network", "client", "ifname", interfaces)
	end
end

local section
uci:foreach("system", "gpio_switch", function(si)
	if si[".name"]:match("poe") then
		if not section then
			section = f:section(Section)
		end

		local port = si.name:match("^PoE Power Port(%d*)$")
		local name
		if port then
			name = translatef("Enable PoE Power Port %s", port)
		else
			name = translate("Enable " .. si.name)
		end
		local poe = section:option(Flag, si[".name"], name)
		poe.default = uci:get_bool("system", si[".name"], "value")

		function poe:write(data)
			uci:set("system", si[".name"], "value", data)
		end
	end
end)

function f:write()
	uci:set("network", "wan", "proto", ipv4.data)
	if ipv4.data == "static" then
		uci:set("network", "wan", "ipaddr", ipv4_addr.data)
		uci:set("network", "wan", "netmask", ipv4_netmask.data)
		uci:set("network", "wan", "gateway", ipv4_gateway.data)
	else
		uci:delete("network", "wan", "ipaddr")
		uci:delete("network", "wan", "netmask")
		uci:delete("network", "wan", "gateway")
	end

	uci:set("network", "wan6", "proto", ipv6.data)
	if ipv6.data == "static" then
		uci:set("network", "wan6", "ip6addr", ipv6_addr.data)
		uci:set("network", "wan6", "ip6gw", ipv6_gateway.data)
	else
		uci:delete("network", "wan6", "ip6addr")
		uci:delete("network", "wan6", "ip6gw")
	end


	uci:commit("network")
	uci:commit('system')
end

return f
