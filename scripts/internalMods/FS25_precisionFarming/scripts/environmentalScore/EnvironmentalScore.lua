-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.


























---
EnvironmentalScore = {}
local EnvironmentalScore_mt = Class(EnvironmentalScore)


---
function EnvironmentalScore.new(pfModule, customMt)
    local self = setmetatable({}, customMt or EnvironmentalScore_mt)

    self.pfModule = pfModule
    self.mapFrame = nil

    self.isColorBlindMode = g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE)

    self.moneyChangeTypePos = MoneyType.register("other", "info_environmentalScoreReward", SoilMap.MOD_NAME)
    self.moneyChangeTypeNeg = MoneyType.register("other", "info_environmentalScorePenalty", SoilMap.MOD_NAME)

    self.scoreUpdateTimer = 0

    self.harvestedStates = {}
    self.farmRevenueIncrease = {}
    self.farmRevenueIncreaseMessageDirty = false

    self.overwrittenWindowState = false
    self.currentInputHelpMode = g_inputBinding:getInputHelpMode()

    self.scoreValues = {}

    self.scoreObjects = {}
    self.scoreObjects["EnvironmentalScoreHerbicide"] = EnvironmentalScoreHerbicide.new(pfModule)
    self.scoreObjects["EnvironmentalScoreNitrogen"] = EnvironmentalScoreNitrogen.new(pfModule)
    self.scoreObjects["EnvironmentalScorePH"] = EnvironmentalScorePH.new(pfModule)
    self.scoreObjects["EnvironmentalScoreSoilSample"] = EnvironmentalScoreSoilSample.new(pfModule)
    self.scoreObjects["EnvironmentalScoreTillage"] = EnvironmentalScoreTillage.new(pfModule)

    local _
    self.ui = {}
    self.ui.fieldInfoWidth, self.ui.fieldInfoHeight = getNormalizedScreenValues(110, 110)
    _, self.ui.fieldInfoHeightSmall = getNormalizedScreenValues(0, 65)
    self.ui.scoreBarMainWidth, self.ui.scoreBarMainHeight = getNormalizedScreenValues(92, 11)
    self.ui.scoreBarMainIndicatorWidth, self.ui.scoreBarMainIndicatorHeight = getNormalizedScreenValues(2, 15)
    self.ui.scoreBarSmallWidth, self.ui.scoreBarSmallHeight = getNormalizedScreenValues(70, 5)
    self.ui.iconWidth, self.ui.iconHeight = getNormalizedScreenValues(40, 40)
    _, self.ui.scoreBarOffset = getNormalizedScreenValues(0, 4)
    _, self.ui.topOffset = getNormalizedScreenValues(0, 2)
    _, self.ui.spacingY = getNormalizedScreenValues(0, 5)
    _, self.ui.fieldInfoHeightOffset = getNormalizedScreenValues(0, 12)
    _, self.ui.textSizeHeader = getNormalizedScreenValues(0, 30)
    _, self.ui.textOffsetHeader = getNormalizedScreenValues(0, 7)

    self.ui.iconOverlay = Overlay.new(EnvironmentalScore.GUI_ELEMENTS, 0, 0, self.ui.iconWidth, self.ui.iconHeight)
    self.ui.iconOverlay:setSliceId("precisionFarming.env_score_icon")
    self.ui.iconOverlay:setColor(1, 1, 1, 1)

    self.ui.gradientOverlay = Overlay.new(EnvironmentalScore.GUI_ELEMENTS, 0, 0, self.ui.scoreBarMainWidth, self.ui.scoreBarMainHeight)
    self.ui.gradientOverlay:setSliceId(self.isColorBlindMode and "precisionFarming.gradient_color_blind" or "precisionFarming.gradient_red_green")
    self.ui.gradientOverlay:setColor(1, 1, 1, 1)

    self.ui.gradientIndicatorOverlay = Overlay.new(EnvironmentalScore.GUI_ELEMENTS, 0, 0, self.ui.scoreBarSmallWidth, self.ui.scoreBarSmallHeight)
    self.ui.gradientIndicatorOverlay:setSliceId("precisionFarming.filled")
    self.ui.gradientIndicatorOverlay:setColor(1, 1, 1, 1)

    self.ui.smallBarOverlay = Overlay.new(EnvironmentalScore.GUI_ELEMENTS, 0, 0, self.ui.scoreBarSmallWidth, self.ui.scoreBarSmallHeight)
    self.ui.smallBarOverlay:setSliceId("precisionFarming.filled")
    self.ui.smallBarOverlay:setColor(1, 1, 1, 1)

    self.ui.colorBackground = {0.018, 0.016, 0.015, 0.6}
    self.ui.colorMainUI = {0.22323, 0.40724, 0.00368, 1.0}

    self.ui.farmlandData = {}

    g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, self.onPeriodChanged, self)
    g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_COLORBLIND_MODE], self.setColorBlindMode, self)

    return self
