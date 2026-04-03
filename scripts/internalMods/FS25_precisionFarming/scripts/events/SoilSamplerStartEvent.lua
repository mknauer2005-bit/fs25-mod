-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for starting soil sample process
-- @category Events
SoilSamplerStartEvent = {}
local SoilSamplerStartEvent_mt = Class(SoilSamplerStartEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function SoilSamplerStartEvent.emptyNew()
    local self = Event.new(SoilSamplerStartEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function SoilSamplerStartEvent.new(object)
    local self = SoilSamplerStartEvent.emptyNew()
    self.object = object
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function SoilSamplerStartEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function SoilSamplerStartEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
end


---Run action on receiving side
-- @param Connection connection connection
function SoilSamplerStartEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    if self.object ~= nil and self.object:getIsSynchronized() then
        self.object:startSoilSampling(true)
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table object object
-- @param boolean noEventSend no event send
function SoilSamplerStartEvent.sendEvent(object, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SoilSamplerStartEvent.new(object), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(SoilSamplerStartEvent.new(object))
        end
    end
end
