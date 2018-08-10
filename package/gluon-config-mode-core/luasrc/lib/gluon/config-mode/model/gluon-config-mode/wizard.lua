local util = require "gluon.util"
local uci = require("simple-uci").cursor()


local wizard = {}
for _, entry in ipairs(util.glob('/lib/gluon/config-mode/wizard/*')) do
	local f = assert(loadfile(entry))
	setfenv(f, getfenv())
	local w = f()
	table.insert(wizard, w)
end

local f = Form(translate("Welcome!"))

f.submit = translate('Save & Restart')
f.reset = false

local s = f:section(Section)
s.template = "wizard/welcome"
s.package = "gluon-config-mode-core"

local commit = {'gluon-setup-mode'}
local run = {}

for _, w in ipairs(wizard) do
	for _, c in ipairs(w(f, uci) or {}) do
		if type(c) == 'string' then
			if not util.contains(commit, c) then
				table.insert(commit, c)
			end
		elseif type(c) == 'function' then
			table.insert(run, c)
		else
			error('invalid wizard module return')
		end
	end
end

local html = [[
		<div class="gluon-page-actions"><input class="gluon-button gluon-button-submit" value="Save" type="submit" onclick="return no_reboot()" /></div>
		<script type="text/javascript">
			setInterval(function() {
				document.getElementById("value-id.1.9.restart").style.display='none'
			}, 100);
			function no_reboot(){
				document.getElementById("id.1.9.restart").checked = "";
				return true;
			}
		</script>
]]

local s = f:section(Section, nil, html)
local restart = s:option(Flag, "restart", translate("Restart the node when saved"))
restart.default = true

function f:write()
	local fcntl = require 'posix.fcntl'
	local unistd = require 'posix.unistd'

	uci:set("gluon-setup-mode", uci:get_first("gluon-setup-mode", "setup_mode"), "configured", true)

	for _, c in ipairs(commit) do
		uci:commit(c)
	end
	for _, r in ipairs(run) do
		r()
	end

	f.template = "wizard/reboot"
	f.package = "gluon-config-mode-core"

	if unistd.fork() == 0 then
		-- Replace stdout with /dev/null
		local null = fcntl.open('/dev/null', fcntl.O_WRONLY)
		unistd.dup2(null, unistd.STDOUT_FILENO)

		-- Sleep a little so the browser can fetch everything required to
		-- display the reboot page, then reboot the device.
		unistd.sleep(1)
		
		-- TODO: WIP: this doesn't correctly check the state of the checkbox:
		if restart then
			f.hidenav = true
			unistd.execp('reboot', {[0] = 'reboot'})
		end
	end
end

return f