end


---
function EnvironmentalScore:delete()
    self.ui.iconOverlay:delete()
    self.ui.gradientOverlay:delete()
    self.ui.gradientIndicatorOverlay:delete()
    self.ui.smallBarOverlay:delete()

    g_messageCenter:unsubscribeAll(self)
end


---
function EnvironmentalScore:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
    self.infoTextPos = g_i18n:getText("environmentalScore_rewardPos", EnvironmentalScore.MOD_NAME)
    self.infoTextNeg = g_i18n:getText("environmentalScore_rewardNeg", EnvironmentalScore.MOD_NAME)
    self.infoTextNone = g_i18n:getText("environmentalScore_rewardNone", EnvironmentalScore.MOD_NAME)

    local i = 0
    while true do
        local baseKey = string.format("%s.scoreValues.scoreValue(%d)", key, i)
        if not hasXMLProperty(xmlFile, baseKey) then
            break
        end

        local scoreValue = {}
        scoreValue.id = getXMLString(xmlFile, baseKey.."#id")
        if scoreValue.id ~= nil then
            scoreValue.id = string.upper(scoreValue.id)
            scoreValue.name = g_i18n:convertText(getXMLString(xmlFile, baseKey.."#name"), EnvironmentalScore.MOD_NAME)

            local className = getXMLString(xmlFile, baseKey.."#className")
            if className ~= nil and self.scoreObjects[className] ~= nil then
                scoreValue.object = self.scoreObjects[className]
                scoreValue.object:loadFromXML(xmlFile, baseKey, baseDirectory, configFileName, mapFilename)
            end

            if scoreValue.name ~= nil then
                if scoreValue.object ~= nil then
                    scoreValue.maxScore = getXMLInt(xmlFile, baseKey .. "#maxScore") or 10

                    scoreValue.curScore = scoreValue.maxScore * 0.5

                    table.insert(self.scoreValues, scoreValue)
                else
                    Logging.warning("Missing score object className in '%s'", baseKey)
                end
            else
                Logging.warning("Missing scoreValue name in '%s'", baseKey)
            end
        else
            Logging.warning("Missing scoreValue id in '%s'", baseKey)
        end

        i = i + 1
    end

    return true
end


---
function EnvironmentalScore:loadFromItemsXML(xmlFile, key)
    key = key .. ".environmentalScore"

    for i=1, #self.scoreValues do
        local scoreValue = self.scoreValues[i]
        if scoreValue.object ~= nil then
            scoreValue.object:loadFromItemsXML(xmlFile, key)
        end
    end

    xmlFile:iterate(key .. ".harvestedStates.harvestedState", function(index, stateKey)
        local farmlandId = xmlFile:getInt(stateKey .. "#farmlandId")
        local state = xmlFile:getInt(stateKey .. "#state")
        if farmlandId ~= nil and state ~= nil then
            self.harvestedStates[farmlandId] = state
        end
    end)
end


---
function EnvironmentalScore:saveToXMLFile(xmlFile, key, usedModNames)
    key = key .. ".environmentalScore"

    for i=1, #self.scoreValues do
        local scoreValue = self.scoreValues[i]
        if scoreValue.object ~= nil then
            scoreValue.object:saveToXMLFile(xmlFile, key, usedModNames)
        end
    end

    local index = 0
    for farmlandId, state in pairs(self.harvestedStates) do
        xmlFile:setInt(string.format("%s.harvestedStates.harvestedState(%d)#farmlandId", key, index), farmlandId)
        xmlFile:setInt(string.format("%s.harvestedStates.harvestedState(%d)#state", key, index), state)
        index = index + 1
    end
