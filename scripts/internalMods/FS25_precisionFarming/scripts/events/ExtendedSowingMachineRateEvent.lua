-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for sync of seed rate
-- @category Events
ExtendedSowingMachineRateEvent = {}
local ExtendedSowingMachineRateEvent_mt = Class(ExtendedSowingMachineRateEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function ExtendedSowingMachineRateEvent.emptyNew()
    local self = Event.new(ExtendedSowingMachineRateEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
-- @param boolean automaticMode automaticMode
-- @param integer manualValue manualValue
function ExtendedSowingMachineRateEvent.new(object, automaticMode, manualValue)
    local self = ExtendedSowingMachineRateEvent.emptyNew()
    self.object = object
    self.automaticMode = automaticMode
    self.manualValue = manualValue
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function ExtendedSowingMachineRateEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.automaticMode = streamReadBool(streamId)
    if not self.automaticMode then
        self.manualValue = streamReadUIntN(streamId, 2)
    end

    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function ExtendedSowingMachineRateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    if not streamWriteBool(streamId, self.automaticMode) then
        streamWriteUIntN(streamId, self.manualValue, 2)
    end
end


---Run action on receiving side
-- @param Connection connection connection
function ExtendedSowingMachineRateEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    if self.object ~= nil and self.object:getIsSynchronized() then
        self.object:setSeedRateAutoMode(self.automaticMode, true)
        if not self.automaticMode then
            self.object:setManualSeedRate(self.manualValue, true)
        end
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table object object
-- @param boolean noEventSend no event send
function ExtendedSowingMachineRateEvent.sendEvent(object, automaticMode, manualValue, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(ExtendedSowingMachineRateEvent.new(object, automaticMode, manualValue), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(ExtendedSowingMachineRateEvent.new(object, automaticMode, manualValue))
        end
    end
end
