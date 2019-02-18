#!/usr/bin/lua

local unistd = require 'posix.unistd'
local uci = require("simple-uci").cursor()
local util = require 'gluon.util'
local site = require 'gluon.site'

-- -------------
-- safety checks
-- -------------

-- TODO:
-- pgrep -f autoupdater >/dev/null && safety_exit 'autoupdater running'

function safety_exit(t)
  io.write(t .. ", exiting with error code 2")
  os.exit(2)
end

function shell_exec(command)
  local file = assert(io.popen(command, 'r'))
  local output = file:read('*all')
  file:close()
  return output
end

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

local UT = util.get_uptime()
if UT < 60 then
  safety_exit('less than one minute')
end

local phy
uci:foreach('wireless', 'wifi-device', function(config)
  phy = util.find_phy(config)
  if not phy then
    safety_exit('no hostapd-phy')
  end
end)

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end
dump(phy); os.exit()

-- only once every timeframe minutes the SSID will change to the Offline-SSID
-- (set to 1 minute to change immediately every time the router gets offline)
local MINUTES = uci:get('ssid-changer', 'settings', 'switch_timeframe') or 30

-- the first few minutes directly after reboot within which an Offline-SSID always may be activated
-- (must be <= switch_timeframe)
local FIRST = uci:get('ssid-changer', 'settings', 'first') or 5

-- the Offline-SSID will start with this prefix use something short to leave space for the nodename
-- (no '~' allowed!)
local PREFIX = uci:get('ssid-changer', 'settings', 'prefix') or 'FF_Offline_'

local DISABLED = '0'
if uci:get('ssid-changer', 'settings', 'enabled') then 
  DISABLED ='1'
end

-- generate the ssid with either 'nodename', 'mac' or to use only the prefix set to 'none'
local SETTINGS_SUFFIX = uci:get('ssid-changer', 'settings', 'suffix') or 'nodename'

local SUFFIX
if SETTINGS_SUFFIX == 'nodename' then
  local pretty_hostname = require 'pretty_hostname'
  SUFFIX = pretty_hostname.get(uci)
  -- 32 would be possible as well
  if ( string.len(SUFFIX) > 30 - string.len(PREFIX) ) then
    -- calculate the length of the first part of the node identifier in the offline-ssid
    local HALF = math.floor((28 - string.len(PREFIX) ) / 2)
    -- jump to this charakter for the last part of the name
    local SKIP = string.len(SUFFIX) - HALF
    -- use the first and last part of the nodename for nodes with long name
    SUFFIX =string.sub(SUFFIX,0,HALF) .. '...' .. string.sub(SUFFIX, SKIP)
  end
elseif SETTINGS_SUFFIX == 'mac' then
  SUFFIX = util.get_wlan_mac(uci, radio, index, 2)
  if not macaddr then
    return
  end
else
  -- 'none'
  local SUFFIX=''
end
local OFFLINE_SSID=PREFIX .. SUFFIX

