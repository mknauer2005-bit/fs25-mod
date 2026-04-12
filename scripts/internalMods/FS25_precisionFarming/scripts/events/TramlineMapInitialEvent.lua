-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for syncing the tramline settings from server to client on join
-- @category Events
TramlineMapInitialEvent = {}
local TramlineMapInitialEvent_mt = Class(TramlineMapInitialEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function TramlineMapInitialEvent.emptyNew()
    local self = Event.new(TramlineMapInitialEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function TramlineMapInitialEvent.new(farmlandTramlineStates)
    local self = TramlineMapInitialEvent.emptyNew()
    self.farmlandTramlineStates = farmlandTramlineStates

    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function TramlineMapInitialEvent:readStream(streamId, connection)
    self.farmlandTramlineStates = {}

    local numFarmlandsToReceive = streamReadUIntN(streamId, g_farmlandManager.numberOfBits)
    for i=1, numFarmlandsToReceive do
        local farmlandId = streamReadUIntN(streamId, g_farmlandManager.numberOfBits)

        local state = {}
        state.workingWidth = streamReadFloat32(streamId)
        state.workDirection = streamReadFloat32(streamId)
        state.spacing = streamReadFloat32(streamId)
        self.farmlandTramlineStates[farmlandId] = state
    end

    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function TramlineMapInitialEvent:writeStream(streamId, connection)
    local numFarmlandsToSend = table.size(self.farmlandTramlineStates)
    streamWriteUIntN(streamId, numFarmlandsToSend, g_farmlandManager.numberOfBits)

    for farmlandId, state in pairs(self.farmlandTramlineStates) do
        streamWriteUIntN(streamId, farmlandId, g_farmlandManager.numberOfBits)
        streamWriteFloat32(streamId, state.workingWidth)
        streamWriteFloat32(streamId, state.workDirection)
        streamWriteFloat32(streamId, state.spacing)
    end
end


---Run action on receiving side
-- @param Connection connection connection
function TramlineMapInitialEvent:run(connection)
    if g_precisionFarming ~= nil then
        if g_precisionFarming.tramlineMap ~= nil then
            g_precisionFarming.tramlineMap.farmlandTramlineStates = self.farmlandTramlineStates
        end
    end
end
