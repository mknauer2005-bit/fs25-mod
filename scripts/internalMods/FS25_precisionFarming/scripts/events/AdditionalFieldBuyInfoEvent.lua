-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for syncing the field buy info to the player
-- @category Events
AdditionalFieldBuyInfoEvent = {}
local AdditionalFieldBuyInfoEvent_mt = Class(AdditionalFieldBuyInfoEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function AdditionalFieldBuyInfoEvent.emptyNew()
    local self = Event.new(AdditionalFieldBuyInfoEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function AdditionalFieldBuyInfoEvent.new(farmlandId)
    local self = AdditionalFieldBuyInfoEvent.emptyNew()
    self.farmlandId = farmlandId
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function AdditionalFieldBuyInfoEvent:readStream(streamId, connection)
    self.farmlandId = streamReadUIntN(streamId, g_farmlandManager.numberOfBits)

    local pfModule = g_precisionFarming
    if pfModule ~= nil then
        if pfModule.additionalFieldBuyInfo ~= nil then
            pfModule.additionalFieldBuyInfo:readInfoFromStream(self.farmlandId, streamId, connection)
        end
    end
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function AdditionalFieldBuyInfoEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.farmlandId, g_farmlandManager.numberOfBits)

    local pfModule = g_precisionFarming
    if pfModule ~= nil then
        if pfModule.additionalFieldBuyInfo ~= nil then
            pfModule.additionalFieldBuyInfo:writeInfoToStream(self.farmlandId, streamId, connection)
        end
    end
end
