-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.












---
FarmlandStatistics = {}
local FarmlandStatistics_mt = Class(FarmlandStatistics)


---
function FarmlandStatistics.new(pfModule, customMt)
    local self = setmetatable({}, customMt or FarmlandStatistics_mt)

    self.statistics = {}
    self.statisticsByFarmland = {}
    self.mapFrame = nil

    self.pfModule = pfModule

    return self
end


---
function FarmlandStatistics:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
    g_messageCenter:subscribe(MessageType.FARMLAND_OWNER_CHANGED, self.onFarmlandStateChanged, self)

    return true
end


---
function FarmlandStatistics:loadFromItemsXML(xmlFile, key)
    key = key .. ".farmlandStatistics"

    for i=1, #self.statistics do
        local statistic = self.statistics[i]
        local statKey = string.format("%s.farmlandStatistic(%d)", key, i - 1)
        if not xmlFile:hasProperty(statKey) then
            break
        end

        statistic:loadFromItemsXML(xmlFile, statKey)
    end
end


---
function FarmlandStatistics:saveToXMLFile(xmlFile, key, usedModNames)
    key = key .. ".farmlandStatistics"

    for i=1, #self.statistics do
        local statistic = self.statistics[i]
        local statKey = string.format("%s.farmlandStatistic(%d)", key, i - 1)

        statistic:saveToXMLFile(xmlFile, statKey, usedModNames)
    end
end


---
function FarmlandStatistics:delete()
    g_messageCenter:unsubscribeAll(self)

    self.statistics = {}
    self.statisticsByFarmland = {}
end


---
function FarmlandStatistics:readStatisticFromStream(farmlandId, streamId, connection)
    if streamReadBool(streamId) then
        local totalFieldArea = streamReadFloat32(streamId)
        local farmland = g_farmlandManager.farmlands[farmlandId]
        if farmland ~= nil then
            farmland.totalFieldArea = totalFieldArea
        end
    end

    local statistic = self.statisticsByFarmland[farmlandId]
    if statistic ~= nil then
        statistic:onReadStream(streamId, connection)
    end

    self.selectedFarmlandId = farmlandId
    self:openStatistics(farmlandId, true)
end


---
function FarmlandStatistics:writeStatisticToStream(farmlandId, streamId, connection)
    local farmland = g_farmlandManager.farmlands[farmlandId]
    if streamWriteBool(streamId, farmland ~= nil) then
        streamWriteFloat32(streamId, farmland.totalFieldArea or 0)
    end

    local statistic = self.statisticsByFarmland[farmlandId]
    if statistic ~= nil then
        statistic:onWriteStream(streamId, connection)
    end
end


---
function FarmlandStatistics:setMapFrame(mapFrame)
    self.mapFrame = mapFrame
end


---
function FarmlandStatistics:collectFarmlandHotspotActions(actions)
    table.insert(actions, {title=g_i18n:getText("ui_economicAnalysis"), callback=self.openStatistics, callbackTarget=self})
end


---
function FarmlandStatistics:openStatistics(farmlandId, noEventSend)
    self.mapFrame:setMapSelectionItem(nil)

    local statistic = self.statisticsByFarmland[farmlandId]
    if statistic ~= nil then
        local fieldNumber, fieldArea = self:getFarmlandFieldInfo(farmlandId)
        if fieldArea >= 0.01 then
            FarmlandStatsDialog.show(farmlandId, fieldNumber, fieldArea, statistic)
        end
    end

    if not noEventSend then
        if g_server == nil and g_client ~= nil then
            g_client:getServerConnection():sendEvent(RequestFarmlandStatisticsEvent.new(farmlandId))
        end
    end
end


---
function FarmlandStatistics:getFarmlandFieldInfo(farmlandId)
    return self.pfModule:getFarmlandFieldInfo(farmlandId)
end


---
function FarmlandStatistics:updateStatistic(farmlandId, name, value)
    local statistic = self.statisticsByFarmland[farmlandId]
    if statistic ~= nil then
        statistic:updateStatistic(name, value)
    end
end


---
function FarmlandStatistics:resetStatistic(farmlandId, clearTotal)
    local statistic = self.statisticsByFarmland[farmlandId]
    if statistic ~= nil then
        statistic:reset(clearTotal)
    end
end


---
function FarmlandStatistics:getFillLevelWeight(fillLevel, fillTypeIndex)
    local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    if fillType ~= nil then
        return fillLevel * (fillType.massPerLiter / FillTypeManager.MASS_SCALE)
    end

    return fillLevel
end


---
function FarmlandStatistics:getFillLevelPrice(fillLevel, fillTypeIndex)
    if fillTypeIndex == "soilSamples" then
        local price = self.pfModule.soilMap.pricePerSample[g_currentMission.missionInfo.economicDifficulty] or 0
        return fillLevel * price
    end

    local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    if fillType ~= nil then
        return fillLevel * fillType.pricePerLiter
    end

    return fillLevel
end











---
function FarmlandStatistics:overwriteGameFunctions(pfModule)
    FarmlandStatsDialog.register()

    pfModule:overwriteGameFunction(FarmlandManager, "loadFarmlandData", function(superFunc, farmlandManager, xmlFile)
        if not superFunc(farmlandManager, xmlFile) then
            return false
        end

        local farmlands = g_farmlandManager:getFarmlands()
        if farmlands ~= nil then
            for id, farmland in pairs(farmlands) do
                local statistic = FarmlandStatistic.new(id)
                self.statisticsByFarmland[id] = statistic
                table.insert(self.statistics, statistic)
            end
        end

        return true
    end)
end
