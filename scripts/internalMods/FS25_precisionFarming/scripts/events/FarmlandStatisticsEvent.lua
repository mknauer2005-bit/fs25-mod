-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for syncing the farmland stats to the player
-- @category Events
FarmlandStatisticsEvent = {}
local FarmlandStatisticsEvent_mt = Class(FarmlandStatisticsEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function FarmlandStatisticsEvent.emptyNew()
    local self = Event.new(FarmlandStatisticsEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function FarmlandStatisticsEvent.new(farmlandId)
    local self = FarmlandStatisticsEvent.emptyNew()
    self.farmlandId = farmlandId
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function FarmlandStatisticsEvent:readStream(streamId, connection)
    self.farmlandId = streamReadUIntN(streamId, g_farmlandManager.numberOfBits)

    local pfModule = g_precisionFarming
    if pfModule ~= nil then
        if pfModule.farmlandStatistics ~= nil then
            pfModule.farmlandStatistics:readStatisticFromStream(self.farmlandId, streamId, connection)
        end
    end
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function FarmlandStatisticsEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.farmlandId, g_farmlandManager.numberOfBits)

    local pfModule = g_precisionFarming
    if pfModule ~= nil then
        if pfModule.farmlandStatistics ~= nil then
            pfModule.farmlandStatistics:writeStatisticToStream(self.farmlandId, streamId, connection)
        end
    end
end
