-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for sync of spray amount and automatic state
-- @category Events
ExtendedSprayerAmountEvent = {}
local ExtendedSprayerAmountEvent_mt = Class(ExtendedSprayerAmountEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function ExtendedSprayerAmountEvent.emptyNew()
    local self = Event.new(ExtendedSprayerAmountEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
-- @param boolean automaticMode automaticMode
-- @param integer manualValue manualValuemanualValue
function ExtendedSprayerAmountEvent.new(object, automaticMode, manualValue)
    local self = ExtendedSprayerAmountEvent.emptyNew()
    self.object = object
    self.automaticMode = automaticMode
    self.manualValue = manualValue
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function ExtendedSprayerAmountEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.automaticMode = streamReadBool(streamId)
    if not self.automaticMode then
        self.manualValue = streamReadUIntN(streamId, NitrogenMap.NUM_BITS)
    end

    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function ExtendedSprayerAmountEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    if not streamWriteBool(streamId, self.automaticMode) then
        streamWriteUIntN(streamId, self.manualValue, NitrogenMap.NUM_BITS)
    end
end


---Run action on receiving side
-- @param Connection connection connection
function ExtendedSprayerAmountEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    if self.object ~= nil and self.object:getIsSynchronized() then
        self.object:setSprayAmountAutoMode(self.automaticMode, true)
        if not self.automaticMode then
            self.object:setSprayAmountManualValue(self.manualValue, true)
        end
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table object object
-- @param boolean noEventSend no event send
function ExtendedSprayerAmountEvent.sendEvent(object, automaticMode, manualValue, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(ExtendedSprayerAmountEvent.new(object, automaticMode, manualValue), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(ExtendedSprayerAmountEvent.new(object, automaticMode, manualValue))
        end
    end
end
