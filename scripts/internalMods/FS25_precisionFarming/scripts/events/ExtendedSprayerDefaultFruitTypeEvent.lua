-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for sync of spray amount and automatic state
-- @category Events
ExtendedSprayerDefaultFruitTypeEvent = {}
local ExtendedSprayerDefaultFruitTypeEvent_mt = Class(ExtendedSprayerDefaultFruitTypeEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function ExtendedSprayerDefaultFruitTypeEvent.emptyNew()
    local self = Event.new(ExtendedSprayerDefaultFruitTypeEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
-- @param integer fruitRequirementIndex fruitRequirementIndex
function ExtendedSprayerDefaultFruitTypeEvent.new(object, fruitRequirementIndex)
    local self = ExtendedSprayerDefaultFruitTypeEvent.emptyNew()
    self.object = object
    self.fruitRequirementIndex = fruitRequirementIndex
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function ExtendedSprayerDefaultFruitTypeEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.fruitRequirementIndex = streamReadUIntN(streamId, FruitTypeManager.SEND_NUM_BITS)

    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function ExtendedSprayerDefaultFruitTypeEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.fruitRequirementIndex, FruitTypeManager.SEND_NUM_BITS)
end


---Run action on receiving side
-- @param Connection connection connection
function ExtendedSprayerDefaultFruitTypeEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    if self.object ~= nil and self.object:getIsSynchronized() then
        self.object:setSprayAmountDefaultFruitRequirementIndex(self.fruitRequirementIndex, true)
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table object object
-- @param boolean noEventSend no event send
function ExtendedSprayerDefaultFruitTypeEvent.sendEvent(object, fruitRequirementIndex, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(ExtendedSprayerDefaultFruitTypeEvent.new(object, fruitRequirementIndex), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(ExtendedSprayerDefaultFruitTypeEvent.new(object, fruitRequirementIndex))
        end
    end
end
