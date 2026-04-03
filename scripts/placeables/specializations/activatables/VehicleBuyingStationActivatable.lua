-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---
VehicleBuyingStationActivatable = {}
local VehicleBuyingStationActivatable_mt = Class(VehicleBuyingStationActivatable)


---
function VehicleBuyingStationActivatable.new(placeable, callbackFunc, text)
    local self = setmetatable({}, VehicleBuyingStationActivatable_mt)

    self.placeable = placeable
    self.callbackFunc = callbackFunc
    self.activateText = text

    return self
end


---
function VehicleBuyingStationActivatable:getIsActivatable()
    return g_currentMission.accessHandler:canPlayerAccess(self.placeable)
end


---
function VehicleBuyingStationActivatable:run()
    self.callbackFunc()
end
