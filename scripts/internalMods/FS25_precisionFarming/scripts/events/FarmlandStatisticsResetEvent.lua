-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for syncing the farmland stats to the player
-- @category Events
FarmlandStatisticsResetEvent = {}
local FarmlandStatisticsResetEvent_mt = Class(FarmlandStatisticsResetEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function FarmlandStatisticsResetEvent.emptyNew()
    local self = Event.new(FarmlandStatisticsResetEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function FarmlandStatisticsResetEvent.new(farmlandId)
    local self = FarmlandStatisticsResetEvent.emptyNew()
    self.farmlandId = farmlandId
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function FarmlandStatisticsResetEvent:readStream(streamId, connection)
    self.farmlandId = streamReadUIntN(streamId, g_farmlandManager.numberOfBits)

    local pfModule = g_precisionFarming
    if pfModule ~= nil then
        if pfModule.farmlandStatistics ~= nil then
            pfModule.farmlandStatistics:resetStatistic(self.farmlandId)
        end
    end
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function FarmlandStatisticsResetEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.farmlandId, g_farmlandManager.numberOfBits)
end
