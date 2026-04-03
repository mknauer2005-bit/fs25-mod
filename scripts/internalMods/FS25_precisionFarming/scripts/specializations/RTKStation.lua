-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---Specialization for placeable RTK stations
-- @category Specializations
RTKStation = {}


---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function RTKStation.prerequisitesPresent(specializations)
    return true
end


---
function RTKStation.registerFunctions(placeableType)
end


---
function RTKStation.registerOverwrittenFunctions(placeableType)
end


---
function RTKStation.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", RTKStation)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", RTKStation)
end


---
function RTKStation.registerXMLPaths(schema, basePath)
end


---
function RTKStation:onFinalizePlacement(savegame)
    if g_precisionFarming ~= nil then
        g_precisionFarming.aiExtension:registerRTKStation(self)
    end
end


---
function RTKStation:onDelete()
    if g_precisionFarming ~= nil then
        g_precisionFarming.aiExtension:unregisterRTKStation(self)
    end
end