end


---Read data on client side
-- @param integer streamId streamId
-- @param Connection connection connection
function EnvironmentalScore:readStream(streamId, connection, farmId)
    for i=1, #self.scoreValues do
        local scoreValue = self.scoreValues[i]
        if scoreValue.object ~= nil then
            scoreValue.object:readStream(streamId, connection, farmId)
        end
    end
end


---Write data to client
-- @param integer streamId streamId
-- @param Connection connection connection
function EnvironmentalScore:writeStream(streamId, connection, farmId)
    for i=1, #self.scoreValues do
        local scoreValue = self.scoreValues[i]
        if scoreValue.object ~= nil then
            scoreValue.object:writeStream(streamId, connection, farmId)
        end
    end
end


---
function EnvironmentalScore:update(dt)
    if self.mapFrame ~= nil then
        local x, y = self.mapFrame.envScoreWindow.absPosition[1], self.mapFrame.envScoreWindow.absPosition[2]
        local sizeX, sizeY = self.mapFrame.envScoreWindow.absSize[1], self.mapFrame.envScoreWindow.absSize[2]
        local isHovering = self.overwrittenWindowState

        if g_gui:getIsDialogVisible() then
            isHovering = false
        else
            if g_inputBinding.mousePosXLast ~= nil then
                if g_inputBinding.mousePosXLast > x and g_inputBinding.mousePosXLast < x + sizeX then
                    if g_inputBinding.mousePosYLast > y and g_inputBinding.mousePosYLast < y + sizeY then
                        isHovering = true
                    end
                end
            end
        end

        local currentSizeY = self.mapFrame.envScoreWindow.size[2]
        local target = (isHovering and self.envScoreWindowSize * 2.692) or self.envScoreWindowSize
        local direction = math.sign(target - currentSizeY)
        local sizeY = math.clamp(currentSizeY + direction * dt / 1000, self.envScoreWindowSize, self.envScoreWindowSize * 2.692)
        self.mapFrame.envScoreWindow:setSize(nil, sizeY)
        self.mapFrame.envScoreWindowBackground:setSize(nil, sizeY + self.envScoreWindowBackgroundOffset)

        self.scoreUpdateTimer = self.scoreUpdateTimer + dt
        if self.scoreUpdateTimer > EnvironmentalScore.SCORE_UPDATE_TIME then
            self:updateUI()
            self.scoreUpdateTimer = 0
        end
    end

    if self.farmRevenueIncreaseMessageDirty then
        local keepDirty = false
        for farmId, data in pairs(self.farmRevenueIncrease) do
            if data.revenue ~= 0 and g_time - data.lastSellTime > 1000 then
                data.lastSellTime = 0

                g_currentMission:showMoneyChange(data.revenue < 0 and self.moneyChangeTypeNeg or self.moneyChangeTypePos, nil, nil, farmId)

                data.revenue = 0
            elseif data.revenue ~= 0 then
                keepDirty = true
            end
        end

        if not keepDirty then
            self.farmRevenueIncreaseMessageDirty = false
        end
    end
end


---
function EnvironmentalScore:toggleWindowSize(state)
    if state == nil then
        state = not self.overwrittenWindowState
    end

    self.overwrittenWindowState = state
end


---
function EnvironmentalScore:setMapFrame(mapFrame)
    self.mapFrame = mapFrame
    self.envScoreWindowSize = self.mapFrame.envScoreWindow.size[2]
    self.envScoreWindowBackgroundOffset = self.mapFrame.envScoreWindowBackground.size[2] - self.mapFrame.envScoreWindow.size[2]

    local sliceId = self.isColorBlindMode and "precisionFarming.gradient_color_blind" or "precisionFarming.gradient_red_green"
    self.mapFrame.envScoreBarDynamic:setImageSlice(nil, sliceId)
    self.mapFrame.envScoreBarStatic:setImageSlice(nil, sliceId)

    self:updateInputGlyphs()
end


---
function EnvironmentalScore:onEnvScoreDetailsButton()
    self:toggleWindowSize()
end


