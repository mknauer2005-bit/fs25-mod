-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for sending taken soil samples for analysation
-- @category Events
SoilSamplerSendEvent = {}
local SoilSamplerSendEvent_mt = Class(SoilSamplerSendEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function SoilSamplerSendEvent.emptyNew()
    local self = Event.new(SoilSamplerSendEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function SoilSamplerSendEvent.new(object)
    local self = SoilSamplerSendEvent.emptyNew()
    self.object = object
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function SoilSamplerSendEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function SoilSamplerSendEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
end


---Run action on receiving side
-- @param Connection connection connection
function SoilSamplerSendEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    if self.object ~= nil and self.object:getIsSynchronized() then
        self.object:sendTakenSoilSamples(true)
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table object object
-- @param boolean noEventSend no event send
function SoilSamplerSendEvent.sendEvent(object, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SoilSamplerSendEvent.new(object), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(SoilSamplerSendEvent.new(object))
        end
    end
end
