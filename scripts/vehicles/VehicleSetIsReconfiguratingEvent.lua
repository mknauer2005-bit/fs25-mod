-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for set isRegonfigurating on vehicles
-- @category Events
VehicleSetIsReconfiguratingEvent = {}
local VehicleSetIsReconfiguratingEvent_mt = Class(VehicleSetIsReconfiguratingEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function VehicleSetIsReconfiguratingEvent.emptyNew()
    local self = Event.new(VehicleSetIsReconfiguratingEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
-- @param integer state state
function VehicleSetIsReconfiguratingEvent.new(object)
    local self = VehicleSetIsReconfiguratingEvent.emptyNew()
    self.object = object
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function VehicleSetIsReconfiguratingEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    if self.object ~= nil and self.object:getIsSynchronized() then
        self.object.isReconfigurating = true
    end
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function VehicleSetIsReconfiguratingEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
end