---
function EnvironmentalScore:updateInputGlyphs()
    self.currentInputHelpMode = g_inputBinding:getInputHelpMode()

    self.mapFrame.envScoreInputGlyph:setActions({InputAction.SWITCH_IMPLEMENT})
    self.mapFrame.envScoreInputBox:setVisible(self.currentInputHelpMode == GS_INPUT_HELP_MODE_GAMEPAD)

    if self.currentInputHelpMode == GS_INPUT_HELP_MODE_GAMEPAD then
        g_inputBinding:registerActionEvent(InputAction.SWITCH_IMPLEMENT, self, self.onEnvScoreDetailsButton, false, true, false, true)
    else
        g_inputBinding:removeActionEventsByTarget(self)
    end
end


---
function EnvironmentalScore:onMapFrameOpen(mapFrame)
    if g_server == nil and g_client ~= nil then
        local farmId = g_currentMission:getFarmId()
        if farmId ~= FarmManager.SPECTATOR_FARM_ID then
            g_client:getServerConnection():sendEvent(RequestEnvironmentalScoreEvent.new(farmId))
        end
    end

    mapFrame.envScoreWindow:setVisible(g_currentMission:getFarmId() ~= FarmManager.SPECTATOR_FARM_ID)
end


---
function EnvironmentalScore:onHarvestScoreReset(farmlandId)
    for i=1, #self.scoreValues do
        local scoreValue = self.scoreValues[i]
        if scoreValue.object ~= nil and scoreValue.object.onHarvestScoreReset ~= nil then
            scoreValue.object:onHarvestScoreReset(farmlandId)
        end
    end
end


---
function EnvironmentalScore:getFarmlandScore(farmlandId)
    local sum = 0
    for i=1, #self.scoreValues do
        sum = sum + self.scoreValues[i].object:getScore(farmlandId) * self.scoreValues[i].maxScore
    end

    return sum
end


---
function EnvironmentalScore:getTotalScoreFromValue(scoreValue, farmId)
    local sumFarmlandSize = 0
    for farmlandId, _farmId in pairs(g_farmlandManager.farmlandMapping) do
        if _farmId == farmId then
            local farmland = g_farmlandManager:getFarmlandById(farmlandId)
            if farmland ~= nil and farmland.totalFieldArea ~= nil and farmland.totalFieldArea > 0.01 then
                sumFarmlandSize = sumFarmlandSize + farmland.totalFieldArea
            end
        end
    end

    local score = 0
    local numValidInfluences = 0
    if scoreValue.object ~= nil then
        for farmlandId, _farmId in pairs(g_farmlandManager.farmlandMapping) do
            if _farmId == farmId then
                local farmland = g_farmlandManager:getFarmlandById(farmlandId)
                if farmland ~= nil and farmland.totalFieldArea ~= nil and farmland.totalFieldArea > 0.01 then
                    score = score + (scoreValue.object:getScore(farmlandId) * scoreValue.maxScore) * (farmland.totalFieldArea / sumFarmlandSize)
                    numValidInfluences = numValidInfluences + 1
                end
            end
        end
    end

    if numValidInfluences == 0 then
        return scoreValue.maxScore * 0.5
    end

    return score
end


---
function EnvironmentalScore:getTotalScore(farmId)
    local sumFarmlandSize = 0

    if farmId ~= FarmManager.SPECTATOR_FARM_ID then
        for farmlandId, _farmId in pairs(g_farmlandManager.farmlandMapping) do
            if _farmId == farmId then
                local farmland = g_farmlandManager:getFarmlandById(farmlandId)
                if farmland ~= nil and farmland.totalFieldArea ~= nil and farmland.totalFieldArea > 0.01 then
                    sumFarmlandSize = sumFarmlandSize + farmland.totalFieldArea
                end
            end
        end

        if sumFarmlandSize > 0 then
            local sum = 0
            for farmlandId, _farmId in pairs(g_farmlandManager.farmlandMapping) do
                if _farmId == farmId then
                    local farmland = g_farmlandManager:getFarmlandById(farmlandId)
                    if farmland ~= nil and farmland.totalFieldArea ~= nil and farmland.totalFieldArea > 0.01 then
                        for i=1, #self.scoreValues do
                            sum = sum + (self.scoreValues[i].object:getScore(farmlandId) * self.scoreValues[i].maxScore) * (farmland.totalFieldArea / sumFarmlandSize)
                        end
                    end
                end
            end

            return sum
        end
    end

    return 50
