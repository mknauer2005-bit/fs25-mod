-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


---Event to sync soil map purchase to the server
-- @category Events
PurchaseSoilMapsEvent = {}
local PurchaseSoilMapsEvent_mt = Class(PurchaseSoilMapsEvent, Event)




---Create instance of Event class
-- @return table self instance of class event
function PurchaseSoilMapsEvent.emptyNew()
    local self = Event.new(PurchaseSoilMapsEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
function PurchaseSoilMapsEvent.new(farmlandId)
    local self = PurchaseSoilMapsEvent.emptyNew()
    self.farmlandId = farmlandId
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function PurchaseSoilMapsEvent:readStream(streamId, connection)
    self.farmlandId = streamReadUIntN(streamId, g_farmlandManager.numberOfBits)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param Connection connection connection
function PurchaseSoilMapsEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.farmlandId, g_farmlandManager.numberOfBits)
end


---Run action on receiving side
-- @param Connection connection connection
function PurchaseSoilMapsEvent:run(connection)
    if not connection:getIsServer() then
        if g_precisionFarming ~= nil then
            if g_precisionFarming.soilMap ~= nil then
                g_precisionFarming.soilMap:purchaseSoilMaps(self.farmlandId)
                g_precisionFarming:updatePrecisionFarmingOverlays()
            end
        end
    end
end
