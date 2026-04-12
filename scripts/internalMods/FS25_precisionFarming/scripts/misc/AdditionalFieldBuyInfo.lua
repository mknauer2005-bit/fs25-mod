-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.










---
AdditionalFieldBuyInfo = {}
local AdditionalFieldBuyInfo_mt = Class(AdditionalFieldBuyInfo)


---
function AdditionalFieldBuyInfo.new(pfModule, customMt)
    local self = setmetatable({}, customMt or AdditionalFieldBuyInfo_mt)

    self.statistics = {}
    self.statisticsByFarmland = {}
    self.mapFrame = nil

    self.selectedFarmlandId = nil
    self.showTotal = false

    self.selectedField = 0
    self.selectedFieldSize = 0

    self.soilDistribution = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
    }

    self.soilDistributionTarget = {
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
    }

    self.yieldPotential = 0
    self.yieldPotentialTarget = 0

    self.doInterpolation = false

    self.allPlaceablesLoaded = false

    self.pfModule = pfModule

    return self
end


---
function AdditionalFieldBuyInfo:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
    self.isColorBlindMode = g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE) or false
    g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_COLORBLIND_MODE], self.setColorBlindMode, self)
    g_messageCenter:subscribe(MessageType.LOADED_ALL_SAVEGAME_PLACEABLES, self.onAllPlaceablesLoaded, self)

    return true
end


---
function AdditionalFieldBuyInfo:loadFromItemsXML(xmlFile, key)
end


---
function AdditionalFieldBuyInfo:saveToXMLFile(xmlFile, key, usedModNames)
end


---
function AdditionalFieldBuyInfo:delete()
    g_messageCenter:unsubscribeAll(self)
end


---
function AdditionalFieldBuyInfo:readInfoFromStream(farmlandId, streamId, connection)
    if streamReadBool(streamId) then
        self.selectedField = streamReadUIntN(streamId, 9)
        self.selectedFieldSize = streamReadFloat32(streamId)

        local farmland = g_farmlandManager.farmlands[farmlandId]
        farmland.totalFieldArea = self.selectedFieldSize

        self.mapFrame.fieldBuyInfoWindow:setVisible(true)

        for i=1, #self.soilDistributionTarget do
            self.soilDistribution[i] = 0
            self.soilDistributionTarget[i] = streamReadUIntN(streamId, 8) / 255
        end

        self.yieldPotentialTarget = streamReadUIntN(streamId, 8) / 255 * 1.25
        self.yieldPotential = 1

        self.doInterpolation = true

        self:updateUIValues()
    else
        self.mapFrame.fieldBuyInfoWindow:setVisible(false)
    end
end


---
function AdditionalFieldBuyInfo:writeInfoToStream(farmlandId, streamId, connection)
    local farmland = g_farmlandManager.farmlands[farmlandId]
    local fieldNumber, fieldArea = self:getFarmlandFieldInfo(farmlandId)

    local isValid = fieldArea > 0 and farmland.soilDistribution ~= nil
    if streamWriteBool(streamId, isValid) then
        streamWriteUIntN(streamId, fieldNumber, 9)
        streamWriteFloat32(streamId, fieldArea)

        for i=1, #self.soilDistributionTarget do
            streamWriteUIntN(streamId, farmland.soilDistribution[i] * 255, 8)
        end

        streamWriteUIntN(streamId, farmland.yieldPotential / 1.25 * 255, 8)
    end
end


---Determine if the HUD extension should be drawn.
function AdditionalFieldBuyInfo:setColorBlindMode(isActive)
    if isActive ~= self.isColorBlindMode then
        self.isColorBlindMode = isActive

        self:updateSoilBars()
    end
end



























---
function AdditionalFieldBuyInfo:setMapFrame(mapFrame)
    self.mapFrame = mapFrame

    self.maxBarSize = self.maxBarSize or mapFrame.soilPercentageBar[1].size[1]

    mapFrame.fieldBuyInfoWindow:setVisible(false)
end


---
function AdditionalFieldBuyInfo:updateSoilBars()
    if self.pfModule.soilMap ~= nil then
        local soilTypes = self.pfModule.soilMap.soilTypes
        for i=1, #soilTypes do
            local soilType = soilTypes[i]
            self.mapFrame.soilNameText[i]:setText(soilType.name)
            self.mapFrame.soilPercentageBar[i]:setImageColor(nil, unpack(self.isColorBlindMode and soilType.colorBlind or soilType.color))
        end
    end
end