end












---
function EnvironmentalScore:updateUI()
    if self.mapFrame ~= nil then
        local farmId = g_currentMission:getFarmId()
        local totalScore = self:getTotalScore(farmId)
        local percentage = self:getTotalScore(farmId) / 100
        self.mapFrame.envScoreBarNumber:setText(string.format("%d", MathUtil.round(totalScore)))

        self.mapFrame.envScoreBarDynamic:setSize(self.mapFrame.envScoreBarStatic.size[1] * percentage)

        local uvs = GuiOverlay.getOverlayUVs(self.mapFrame.envScoreBarStatic.overlay, true)
        self.mapFrame.envScoreBarDynamic:setImageUVs(true, uvs[1], uvs[2], uvs[3], uvs[4], (uvs[5] - uvs[1]) * percentage + uvs[1], uvs[6], (uvs[7] - uvs[3]) * percentage + uvs[3], uvs[8])

        local indicatorX = self.mapFrame.envScoreBarStatic.position[1] + self.mapFrame.envScoreBarStatic.size[1] * percentage
        self.mapFrame.envScoreBarIndicator:setPosition(indicatorX - self.mapFrame.envScoreBarIndicator.size[1] * 0.5)
        self.mapFrame.envScoreBarNumber:setPosition(indicatorX - self.mapFrame.envScoreBarNumber.size[1] * 0.5)

        for i=1, #self.scoreValues do
            local scoreValue = self.scoreValues[i]
            if self.mapFrame.envScoreDistributionText[i] ~= nil then
                local score = self:getTotalScoreFromValue(scoreValue, farmId)

                self.mapFrame.envScoreDistributionText[i]:setText(scoreValue.name)
                self.mapFrame.envScoreDistributionValue[i]:setText(string.format("%.1f", MathUtil.round(score, 1)))

                self.mapFrame.envScoreDistributionBar[i]:setSize(self.mapFrame.envScoreDistributionBarBackground[i].size[1] * (score / scoreValue.maxScore))
            end
        end

        local factor = MathUtil.round(self:getSellPriceFactor(farmId) * 100)
        local text = factor >= 1 and self.infoTextPos or (factor <= -1 and self.infoTextNeg or self.infoTextNone)
        self.mapFrame.envScoreInfoText:setText(string.format(text, math.abs(factor)))
    end
end


---
function EnvironmentalScore:onDraw(element, ingameMap)
    if g_currentMission:getFarmId() ~= FarmManager.SPECTATOR_FARM_ID then
        for _, hotspot in pairs(ingameMap.hotspots) do
            if hotspot:isa(FarmlandHotspot) then
                local worldX, worldZ = hotspot:getWorldPosition()

                local objectX = (worldX + ingameMap.worldCenterOffsetX) / ingameMap.worldSizeX * 0.5 + 0.25
                local objectZ = (worldZ + ingameMap.worldCenterOffsetZ) / ingameMap.worldSizeZ * 0.5 + 0.25

                local x, y, _, visible = ingameMap.layout:getMapObjectPosition(objectX, objectZ, hotspot:getWidth(), hotspot:getHeight(), 0, hotspot:getIsPersistent())
                if visible then
                    self:onDrawFieldNumber(element, ingameMap, x + hotspot:getWidth() * 0.5, y, hotspot:getFarmland())
                end
            end
        end
    end
end


---
function EnvironmentalScore:onDrawFieldNumber(element, ingameMap, x, y, farmland)
    local farmlandId = farmland.id
    if farmland.totalFieldArea ~= nil and farmland.totalFieldArea > 0.01 then
        if g_farmlandManager.farmlandMapping[farmlandId] == g_currentMission:getFarmId() then
            self:drawFarmlandScore(x, y, farmland, farmlandId, ingameMap.layout:getIconZoom())
        end
    end
end


