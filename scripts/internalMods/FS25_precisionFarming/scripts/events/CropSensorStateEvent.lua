-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for setting the crop sensor active state
-- @category Events
CropSensorStateEvent = {}
local CropSensorStateEvent_mt = Class(CropSensorStateEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function CropSensorStateEvent.emptyNew()
    local self = Event.new(CropSensorStateEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
-- @param boolean state state
function CropSensorStateEvent.new(object, state)
    local self = CropSensorStateEvent.emptyNew()
    self.object = object
    self.state = state
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function CropSensorStateEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.state = streamReadBool(streamId)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function CropSensorStateEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.state)
end


---Run action on receiving side
-- @param Connection connection connection
function CropSensorStateEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end

    if self.object ~= nil and self.object:getIsSynchronized() then
        self.object:setCropSensorActive(self.state, true)
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table object object
-- @param boolean state state
-- @param boolean noEventSend no event send
function CropSensorStateEvent.sendEvent(object, state, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(CropSensorStateEvent.new(object, state), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(CropSensorStateEvent.new(object, state))
        end
    end
end
