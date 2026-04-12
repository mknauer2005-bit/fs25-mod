-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---
MotorClutchCreakingEvent = {}
local MotorClutchCreakingEvent_mt = Class(MotorClutchCreakingEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function MotorClutchCreakingEvent.emptyNew()
    local self = Event.new(MotorClutchCreakingEvent_mt)
    return self
end


---Create new instance of event
-- @param table vehicle vehicle
-- @param boolean turnedOn is turned on
function MotorClutchCreakingEvent.new(vehicle, isEvent, groupTransmission, gearIndex, groupIndex)
    local self = MotorClutchCreakingEvent.emptyNew()
    self.vehicle = vehicle
    self.isEvent = isEvent
    self.groupTransmission = groupTransmission
    self.gearIndex = gearIndex
    self.groupIndex = groupIndex

    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function MotorClutchCreakingEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.isEvent = streamReadBool(streamId)
    self.groupTransmission = streamReadBool(streamId)

    if streamReadBool(streamId) then
        self.gearIndex = streamReadUIntN(streamId, 6)
    end
    if streamReadBool(streamId) then
        self.groupIndex = streamReadUIntN(streamId, 5)
    end

    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function MotorClutchCreakingEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)

    streamWriteBool(streamId, self.isEvent)
    streamWriteBool(streamId, self.groupTransmission)

    if streamWriteBool(streamId, self.gearIndex ~= nil) then
        streamWriteUIntN(streamId, self.gearIndex, 6)
    end
    if streamWriteBool(streamId, self.groupIndex ~= nil) then
        streamWriteUIntN(streamId, self.groupIndex, 5)
    end
end


---Run action on receiving side
-- @param Connection connection connection
function MotorClutchCreakingEvent:run(connection)
    local vehicle = self.vehicle
    if vehicle ~= nil and vehicle:getIsSynchronized() then
        SpecializationUtil.raiseEvent(self.vehicle, "onClutchCreaking", self.isEvent, self.groupTransmission, self.gearIndex, self.groupIndex)
    end
end