---
function AdditionalFieldBuyInfo:updateUIValues()
    local mapFrame = self.mapFrame

    local contentBox = self.mapFrame.contextBoxFarmland
    local background = contentBox.elements[1]

    if self.farmlandBoxHeight == nil then
        self.farmlandBoxHeight = contentBox.size[2]
        self.farmlandBoxBgHeight = background.size[2]
    end

    if self.selectedFieldSize >= 0.01 then
        self.mapFrame.fieldBuyInfoWindow:setVisible(true)
        contentBox:setSize(nil, self.farmlandBoxHeight + self.mapFrame.fieldBuyInfoWindow.size[2])
        background:setSize(nil, self.farmlandBoxBgHeight + self.mapFrame.fieldBuyInfoWindow.size[2])
    else
        self.mapFrame.fieldBuyInfoWindow:setVisible(false)
        contentBox:setSize(nil, self.farmlandBoxHeight)
        background:setSize(nil, self.farmlandBoxBgHeight)

        return
    end

    self:updateSoilBars()

    for i=1, 4 do
        local offset = mapFrame.soilPercentageText[i].size[1] * 0.1
        local str = "~%d%%"
        if self.soilDistribution[i] == 0 then
            str = "%d%%"
            offset = 0
        end

        mapFrame.soilPercentageText[i]:setText(string.format(str, self.soilDistribution[i] * 100))
        mapFrame.soilPercentageBar[i]:setSize(self.maxBarSize * self.soilDistribution[i])
        mapFrame.soilPercentageText[i]:setPosition(mapFrame.soilPercentageBar[i].position[1] + mapFrame.soilPercentageBar[i].size[1] + offset)
    end

    if self.yieldPotential > 1 then
        mapFrame.yieldPercentageBarPos:setPosition(mapFrame.yieldPercentageBarBase.position[1] + mapFrame.yieldPercentageBarBase.size[1])
        mapFrame.yieldPercentageBarPos:setSize(mapFrame.yieldPercentageBarBase.size[1] * (self.yieldPotential - 1))

        mapFrame.yieldPercentageBarNeg:setSize(0)
    elseif self.yieldPotential < 1 then
        local barWidth = mapFrame.yieldPercentageBarBase.size[1] * math.abs(self.yieldPotential - 1)
        mapFrame.yieldPercentageBarNeg:setPosition(mapFrame.yieldPercentageBarBase.position[1] + mapFrame.yieldPercentageBarBase.size[1] - barWidth)
        mapFrame.yieldPercentageBarNeg:setSize(barWidth)

        mapFrame.yieldPercentageBarPos:setSize(0)
    else
        mapFrame.yieldPercentageBarNeg:setSize(0)
        mapFrame.yieldPercentageBarPos:setSize(0)
    end

    mapFrame.yieldPercentageText:setText(string.format("~%d%%", self.yieldPotential * 100))
    local maxWidth = mapFrame.yieldPercentageBarBase.position[1] + mapFrame.yieldPercentageBarBase.size[1] * 1.25 - mapFrame.yieldPercentageText.size[1]
    mapFrame.yieldPercentageText:setPosition(math.min(mapFrame.yieldPercentageBarBase.position[1] + mapFrame.yieldPercentageBarBase.size[1] * self.yieldPotential - mapFrame.yieldPercentageText.size[1] * 0.5, maxWidth))

    self:updateContextBox()
end


---
function AdditionalFieldBuyInfo:onFarmlandSelectionChanged(selectedFarmland)
    if self.mapFrame ~= nil then
        if selectedFarmland ~= nil then
            self.selectedFarmlandId = selectedFarmland.id

            if g_server ~= nil then
                local fieldNumber, fieldArea = self:getFarmlandFieldInfo(selectedFarmland.id)
                if fieldArea >= 0.01 then
                    self.selectedField = fieldNumber
                    self.selectedFieldSize = fieldArea

                    if selectedFarmland.soilDistribution ~= nil then
                        for i=1, #self.soilDistributionTarget do
                            self.soilDistribution[i] = 0
                            self.soilDistributionTarget[i] = selectedFarmland.soilDistribution[i]
                        end

                        self.yieldPotentialTarget = selectedFarmland.yieldPotential
                        self.yieldPotential = 1
                        self.doInterpolation = true
                    end
                else
                    self.selectedField = 0
                    self.selectedFieldSize = 0
                end

                self:updateUIValues()
            else
                -- client doesn't know that the values have changed -> so just poll the latest data
                if g_server == nil and g_client ~= nil then
                    g_client:getServerConnection():sendEvent(RequestFieldBuyInfoEvent.new(selectedFarmland.id))
                end
            end
        else
            self.selectedField = 0
            self.selectedFieldSize = 0
            self.selectedFarmlandId = 0

            self:updateUIValues()
        end
    end
