-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event for syncing the farmland stats to the player
-- @category Events
ResetYieldMapEvent = {}
local ResetYieldMapEvent_mt = Class(ResetYieldMapEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function ResetYieldMapEvent.emptyNew()
    local self = Event.new(ResetYieldMapEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function ResetYieldMapEvent.new(farmlandId)
    local self = ResetYieldMapEvent.emptyNew()
    self.farmlandId = farmlandId
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function ResetYieldMapEvent:readStream(streamId, connection)
    self.farmlandId = streamReadUIntN(streamId, g_farmlandManager.numberOfBits)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function ResetYieldMapEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.farmlandId, g_farmlandManager.numberOfBits)
end


---Run action on receiving side
-- @param Connection connection connection
function ResetYieldMapEvent:run(connection)
    if not connection:getIsServer() then
        if g_precisionFarming ~= nil then
            if g_precisionFarming.yieldMap ~= nil then
                g_precisionFarming.yieldMap:resetFarmlandYieldArea(self.farmlandId)
                g_precisionFarming:updatePrecisionFarmingOverlays()
            end
        end
    end
end
