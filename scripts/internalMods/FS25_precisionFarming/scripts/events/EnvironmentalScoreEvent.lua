-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for syncing the environmental score to the player
-- @category Events
EnvironmentalScoreEvent = {}
local EnvironmentalScoreEvent_mt = Class(EnvironmentalScoreEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function EnvironmentalScoreEvent.emptyNew()
    local self = Event.new(EnvironmentalScoreEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function EnvironmentalScoreEvent.new(farmId)
    local self = EnvironmentalScoreEvent.emptyNew()
    self.farmId = farmId
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function EnvironmentalScoreEvent:readStream(streamId, connection)
    self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)

    local pfModule = g_precisionFarming
    if pfModule ~= nil then
        if pfModule.environmentalScore ~= nil then
            pfModule.environmentalScore:readStream(streamId, connection, self.farmId)
        end
    end
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function EnvironmentalScoreEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)

    local pfModule = g_precisionFarming
    if pfModule ~= nil then
        if pfModule.environmentalScore ~= nil then
            pfModule.environmentalScore:writeStream(streamId, connection, self.farmId)
        end
    end
end
