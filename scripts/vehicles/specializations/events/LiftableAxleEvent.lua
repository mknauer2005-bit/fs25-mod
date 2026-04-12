-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for liftable axle state
-- @category Events
LiftableAxleEvent = {}
local LiftableAxleEvent_mt = Class(LiftableAxleEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function LiftableAxleEvent.emptyNew()
    local self = Event.new(LiftableAxleEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function LiftableAxleEvent.new(object, state, fixedHeight)
    local self = LiftableAxleEvent.emptyNew()

    self.object = object
    self.state = state
    self.fixedHeight = fixedHeight

    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function LiftableAxleEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.state = streamReadBool(streamId)

    if streamReadBool(streamId) then
        self.fixedHeight = streamReadFloat32(streamId)
    else
        self.fixedHeight = nil
    end

    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function LiftableAxleEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteBool(streamId, self.state)

    if streamWriteBool(streamId, self.fixedHeight ~= nil) then
        streamWriteFloat32(streamId, self.fixedHeight)
    end
end


---Run action on receiving side
-- @param Connection connection connection
function LiftableAxleEvent:run(connection)
    if self.object ~= nil and self.object:getIsSynchronized() then
        self.object:setLiftableAxleState(self.state, self.fixedHeight, nil, true)
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table object object
-- @param boolean isActive is active
-- @param boolean noEventSend no event send
function LiftableAxleEvent.sendEvent(object, state, fixedHeight, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(LiftableAxleEvent.new(object, state, fixedHeight), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(LiftableAxleEvent.new(object, state, fixedHeight))
        end
    end
end
