-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event to sync the current mount type of a vehicle
-- @category Events
MountableSetMountTypeEvent = {}
local MountableSetMountTypeEvent_mt = Class(MountableSetMountTypeEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function MountableSetMountTypeEvent.emptyNew()
    local self = Event.new(MountableSetMountTypeEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
-- @param boolean mountType use mower windrow drop areas
function MountableSetMountTypeEvent.new(object, mountType, mountObject)
    local self = MountableSetMountTypeEvent.emptyNew()
    self.object = object
    self.mountType = mountType
    self.mountObject = mountObject
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function MountableSetMountTypeEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self.mountType = streamReadUIntN(streamId, MountableObject.MOUNT_TYPE_SEND_NUM_BITS)

    if streamReadBool(streamId) then
        self.mountObject = NetworkUtil.readNodeObject(streamId)
    end

    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function MountableSetMountTypeEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
    streamWriteUIntN(streamId, self.mountType, MountableObject.MOUNT_TYPE_SEND_NUM_BITS)

    if streamWriteBool(streamId, self.mountObject ~= nil) then
        NetworkUtil.writeNodeObject(streamId, self.mountObject)
    end
end


---Run action on receiving side
-- @param Connection connection connection
function MountableSetMountTypeEvent:run(connection)
    if self.object ~= nil and self.object:getIsSynchronized() then
        -- only broadcast if we (still) have a valid object on the server and it's not deleted already
        if not connection:getIsServer() then
            g_server:broadcastEvent(self, false, connection, self.object)
        end

        self.object:setDynamicMountType(self.mountType, self.mountObject, true)
    end
end


---Broadcast event from server to all clients, if called on client call function on server and broadcast it to all clients
-- @param table vehicle vehicle
-- @param boolean mountType use mower windrow drop areas
-- @param boolean noEventSend no event send
function MountableSetMountTypeEvent.sendEvent(vehicle, mountType, mountObject, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(MountableSetMountTypeEvent.new(vehicle, mountType, mountObject), nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(MountableSetMountTypeEvent.new(vehicle, mountType, mountObject))
        end
    end
end