-- get all SSIDs (replace \' with TICX and back to keep a possible tic in an SSID)
ONLINE_SSIDs = shell_exec('uci show | grep wireless.client_radio[0-9]\.'
  .. '| grep ssid | awk -F \'=\'  \'{print $2}\'') .. " "  or "~FREIFUNK~"
-- set a default if for whatever reason ONLINE_SSIDs is NULL
-- TODO: | sed "s/\\\'/TICX/g" | tr \' \~ | sed "s/TICX/\\\'/g" 

-- temp file to count the offline incidents during switch_timeframe
local TMP='/tmp/ssid-changer-count'
local OFF_COUNT='0'
if not file_exists(TMP) then 
  local f = io.open(TMP, 'w+')
  f:write('0')
else
  OFF_COUNT = tonumber(util.readfile(TMP))
end

-- if TQ_LIMIT_ENABLED is true, the offline ssid will only be set if there is no gateway reacheable
-- upper and lower limit to turn the offline_ssid on and off
-- in-between these two values the SSID will never be changed to preven it from toggeling every Minute.
local TQ_LIMIT_ENABLED = uci:get('ssid-changer', 'settings', 'tq_limit_enabled') or '0'

local CHECK
if ( TQ_LIMIT_ENABLED == 1 ) then
  --  upper limit, above that the online SSID will be used
  local TQ_LIMIT_MAX = uci:get('ssid-changer', 'settings', 'tq_limit_max') or '45'
  --  lower limit, below that the offline SSID will be used
  local TQ_LIMIT_MIN = uci:get('ssid-changer', 'settings', 'tq_limit_min') or '35'
  -- grep the connection quality of the currently used gateway
  local GATEWAY_TQ=shell_exec('batctl gwl | grep -e "^=>" -e "^\*" | awk -F \'[()]\' \'{print $2}\' | tr -d " "')
  if ( GATEWAY_TQ == '' ) then
    -- there is no gateway
    local GATEWAY_TQ = 0
  end
  
  local MSG="TQ is " .. GATEWAY_TQ

  if ( GATEWAY_TQ >= TQ_LIMIT_MAX ) then
    CHECK = 1
  elseif ( GATEWAY_TQ < TQ_LIMIT_MIN ) then
    CHECK = 0
  else
    -- this is just get a clean run if we are in-between the grace periode
    print("TQ is " .. GATEWAY_TQ .. ", do nothing")
    os.exit(0)
  end
else
  local MSG=""
  CHECK=shell_exec('batctl gwl -H|grep -v "gateways in range"|wc -l')
end

local UP = UT / 60
local M = UP % MINUTES

local HUP_NEEDED = 0

if CHECK > 0 or DISABLED == '1' then
  print("node is online")
  local LOOP=1
  -- check status for all physical devices
  -- TODO: real loop over phy
  for HOSTAPD in phy do
    ONLINE_SSID=shell_exec('echo ' .. ONLINE_SSIDs .. ' | awk -F \'~\' -v l=$((LOOP*2)) \'{print $l}\'')
    LOOP = LOOP + 1
    CURRENT_SSID=shell_exec('grep "^ssid=$ONLINE_SSID" $HOSTAPD | cut -d"=" -f2)"')
    if CURRENT_SSID == ONLINE_SSID then
      print("SSID $CURRENT_SSID is correct, nothing to do")
      break
    end
    CURRENT_SSID=shell_exec('grep "^ssid=' .. OFFLINE_SSID .. '" ' .. HOSTAPD .. ' | cut -d"=" -f2)"')
    if CURRENT_SSID == OFFLINE_SSID then
      -- set online
      shell_exec('logger -s -t "gluon-ssid-changer" -p 5 ' .. MSG .. '"SSID is ' .. CURRENT_SSID .. ', change to ' .. ONLINE_SSID .. '"')
      shell_exec('sed -i "s~^ssid=' .. CURRENT_SSID .. '~ssid=' .. ONLINE_SSID .. '~" ' .. HOSTAPD .. '')
      -- HUP here would be to early for dualband devices
      HUP_NEEDED=1
    else
      shell_exec('logger -s -t "gluon-ssid-changer" -p 5 "could not set to online state: did neither find SSID ' .. ONLINE_SSID .. ' nor ' .. OFFLINE_SSID .. '. Please reboot"')
    end
  end
elseif CHECK == 0 then
  print("node is considered offline")
  if UP < FIRST or M == 0 then
    -- set SSID offline, only if uptime is less than FIRST or exactly a multiplicative of switch_timeframe
    if UP < FIRST then 
      T=FIRST
    else
      T=MINUTES
    end
    -- print("Minute M, check if OFF_COUNT is more than half of " .. T )
    if OFF_COUNT >= T / 2 then
      -- node was offline more times than half of switch_timeframe (or than FIRST)
      LOOP=1
      -- TODO: real loop over phy
      for HOSTAPD in phy do
        ONLINE_SSID=shell_exec(ONLINE_SSIDs .. ' | awk -F \'~\' -v l=' .. (LOOP*2) .. ' \'{print $l}')
        LOOP = LOOP + 1
        CURRENT_SSID=shell_exec('grep "^ssid=' .. OFFLINE_SSID .. '" ' .. HOSTAPD .. ' | cut -d"=" -f2)"')
        if CURRENT_SSID == OFFLINE_SSID then
          print("SSID ' .. CURRENT_SSID .. ' is correct, nothing to do")
          break
        end
        CURRENT_SSID=shell_exec('grep "^ssid=' .. ONLINE_SSID .. '" ' .. HOSTAPD .. ' | cut -d"=" -f2)"')
        if CURRENT_SSID == ONLINE_SSID then
          -- set offline
          shell_exec('logger -s -t "gluon-ssid-changer" -p 5 ' .. MSG .. '"' .. OFF_COUNT .. ' times offline, SSID is ' .. CURRENT_SSID .. ', change to ' .. OFFLINE_SSID .. '"')
          shell_exec('sed -i "s~^ssid=' .. ONLINE_SSID .. '~ssid=' .. OFFLINE_SSID .. '~" ' .. HOSTAPD .. '')
          HUP_NEEDED=1
        else
          shell_exec('logger -s -t "gluon-ssid-changer" -p 5 "could not set to offline state: did neither endnd SSID ' .. ONLINE_SSID .. ' nor ' .. OFFLINE_SSID .. '. Please reboot"')
        end
      end
    end
    -- else print("Minute ' .. M .. ', just count ' .. OFF_COUNT .. '")
  end
  
  local f = io.open(TMP, 'w+')
  f:write(OFF_COUNT + 1)
end

if HUP_NEEDED == 1 then
  -- send HUP to all hostapd to load the new SSID
  shell_exec('killall -HUP hostapd')
  HUP_NEEDED=0
  print("HUP!")
end

if M == 0 then
  -- set counter to 0 if the timeframe is over
  local f = io.open(TMP, 'w+')
  f:write('0')
end