---
function EnvironmentalScore:drawFarmlandScore(x, y, dataKey, farmlandId, zoom)
    local alpha = math.min(math.max((zoom / 1.2) - 0.55, 0) / 0.05, 1)
    if alpha == 0 then
        return
    end

    local scale = 1

    local farmlandData = self.ui.farmlandData[dataKey]
    if farmlandData == nil then
        farmlandData = {state = 0}
        self.ui.farmlandData[dataKey] = farmlandData
    end

    local windowWidth, windowHeight = self.ui.fieldInfoWidth * scale, ((self.ui.fieldInfoHeight - self.ui.fieldInfoHeightSmall) * farmlandData.state + self.ui.fieldInfoHeightSmall) * scale
    local windowX, windowY = x - windowWidth * 0.5, y - windowHeight - self.ui.fieldInfoHeightOffset * scale


    local cursorX, cursorY
    if self.currentInputHelpMode == GS_INPUT_HELP_MODE_GAMEPAD then
        cursorX, cursorY = self.mapFrame.mapCursor:getCenter()
    elseif g_inputBinding.mousePosXLast ~= nil then
        cursorX, cursorY = g_inputBinding.mousePosXLast, g_inputBinding.mousePosYLast
    end

    local isHovering = false
    if cursorX ~= nil and cursorX > windowX and cursorX < windowX + windowWidth then
        if cursorY ~= nil and cursorY > windowY and cursorY < windowY + windowHeight then
            isHovering = true
        end
    end

    local target = (isHovering and 1) or 0
    local direction = math.sign(target - farmlandData.state)
    farmlandData.state = math.clamp(farmlandData.state + direction * g_currentDt / 150, 0, 1)

    windowHeight = ((self.ui.fieldInfoHeight - self.ui.fieldInfoHeightSmall) * farmlandData.state + self.ui.fieldInfoHeightSmall) * scale
    windowY = y - windowHeight - self.ui.fieldInfoHeightOffset * scale

    drawFilledRect(windowX, windowY, windowWidth, windowHeight, self.ui.colorBackground[1], self.ui.colorBackground[2], self.ui.colorBackground[3], self.ui.colorBackground[4] * alpha)

    local iconOffsetX = windowWidth * 0.3 - self.ui.iconWidth * scale * 0.5
    local iconOffsetY =  windowHeight - self.ui.topOffset * scale - self.ui.iconHeight * scale
    self.ui.iconOverlay:setDimension(self.ui.iconWidth * scale, self.ui.iconHeight * scale)
    self.ui.iconOverlay:setColor(self.ui.colorMainUI[1], self.ui.colorMainUI[2], self.ui.colorMainUI[3], self.ui.colorMainUI[4] * alpha)
    self.ui.iconOverlay:setPosition(windowX + iconOffsetX, windowY + iconOffsetY)
    self.ui.iconOverlay:render()

    setTextColor(1, 1, 1, alpha)
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_CENTER)

    local score = self:getFarmlandScore(farmlandId)

    renderText(windowX + windowWidth - iconOffsetX - self.ui.iconOverlay.width * 0.5, windowY + iconOffsetY + self.ui.textOffsetHeader * scale, self.ui.textSizeHeader * scale, string.format("%d", score))

    local gradientX, gradientY = windowX + windowWidth * 0.5 - self.ui.gradientOverlay.width * 0.5, windowY + windowHeight - self.ui.topOffset * scale - self.ui.iconOverlay.height - self.ui.spacingY * scale - self.ui.gradientOverlay.height
    self.ui.gradientOverlay:setDimension(self.ui.scoreBarMainWidth * scale, self.ui.scoreBarMainHeight * scale)
    self.ui.gradientOverlay:setColor(1, 1, 1, alpha)
    self.ui.gradientOverlay:setPosition(gradientX, gradientY)
    self.ui.gradientOverlay:render()

    self.ui.gradientIndicatorOverlay:setDimension(self.ui.scoreBarMainIndicatorWidth * scale, self.ui.scoreBarMainIndicatorHeight * scale)
    self.ui.gradientIndicatorOverlay:setColor(1, 1, 1, alpha)
    self.ui.gradientIndicatorOverlay:setPosition(gradientX - self.ui.scoreBarMainIndicatorWidth * scale * 0.5 + (self.ui.gradientOverlay.width * (score/100)), gradientY - (self.ui.scoreBarMainIndicatorHeight-self.ui.scoreBarMainHeight) * 0.5 * scale)
    self.ui.gradientIndicatorOverlay:render()

    if farmlandData.state == 1 then
        for i=1, #self.scoreValues do
            local posX, posY = windowX + windowWidth * 0.5 - self.ui.scoreBarSmallWidth * scale * 0.5, windowY + self.ui.spacingY * scale + (self.ui.scoreBarSmallHeight * scale + self.ui.scoreBarOffset * scale) * (#self.scoreValues-i)
            self.ui.smallBarOverlay:setPosition(posX, posY)
            self.ui.smallBarOverlay:setDimension(self.ui.scoreBarSmallWidth * scale, self.ui.scoreBarSmallHeight * scale)
            self.ui.smallBarOverlay:setColor(self.ui.colorBackground[1], self.ui.colorBackground[2], self.ui.colorBackground[3], self.ui.colorBackground[4] * alpha)
            self.ui.smallBarOverlay:render()

            self.ui.smallBarOverlay:setPosition(posX, posY)
            self.ui.smallBarOverlay:setDimension(self.ui.scoreBarSmallWidth * self.scoreValues[i].object:getScore(farmlandId) * scale, self.ui.scoreBarSmallHeight * scale)
            self.ui.smallBarOverlay:setColor(self.ui.colorMainUI[1], self.ui.colorMainUI[2], self.ui.colorMainUI[3], self.ui.colorMainUI[4] * alpha)
            self.ui.smallBarOverlay:render()
        end
    end
end


---
function EnvironmentalScore:onPeriodChanged(currentPeriod)
    for farmlandId, state in pairs(self.harvestedStates) do
        if state == 2 then
            self.harvestedStates[farmlandId] = 0
            self:onHarvestScoreReset(farmlandId)
        end

        if state == 1 then
            self.harvestedStates[farmlandId] = 2
        end
    end
end


---
function EnvironmentalScore:setColorBlindMode()
    self.isColorBlindMode = g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE)
    local sliceId = self.isColorBlindMode and "precisionFarming.gradient_color_blind" or "precisionFarming.gradient_red_green"

    self.ui.gradientOverlay:setSliceId(sliceId)
    if self.mapFrame ~= nil then
        self.mapFrame.envScoreBarDynamic:setImageSlice(nil, sliceId)
        self.mapFrame.envScoreBarStatic:setImageSlice(nil, sliceId)
    end

    self:updateUI()
