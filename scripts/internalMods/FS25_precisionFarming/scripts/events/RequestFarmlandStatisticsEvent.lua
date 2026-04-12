-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for syncing the farmland stats to the player
-- @category Events
RequestFarmlandStatisticsEvent = {}
local RequestFarmlandStatisticsEvent_mt = Class(RequestFarmlandStatisticsEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function RequestFarmlandStatisticsEvent.emptyNew()
    local self = Event.new(RequestFarmlandStatisticsEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function RequestFarmlandStatisticsEvent.new(farmlandId)
    local self = RequestFarmlandStatisticsEvent.emptyNew()
    self.farmlandId = farmlandId
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function RequestFarmlandStatisticsEvent:readStream(streamId, connection)
    self.farmlandId = streamReadUIntN(streamId, g_farmlandManager.numberOfBits)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function RequestFarmlandStatisticsEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.farmlandId, g_farmlandManager.numberOfBits)
end


---Run action on receiving side
-- @param Connection connection connection
function RequestFarmlandStatisticsEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(FarmlandStatisticsEvent.new(self.farmlandId), false, nil, nil, true, {connection})
    end
end
