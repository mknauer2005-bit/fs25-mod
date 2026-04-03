-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for requesting the field buy info from the server
-- @category Events
RequestFieldBuyInfoEvent = {}
local RequestFieldBuyInfoEvent_mt = Class(RequestFieldBuyInfoEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function RequestFieldBuyInfoEvent.emptyNew()
    local self = Event.new(RequestFieldBuyInfoEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function RequestFieldBuyInfoEvent.new(farmlandId)
    local self = RequestFieldBuyInfoEvent.emptyNew()
    self.farmlandId = farmlandId
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function RequestFieldBuyInfoEvent:readStream(streamId, connection)
    self.farmlandId = streamReadUIntN(streamId, g_farmlandManager.numberOfBits)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function RequestFieldBuyInfoEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.farmlandId, g_farmlandManager.numberOfBits)
end


---Run action on receiving side
-- @param Connection connection connection
function RequestFieldBuyInfoEvent:run(connection)
    if not connection:getIsServer() then
        if not connection:getIsServer() then
            g_server:broadcastEvent(AdditionalFieldBuyInfoEvent.new(self.farmlandId), false, nil, nil, true, {connection})
        end
    end
end
