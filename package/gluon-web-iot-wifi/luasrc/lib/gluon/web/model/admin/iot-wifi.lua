local uci = require("simple-uci").cursor()
local util = require 'gluon.util'

-- where to read the configuration from
local primary_iface = 'wan_radio2'

local f = Form(translate("IoT WLAN"))

local s = f:section(Section, nil, translate(
	'Your node can additionally create a separate WLAN that has neither access to '
	.. 'the internet nor to your private WLAN. This is useful to serve as a local '
	.. 'Network for IoT devices. This feature is completely independent of '
	.. 'the mesh functionality. Please note that the IoT WLAN and meshing on the '
	.. 'WAN interface should not be enabled at the same time.'
))

local iot_enabled = s:option(Flag, "iot_enabled", translate("Enabled"))
iot_enabled.default = uci:get('wireless', primary_iface) and not uci:get_bool('wireless', primary_iface, "disabled")

local iot_ssid = s:option(Value, "iot_ssid", translate("Name (SSID)"))
iot_ssid:depends(iot_enabled, true)
iot_ssid.datatype = "maxlength(32)"
iot_ssid.default = uci:get('wireless', primary_iface, "iot_ssid")

local iot_key = s:option(Value, "iot_key", translate("Key"), translate("8-63 characters"))
iot_key:depends(iot_enabled, true)
iot_key.datatype = "wpakey"
iot_key.default = uci:get('wireless', primary_iface, "iot_key")

function f:write()
	util.iterate_radios(uci, function(radio, index)
		local name   = "wan_" .. radio

		if iot_enabled.data then
			local macaddr = util.get_wlan_mac(uci, radio, index, 5)

			uci:section('wireless', "iot-iface", name, {
				device     = radio,
				network    = "wan",
				mode       = 'ap',
				encryption = 'psk2',
				ssid       = iot_ssid.data,
				key        = iot_key.data,
				macaddr    = macaddr,
				disabled   = false,
			})
		else
			uci:set('wireless', name, "disabled", true)
		end
	end)

	uci:commit('wireless')
end

return f
