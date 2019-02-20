local uci = require('simple-uci').cursor()
local util = require 'gluon.util'

local pkg_i18n = i18n 'gluon-web-offline-ssid'

local f = Form(pkg_i18n.translate('Offline-SSID'))

local s = f:section(Section, nil, pkg_i18n.translate(
	'Here you can enable to automatically change the SSID to the Offline-SSID '
	.. 'when the node has no connection to the selected gateway.'
))

local enabled = s:option(Flag, 'enabled', pkg_i18n.translate('Enabled'))
enabled.default = uci:get_bool('gluon-offline-ssid', 'settings', 'enabled')

function f:write()
	if enabled.data then
		uci:set('gluon-offline-ssid', 'settings', 'enabled', '1')
	else
		uci:set('gluon-offline-ssid', 'settings', 'enabled', '0')
	end

	uci:commit('gluon-offline-ssid')
end

return f
