-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for syncing the tramline settings from client to server
-- @category Events
TramlineMapSetEvent = {}
local TramlineMapSetEvent_mt = Class(TramlineMapSetEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function TramlineMapSetEvent.emptyNew()
    local self = Event.new(TramlineMapSetEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function TramlineMapSetEvent.new(farmlandId, workingWidth, workDirection, spacing, enabled, clearFruit)
    local self = TramlineMapSetEvent.emptyNew()
    self.farmlandId = farmlandId
    self.workingWidth = workingWidth
    self.workDirection = workDirection
    self.spacing = spacing
    self.enabled = enabled
    self.clearFruit = clearFruit

    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function TramlineMapSetEvent:readStream(streamId, connection)
    self.farmlandId = streamReadUIntN(streamId, g_farmlandManager.numberOfBits)
    self.workingWidth = streamReadFloat32(streamId)
    self.workDirection = streamReadFloat32(streamId)
    self.spacing = streamReadFloat32(streamId)
    self.enabled = streamReadBool(streamId)
    self.clearFruit = streamReadBool(streamId)

    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function TramlineMapSetEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.farmlandId, g_farmlandManager.numberOfBits)
    streamWriteFloat32(streamId, self.workingWidth)
    streamWriteFloat32(streamId, self.workDirection)
    streamWriteFloat32(streamId, self.spacing)
    streamWriteBool(streamId, self.enabled)
    streamWriteBool(streamId, self.clearFruit)
end


---Run action on receiving side
-- @param Connection connection connection
function TramlineMapSetEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, nil)
    end

    if g_precisionFarming ~= nil then
        if g_precisionFarming.tramlineMap ~= nil then
            g_precisionFarming.tramlineMap:setFarmlandTramlines(self.farmlandId, self.workingWidth, self.workDirection, self.spacing, self.enabled, self.clearFruit, true)
        end
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table object object
-- @param boolean noEventSend no event send
function TramlineMapSetEvent.sendEvent(farmlandId, workingWidth, workDirection, spacing, enabled, clearFruit, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(TramlineMapSetEvent.new(farmlandId, workingWidth, workDirection, spacing, enabled, clearFruit), nil, nil, nil)
        else
            g_client:getServerConnection():sendEvent(TramlineMapSetEvent.new(farmlandId, workingWidth, workDirection, spacing, enabled, clearFruit))
        end
    end
end