end


---
function EnvironmentalScore:overwriteGameFunctions(pfModule)
    for _, object in pairs(self.scoreObjects) do
        object:overwriteGameFunctions(pfModule)
    end

    pfModule:overwriteGameFunction(CoverMap, "preUpdateCoverArea", function(superFunc, coverMap, fruitTypes, densityMapShape, useMinForageState)
        local phMapUpdated, nMapUpdated = superFunc(coverMap, fruitTypes, densityMapShape, useMinForageState)

        local centerX, centerZ = densityMapShape:getCenter()
        local farmlandId = g_farmlandManager:getFarmlandIdAtWorldPosition(centerX, centerZ)
        if farmlandId ~= nil then
            self.harvestedStates[farmlandId] = 1
        end

        return phMapUpdated, nMapUpdated
    end)

    pfModule:overwriteGameFunction(SellingStation, "sellFillType", function(superFunc, sellingStation, farmId, fillDelta, fillTypeIndex, toolType, extraAttributes)
        local price = superFunc(sellingStation, farmId, fillDelta, fillTypeIndex, toolType, extraAttributes)

        local revenue = price * self:getSellPriceFactor(farmId)
        if revenue ~= 0 then
            if self.farmRevenueIncrease[farmId] == nil then
                self.farmRevenueIncrease[farmId] = {revenue=0, lastSellTime=g_time}
            end
            self.farmRevenueIncrease[farmId].revenue = self.farmRevenueIncrease[farmId].revenue + revenue
            self.farmRevenueIncrease[farmId].lastSellTime = g_time

            g_currentMission:addMoney(revenue, farmId, revenue < 0 and self.moneyChangeTypeNeg or self.moneyChangeTypePos, true)

            self.farmRevenueIncreaseMessageDirty = true
        end

        return price
    end)
end
