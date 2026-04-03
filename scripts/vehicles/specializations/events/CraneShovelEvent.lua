-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for crane shovel state
-- @category Events
CraneShovelEvent = {}
local CraneShovelEvent_mt = Class(CraneShovelEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function CraneShovelEvent.emptyNew()
    local self = Event.new(CraneShovelEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function CraneShovelEvent.new(object, state)
    local self = CraneShovelEvent.emptyNew()

    self.object = object
    self.state = state

    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function CraneShovelEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.state = streamReadBool(streamId)

    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function CraneShovelEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.state)
end


---Run action on receiving side
-- @param Connection connection connection
function CraneShovelEvent:run(connection)
    if self.object ~= nil and self.object:getIsSynchronized() then
        self.object:setCraneShovelState(self.state, nil, true)
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table object object
-- @param boolean isActive is active
-- @param boolean noEventSend no event send
function CraneShovelEvent.sendEvent(object, state, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(CraneShovelEvent.new(object, state), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(CraneShovelEvent.new(object, state))
        end
    end
end