end


---
function AdditionalFieldBuyInfo:onShowContextBox(farmland, contextBox)
    self.lastContextBox = contextBox
end


---
function AdditionalFieldBuyInfo:updateContextBox()
    if self.lastContextBox ~= nil then
        local farmland = g_farmlandManager.farmlands[self.selectedFarmlandId]
        if farmland == nil then
            return
        end

        local valueText
        if farmland.totalFieldArea ~= nil then
            valueText = string.format("%s (%s / ha)", g_i18n:formatMoney(farmland.price, 0, true, false), g_i18n:formatMoney(farmland.price / farmland.totalFieldArea, 0, true, false))
        else
            valueText = g_i18n:formatMoney(farmland.price, 0, true, false)
        end
        self.lastContextBox:getDescendantByName("farmlandValue"):setText(valueText)

        if farmland.totalFieldArea ~= nil then
            local text = string.format("%s (%s: %s)", g_i18n:formatArea(farmland.areaInHa, 2), g_i18n:getText("contract_details_field"), g_i18n:formatArea(farmland.totalFieldArea, 2))
            self.lastContextBox:getDescendantByName("farmlandSize"):setText(text)
        end

        if self.mapFrame.updatePrecisionFarmingContextActions ~= nil then
            self.mapFrame.updatePrecisionFarmingContextActions()
        end
    end
end


---
function AdditionalFieldBuyInfo:getFarmlandFieldInfo(farmlandId)
    local fieldNumber = 0
    local fieldArea = 0

    local farmland = g_farmlandManager.farmlands[farmlandId]
    if farmland ~= nil then
        fieldArea = farmland.totalFieldArea or 0
    end

    local fields = g_fieldManager:getFields()
    if fields ~= nil then
        for _, field in pairs(fields) do
            if field.farmland ~= nil then
                if field.farmland.id == farmlandId then
                    fieldNumber = field:getId()
                    break
                end
            end
        end
    end

    return fieldNumber, fieldArea
end


---
function AdditionalFieldBuyInfo:updateFieldSoilDistributionData()
    local pfModule = self.pfModule
    local farmlandManager = g_farmlandManager
    if pfModule.soilMap ~= nil then
        local soilBitVectorMap = pfModule.soilMap.bitVectorMap
        if soilBitVectorMap ~= nil then
            local startTime = getTimeSec()

            local farmlandX, _ = getBitVectorMapSize(farmlandManager.localMap)
            local soilX, soilY = getBitVectorMapSize(soilBitVectorMap)

            local farmlandScale = farmlandX / soilX
            for x = 0, soilX - 1 do
                for y = 0, soilY - 1 do
                    local worldX = x / (soilX - 1) * g_currentMission.terrainSize - g_currentMission.terrainSize * 0.5
                    local worldZ = y / (soilY - 1) * g_currentMission.terrainSize - g_currentMission.terrainSize * 0.5
                    local isOnField = getDensityAtWorldPos(g_currentMission.terrainDetailId, worldX, 0, worldZ) ~= 0
                    if isOnField then
                        local valueFarmland = getBitVectorMapPoint(farmlandManager.localMap, x * farmlandScale, y * farmlandScale, 0, farmlandManager.numberOfBits)
                        local valueSoil = bit32.band(getBitVectorMapPoint(soilBitVectorMap, x, y, 0, pfModule.soilMap.numChannels), 3)

                        if valueFarmland > 0 then
                            local farmland = farmlandManager.farmlands[valueFarmland]
                            if farmland ~= nil then
                                if farmland.totalFieldArea == nil then
                                    farmland.totalFieldArea = 0
                                end

                                farmland.totalFieldArea = farmland.totalFieldArea + 1

                                if farmland.soilDistribution == nil then
                                    farmland.soilDistribution = {}
                                    for i=1, #pfModule.soilMap.soilTypes do
                                        farmland.soilDistribution[i] = 0
                                    end
                                end

                                farmland.soilDistribution[valueSoil + 1] = farmland.soilDistribution[valueSoil + 1] + 1
                            end
                        end
                    end
                end
            end

            local totalYieldPotentialPixels = 0
            local totalFarmlandPixels = 0
            for _, farmland in pairs(farmlandManager.farmlands) do
                farmland:updatePrice()

                if farmland.soilDistribution ~= nil then
                    local soilSum = 0
                    for i=1, #farmland.soilDistribution do
                        soilSum = soilSum + farmland.soilDistribution[i]
                    end

                    if soilSum > 0 then
                        local yieldPotential = 0
                        for i=1, #farmland.soilDistribution do
                            farmland.soilDistribution[i] = math.floor(farmland.soilDistribution[i] / soilSum * 100) / 100
                            yieldPotential = yieldPotential + self.pfModule.soilMap:getYieldPotentialBySoilTypeIndex(i) * farmland.soilDistribution[i]
                            self.soilDistribution[i] = 0
                        end

                        farmland.yieldPotential = math.clamp(yieldPotential, 0, 1.25)

                        totalYieldPotentialPixels = totalYieldPotentialPixels + farmland.yieldPotential * soilSum
                        totalFarmlandPixels = totalFarmlandPixels + soilSum
                    end

                    local pixelToSqm = g_currentMission.terrainSize / soilX
                    farmland.totalFieldArea = (farmland.totalFieldArea * pixelToSqm * pixelToSqm) / 10000
                end
            end

            Logging.devInfo("Map Overall Yield Potential: %.3f (%.2fms)", totalYieldPotentialPixels / totalFarmlandPixels, (getTimeSec() - startTime) * 1000)
        end
    end
