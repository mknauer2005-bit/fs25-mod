-- Optional bridge for map mods that use onCreate="modOnCreate.*"
-- Put this file in your map mod script folder and load it before map.i3d onCreate callbacks are evaluated.

local BRIDGE_LOG_PREFIX = "[GarageStorage][modOnCreateBridge]"

local function bridgeLog(message)
    print(string.format("%s %s", BRIDGE_LOG_PREFIX, tostring(message or "")))
end

modOnCreate = modOnCreate or {}
bridgeLog("Bridge loaded")

function modOnCreate.GarageStorage_onCreate(nodeId)
    bridgeLog("GarageStorage_onCreate called for nodeId=" .. tostring(nodeId))

    if GarageStorage_onCreate ~= nil then
        GarageStorage_onCreate(nodeId)
        bridgeLog("Forwarded call to GarageStorage_onCreate")
    else
        bridgeLog("GarageStorage_onCreate is nil; callback not forwarded")
    end
end

