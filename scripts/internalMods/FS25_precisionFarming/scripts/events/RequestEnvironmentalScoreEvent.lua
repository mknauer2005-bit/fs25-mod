-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for syncing the environmental score to the player
-- @category Events
RequestEnvironmentalScoreEvent = {}
local RequestEnvironmentalScoreEvent_mt = Class(RequestEnvironmentalScoreEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function RequestEnvironmentalScoreEvent.emptyNew()
    local self = Event.new(RequestEnvironmentalScoreEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function RequestEnvironmentalScoreEvent.new(farmId)
    local self = RequestEnvironmentalScoreEvent.emptyNew()
    self.farmId = farmId
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function RequestEnvironmentalScoreEvent:readStream(streamId, connection)
    self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function RequestEnvironmentalScoreEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
end


---Run action on receiving side
-- @param Connection connection connection
function RequestEnvironmentalScoreEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(EnvironmentalScoreEvent.new(self.farmId), false, nil, nil, true, {connection})
    end
end