end


---
function AdditionalFieldBuyInfo:onAllPlaceablesLoaded()
    self.allPlaceablesLoaded = true

    -- update the soil data when all placeables have been loaded -> so all rice fields are loaded as well
    if self.delayedFieldSoilDistributionUpdate and #g_fieldManager.updateTasks == 0 then
        local readyForUpdate = true
        for _, _field in pairs(g_fieldManager.fields) do
            if not _field:getHasOwner() and _field.isMissionAllowed then
                if not _field.pf_fieldInitialized then
                    readyForUpdate = false
                    break
                end
            end
        end

        if readyForUpdate then
            self.delayedFieldSoilDistributionUpdate = false
            self:updateFieldSoilDistributionData()
        end
    end
end


---
function AdditionalFieldBuyInfo:overwriteGameFunctions(pfModule)
    -- when all placeables have been loaded and synced to client side
    if g_server == nil then
        pfModule:overwriteGameFunction(Placeable, "setLoadingStep", function(superFunc, placeable, loadingStep, ...)
            superFunc(placeable, loadingStep, ...)

            if g_currentMission.placeableSystem:canStartMission() then
                self:onAllPlaceablesLoaded()
            end
        end)
    end

    -- calculate the soil distribution for
    pfModule:overwriteGameFunction(FarmlandManager, "loadFarmlandData", function(superFunc, farmlandManager, xmlFile)
        if not superFunc(farmlandManager, xmlFile) then
            return false
        end

        if g_currentMission.missionInfo.isValid then
            self:updateFieldSoilDistributionData()
        else
            -- delay the initialization on new savegames to make sure the terrain detail is painted
            self.delayedFieldSoilDistributionUpdate = true
        end

        return true
    end)

    -- update the distribution data initially when all fields have been updated
    pfModule:overwriteGameFunction(FieldManager, "onFinishFieldUpdateTask", function(superFunc, _fieldManager, task, ...)
        superFunc(_fieldManager, task, ...)

        if task.fieldId ~= nil then
            local field = _fieldManager:getFieldById(task.fieldId)
            if field ~= nil then
                field.pf_fieldInitialized = true
            end
        end

        if self.delayedFieldSoilDistributionUpdate and self.allPlaceablesLoaded and #_fieldManager.updateTasks == 0 then
            local readyForUpdate = true
            for _, _field in pairs(_fieldManager.fields) do
                if not _field:getHasOwner() and _field.isMissionAllowed then
                    if not _field.pf_fieldInitialized then
                        readyForUpdate = false
                        break
                    end
                end
            end

            if readyForUpdate then
                self.delayedFieldSoilDistributionUpdate = false
                self:updateFieldSoilDistributionData()
            end
        end
    end)

    -- multiply the field price with the yield potential
    pfModule:overwriteGameFunction(Farmland, "updatePrice", function(superFunc, farmland)
        superFunc(farmland)

        if farmland.yieldPotential ~= nil then
            farmland.price = farmland.price * farmland.yieldPotential
        end
    end)
end
