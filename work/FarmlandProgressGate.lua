FarmlandProgressMessageEvent = {}
local FarmlandProgressMessageEvent_mt = Class(FarmlandProgressMessageEvent, Event)
InitEventClass(FarmlandProgressMessageEvent, "FarmlandProgressMessageEvent")

function FarmlandProgressMessageEvent.emptyNew()
    local self = Event.new(FarmlandProgressMessageEvent_mt)
    return self
end

function FarmlandProgressMessageEvent.new(farmId, text)
    local self = FarmlandProgressMessageEvent.emptyNew()
    self.farmId = farmId
    self.text = text
    return self
end

function FarmlandProgressMessageEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.farmId or 0)
    streamWriteString(streamId, self.text or "")
end

function FarmlandProgressMessageEvent:readStream(streamId, connection)
    self.farmId = streamReadInt32(streamId)
    self.text = streamReadString(streamId)
    self:run(connection)
end

function FarmlandProgressMessageEvent:run(connection)
    if self.text == nil or self.text == "" then
        return
    end

    local localFarmId = 0

    if g_localPlayer ~= nil and g_localPlayer.farmId ~= nil then
        local localFarmIdCandidate = g_localPlayer.farmId
        localFarmId = localFarmIdCandidate or 0
    elseif g_currentMission ~= nil and g_currentMission.player ~= nil and g_currentMission.player.farmId ~= nil then
        local localFarmIdCandidate = g_currentMission.player.farmId
        localFarmId = localFarmIdCandidate or 0
    end

    if self.farmId ~= nil and self.farmId ~= 0 and self.farmId == localFarmId then
        FarmlandProgressGate:showReasonLocal(self.text)
    end
end



FarmlandProgressGate = {}
FarmlandProgressGate.modName = g_currentModName
FarmlandProgressGate.modDirectory = g_currentModDirectory

local LOG_PREFIX = "[FarmlandProgressGate]"
local DEBUG_STATS = false

FarmlandProgressGate.config = {
    defaultBlocked = true,
    whitelist = {}
}

FarmlandProgressGate.metricsConfig = {
    metrics = {},
    metricOrder = {}
}

FarmlandProgressGate.stateTemplate = {
    workedHa = 0,
    plowedHa = 0,
    cultivatedHa = 0,
    sownHa = 0,
    sprayedHa = 0,
    threshedHa = 0,
    workedMinutes = 0,
    plowedMinutes = 0,
    cultivatedMinutes = 0,
    sownMinutes = 0,
    sprayedMinutes = 0,
    threshedMinutes = 0,
    seedUsage = 0,
    sprayUsage = 0,
    woodTonsSold = 0,
    baleCount = 0,
    wrappedBales = 0,
    soldCottonBales = 0,
    plantedTreeCount = 0,
    cutTreeCount = 0,
    traveledDistanceKm = 0,
    fuelUsage = 0,
    expenses = 0,
    horseJumpCount = 0,
    petDogCount = 0,
    repairVehicleCount = 0,
    soldFillTypes = {},
    metricStates = {}
}

FarmlandProgressGate.progressByFarm = {}
FarmlandProgressGate.lastDistanceStatByFarm = {}
FarmlandProgressGate.savegameHooksInstalled = false
FarmlandProgressGate.statsHooksInstalled = false
FarmlandProgressGate.progressDataDirty = false
FarmlandProgressGate.enabled = true
FarmlandProgressGate.externalToggleCache = {
    system = true
}

FarmlandProgressGate.statMappings = {
    workedHectares = {stateKey = "workedHa", scale = 1},
    plowedHectares = {stateKey = "plowedHa", scale = 1},
    cultivatedHectares = {stateKey = "cultivatedHa", scale = 1},
    sownHectares = {stateKey = "sownHa", scale = 1},
    sprayedHectares = {stateKey = "sprayedHa", scale = 1},
    threshedHectares = {stateKey = "threshedHa", scale = 1},

    workedTime = {stateKey = "workedMinutes", scale = 1},
    plowedTime = {stateKey = "plowedMinutes", scale = 1},
    cultivatedTime = {stateKey = "cultivatedMinutes", scale = 1},
    sownTime = {stateKey = "sownMinutes", scale = 1},
    sprayedTime = {stateKey = "sprayedMinutes", scale = 1},
    threshedTime = {stateKey = "threshedMinutes", scale = 1},

    seedUsage = {stateKey = "seedUsage", scale = 1},
    sprayUsage = {stateKey = "sprayUsage", scale = 1},
    woodTonsSold = {stateKey = "woodTonsSold", scale = 1},
    baleCount = {stateKey = "baleCount", scale = 1},
    wrappedBales = {stateKey = "wrappedBales", scale = 1},
    soldCottonBales = {stateKey = "soldCottonBales", scale = 1},
    plantedTreeCount = {stateKey = "plantedTreeCount", scale = 1},
    cutTreeCount = {stateKey = "cutTreeCount", scale = 1},
    traveledDistance = {stateKey = "traveledDistanceKm", scale = 1},
    tractorDistance = {stateKey = "traveledDistanceKm", scale = 1},
    carDistance = {stateKey = "traveledDistanceKm", scale = 1},
    truckDistance = {stateKey = "traveledDistanceKm", scale = 1},
    horseDistance = {stateKey = "traveledDistanceKm", scale = 1},
    fuelUsage = {stateKey = "fuelUsage", scale = 1},
    expenses = {stateKey = "expenses", scale = 1},
    horseJumpCount = {stateKey = "horseJumpCount", scale = 1},
    petDogCount = {stateKey = "petDogCount", scale = 1},
    repairVehicleCount = {stateKey = "repairVehicleCount", scale = 1}
}

FarmlandProgressGate.requirementDefs = {
    {xmlAttr = "requiredWorkedHa", stateKey = "workedHa", label = "обработать", unit = "га", decimals = 1},
    {xmlAttr = "requiredPlowedHa", stateKey = "plowedHa", label = "вспахать", unit = "га", decimals = 1},
    {xmlAttr = "requiredCultivatedHa", stateKey = "cultivatedHa", label = "скультивировать", unit = "га", decimals = 1},
    {xmlAttr = "requiredSownHa", stateKey = "sownHa", label = "засеять", unit = "га", decimals = 1},
    {xmlAttr = "requiredSprayedHa", stateKey = "sprayedHa", label = "удобрить/опрыскать", unit = "га", decimals = 1},
    {xmlAttr = "requiredThreshedHa", stateKey = "threshedHa", label = "убрать", unit = "га", decimals = 1},

    {xmlAttr = "requiredWorkedMinutes", stateKey = "workedMinutes", label = "отработать", unit = "мин", decimals = 1},
    {xmlAttr = "requiredPlowedMinutes", stateKey = "plowedMinutes", label = "вспахивать", unit = "мин", decimals = 1},
    {xmlAttr = "requiredCultivatedMinutes", stateKey = "cultivatedMinutes", label = "культивировать", unit = "мин", decimals = 1},
    {xmlAttr = "requiredSownMinutes", stateKey = "sownMinutes", label = "сеять", unit = "мин", decimals = 1},
    {xmlAttr = "requiredSprayedMinutes", stateKey = "sprayedMinutes", label = "удобрять/опрыскивать", unit = "мин", decimals = 1},
    {xmlAttr = "requiredThreshedMinutes", stateKey = "threshedMinutes", label = "убирать урожай", unit = "мин", decimals = 1},

    {xmlAttr = "requiredSeedUsage", stateKey = "seedUsage", label = "израсходовать семян", unit = "л", decimals = 0},
    {xmlAttr = "requiredSprayUsage", stateKey = "sprayUsage", label = "израсходовать удобрений/гербицидов", unit = "л", decimals = 0},
    {xmlAttr = "requiredWoodTonsSold", stateKey = "woodTonsSold", label = "продать древесины", unit = "т", decimals = 2},
    {xmlAttr = "requiredBaleCount", stateKey = "baleCount", label = "сделать тюков", unit = "шт", decimals = 0},
    {xmlAttr = "requiredWrappedBales", stateKey = "wrappedBales", label = "обмотать тюков", unit = "шт", decimals = 0},
    {xmlAttr = "requiredSoldCottonBales", stateKey = "soldCottonBales", label = "продать хлопковых тюков", unit = "шт", decimals = 0},
    {xmlAttr = "requiredPlantedTreeCount", stateKey = "plantedTreeCount", label = "посадить деревьев", unit = "шт", decimals = 0},
    {xmlAttr = "requiredCutTreeCount", stateKey = "cutTreeCount", label = "спилить деревьев", unit = "шт", decimals = 0},
    {xmlAttr = "requiredTraveledDistanceKm", stateKey = "traveledDistanceKm", label = "проехать", unit = "км", decimals = 1},
    {xmlAttr = "requiredFuelUsage", stateKey = "fuelUsage", label = "израсходовать топлива", unit = "л", decimals = 0},
    {xmlAttr = "requiredExpenses", stateKey = "expenses", label = "потратить", unit = "€", decimals = 0},
    {xmlAttr = "requiredHorseJumpCount", stateKey = "horseJumpCount", label = "сделать прыжков на лошади", unit = "шт", decimals = 0},
    {xmlAttr = "requiredPetDogCount", stateKey = "petDogCount", label = "погладить собаку", unit = "шт", decimals = 0},
    {xmlAttr = "requiredRepairVehicleCount", stateKey = "repairVehicleCount", label = "отремонтировать техники", unit = "шт", decimals = 0}
}

FarmlandProgressGate.sellHookRetryTimer = 0
FarmlandProgressGate.statsHookRetryTimer = 0
FarmlandProgressGate.sellHooksInstalledCount = 0
FarmlandProgressGate.installedUpdateFarmStatsFunc = nil

local function log(msg)
    print(string.format("%s %s", LOG_PREFIX, tostring(msg)))
end

local function debugLog(msg)
    if DEBUG_STATS then
        log(msg)
    end
end

local function roundTo(value, decimals)
    local precision = math.pow(10, decimals or 0)
    return math.floor(value * precision + 0.5) / precision
end

local function normalizeFillTypeName(fillTypeName)
    if fillTypeName == nil then
        return nil
    end

    return string.upper(tostring(fillTypeName))
end

local function safeNumber(value, fallback)
    local numberValue = tonumber(value)
    if numberValue == nil then
        return fallback or 0
    end
    return numberValue
end

function FarmlandProgressGate:isServer()
    if g_currentMission ~= nil and g_currentMission.getIsServer ~= nil then
        return g_currentMission:getIsServer()
    end

    return g_server ~= nil
end

function FarmlandProgressGate:isClient()
    if g_currentMission ~= nil and g_currentMission.getIsClient ~= nil then
        return g_currentMission:getIsClient()
    end

    return g_client ~= nil
end

function FarmlandProgressGate:getToggleBridge()
    local bridge = rawget(_G, "g_svapaToggleBridge") or rawget(_G, "SvapaToggleBridge")
    if bridge ~= nil and type(bridge.getIsEnabled) == "function" then
        return bridge
    end

    return nil
end

function FarmlandProgressGate:isExternallyEnabled(toggleId, fallback)
    if toggleId == nil or toggleId == "" then
        return fallback == true
    end

    local bridge = self:getToggleBridge()
    if bridge == nil then
        return fallback == true
    end

    local ok, value = pcall(function()
        return bridge:getIsEnabled(toggleId, fallback == true)
    end)

    if ok and type(value) == "boolean" then
        return value
    end

    return fallback == true
end

function FarmlandProgressGate:applyExternalToggles()
    local cache = self.externalToggleCache or {}
    cache.system = self:isExternallyEnabled("farmlandProgressGate.enabled", self.enabled == true)
    self.externalToggleCache = cache
end

function FarmlandProgressGate:isSystemEnabled()
    local enabledByTarget = self.enabled ~= false
    local cache = self.externalToggleCache

    if cache ~= nil and cache.system ~= nil then
        return (cache.system == true) and enabledByTarget
    end

    return enabledByTarget
end

function FarmlandProgressGate:markDirty()
    self.progressDataDirty = true
end

function FarmlandProgressGate:createEmptyMetricRuntime(metricDef)
    return {
        adjustment = 0,
        spent = 0
    }
end

function FarmlandProgressGate:createEmptyFarmState()
    local state = {}

    for key, value in pairs(self.stateTemplate) do
        if type(value) == "number" then
            state[key] = 0
        elseif type(value) == "table" then
            state[key] = {}
        end
    end

    state.metricStates = {}
    return state
end

function FarmlandProgressGate:getFarmState(farmId, createIfMissing)
    if farmId == nil or farmId == 0 then
        return nil
    end

    local state = self.progressByFarm[farmId]

    if state == nil and createIfMissing then
        state = self:createEmptyFarmState()
        self.progressByFarm[farmId] = state
        self:markDirty()
    end

    if state ~= nil and state.metricStates == nil then
        state.metricStates = {}
    end

    return state
end

function FarmlandProgressGate:getMetricNames()
    local names = {}
    for _, metricName in ipairs(self.metricsConfig.metricOrder or {}) do
        table.insert(names, metricName)
    end
    return names
end

function FarmlandProgressGate:getMetricDef(metricName)
    if metricName == nil then
        return nil
    end

    return self.metricsConfig.metrics[tostring(metricName)]
end

function FarmlandProgressGate:getMetricRuntimeState(farmId, metricName, createIfMissing)
    local state = self:getFarmState(farmId, createIfMissing)
    if state == nil then
        return nil
    end

    state.metricStates = state.metricStates or {}
    local runtimeState = state.metricStates[metricName]

    if runtimeState == nil and createIfMissing then
        runtimeState = self:createEmptyMetricRuntime(self:getMetricDef(metricName))
        state.metricStates[metricName] = runtimeState
        self:markDirty()
    end

    return runtimeState
end

function FarmlandProgressGate:resetFarmState(farmId)
    if farmId == nil or farmId == 0 then
        return
    end

    self.progressByFarm[farmId] = self:createEmptyFarmState()
    self.lastDistanceStatByFarm[farmId] = nil
    self:markDirty()
end

function FarmlandProgressGate:resetAllProgress()
    self.progressByFarm = {}
    self.lastDistanceStatByFarm = {}
    self:markDirty()
end

function FarmlandProgressGate:getLocalFarmId()
    if g_localPlayer ~= nil and g_localPlayer.farmId ~= nil then
        return g_localPlayer.farmId
    end

    if g_currentMission ~= nil and g_currentMission.player ~= nil and g_currentMission.player.farmId ~= nil then
        return g_currentMission.player.farmId
    end

    return nil
end

function FarmlandProgressGate:getFillTypeDisplayName(fillTypeName)
    local normalized = normalizeFillTypeName(fillTypeName)
    if normalized == nil then
        return ""
    end

    local fillTypeIndex = nil
    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeIndexByName ~= nil then
        fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(normalized)
    end

    if fillTypeIndex ~= nil then
        if g_fillTypeManager.getFillTypeTitleByIndex ~= nil then
            local title = g_fillTypeManager:getFillTypeTitleByIndex(fillTypeIndex)
            if title ~= nil and title ~= "" then
                if g_i18n ~= nil and g_i18n.convertText ~= nil then
                    local converted = g_i18n:convertText(title)
                    if converted ~= nil and converted ~= "" then
                        return converted
                    end
                end

                return title
            end
        end

        if g_fillTypeManager.getFillTypeByIndex ~= nil then
            local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
            if fillType ~= nil and fillType.title ~= nil and fillType.title ~= "" then
                if g_i18n ~= nil and g_i18n.convertText ~= nil then
                    local converted = g_i18n:convertText(fillType.title)
                    if converted ~= nil and converted ~= "" then
                        return converted
                    end
                end

                return fillType.title
            end
        end
    end

    return normalized
end

function FarmlandProgressGate:getSoldFillTypeAmountForFarm(farmId, fillTypeName)
    local state = self:getFarmState(farmId, false)
    if state == nil then
        return 0
    end

    local normalized = normalizeFillTypeName(fillTypeName)
    if normalized == nil then
        return 0
    end

    return state.soldFillTypes[normalized] or 0
end

function FarmlandProgressGate:addSoldFillTypeAmountForFarm(farmId, fillTypeName, amount)
    if farmId == nil or farmId == 0 or type(amount) ~= "number" or amount <= 0 then
        return
    end

    local normalized = normalizeFillTypeName(fillTypeName)
    if normalized == nil then
        return
    end

    local state = self:getFarmState(farmId, true)
    local currentValue = state.soldFillTypes[normalized] or 0
    state.soldFillTypes[normalized] = currentValue + amount
    self:markDirty()
end

function FarmlandProgressGate:recordSoldFillType(farmId, fillTypeIndex, amount, sourceName, requestedAmount)
    if type(amount) ~= "number" or amount <= 0 then
        return
    end

    if not self:isServer() or not self:isSystemEnabled() then
        return
    end

    local fillTypeName = nil
    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeNameByIndex ~= nil then
        fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
    end

    if fillTypeName == nil then
        return
    end

    self:addSoldFillTypeAmountForFarm(farmId, fillTypeName, amount)
    self:debugSellEvent(sourceName, farmId, fillTypeIndex, fillTypeName, requestedAmount, amount)
end

function FarmlandProgressGate:getFarmNameSafe(farmId)
    if farmId == nil or farmId == 0 or g_farmManager == nil or g_farmManager.getFarmById == nil then
        return tostring(farmId)
    end

    local farm = g_farmManager:getFarmById(farmId)
    if farm ~= nil and farm.name ~= nil and farm.name ~= "" then
        return tostring(farm.name)
    end

    return tostring(farmId)
end

function FarmlandProgressGate:debugStatEvent(sourceName, farmId, statName, value, appliedValue, stateKey, newStateValue)
    debugLog(string.format(
        "STAT source=%s farmId=%s farmName=%s stat=%s raw=%s applied=%s stateKey=%s total=%s",
        tostring(sourceName or "unknown"),
        tostring(farmId),
        tostring(self:getFarmNameSafe(farmId)),
        tostring(statName),
        tostring(value),
        tostring(appliedValue),
        tostring(stateKey),
        tostring(newStateValue)
    ))
end

function FarmlandProgressGate:debugSellEvent(sourceName, farmId, fillTypeIndex, fillTypeName, requestedAmount, appliedAmount)
    debugLog(string.format(
        "SELL source=%s farmId=%s farmName=%s fillType=%s fillTypeIndex=%s requested=%s applied=%s",
        tostring(sourceName or "unknown"),
        tostring(farmId),
        tostring(self:getFarmNameSafe(farmId)),
        tostring(fillTypeName),
        tostring(fillTypeIndex),
        tostring(requestedAmount),
        tostring(appliedAmount)
    ))
end

function FarmlandProgressGate:markStationHookInstalled(station, hookKey)
    if station == nil then
        return false
    end

    station.fpgSellHookInstalled = station.fpgSellHookInstalled or {}
    if station.fpgSellHookInstalled[hookKey] then
        return false
    end

    station.fpgSellHookInstalled[hookKey] = true
    return true
end

function FarmlandProgressGate:getSavegameDirectory()
    if g_currentMission == nil then
        return nil
    end

    if g_currentMission.missionInfo ~= nil and g_currentMission.missionInfo.savegameDirectory ~= nil and g_currentMission.missionInfo.savegameDirectory ~= "" then
        return g_currentMission.missionInfo.savegameDirectory
    end

    if g_currentMission.currentMissionInfo ~= nil and g_currentMission.currentMissionInfo.savegameDirectory ~= nil and g_currentMission.currentMissionInfo.savegameDirectory ~= "" then
        return g_currentMission.currentMissionInfo.savegameDirectory
    end

    return nil
end

function FarmlandProgressGate:getProgressSavegamePath()
    local savegameDirectory = self:getSavegameDirectory()
    if savegameDirectory == nil or savegameDirectory == "" then
        return nil
    end

    if string.sub(savegameDirectory, -1) == "/" or string.sub(savegameDirectory, -1) == "\\" then
        return savegameDirectory .. "farmlandProgressGate.xml"
    end

    return savegameDirectory .. "/farmlandProgressGate.xml"
end

function FarmlandProgressGate:createXmlFile(rootName)
    local xmlPath = self:getProgressSavegamePath()
    if xmlPath == nil or xmlPath == "" then
        return nil
    end

    local xmlFile = createXMLFile("FarmlandProgressGateSave", xmlPath, rootName)
    if xmlFile == nil or xmlFile == 0 then
        return nil
    end

    return xmlFile
end

function FarmlandProgressGate:loadXmlFile(rootName)
    local xmlPath = self:getProgressSavegamePath()
    if xmlPath == nil or xmlPath == "" or not fileExists(xmlPath) then
        return nil
    end

    local xmlFile = loadXMLFile("FarmlandProgressGateSave", xmlPath)
    if xmlFile == nil or xmlFile == 0 then
        return nil
    end

    return xmlFile
end

-- =====================================================
-- CONFIG
-- =====================================================

function FarmlandProgressGate:loadConfig()
    local path = self.modDirectory .. "map/config/farmlandProgress.xml"

    if path == nil or path == "" then
        log("Config path is invalid")
        return
    end

    if not fileExists(path) then
        log("Config not found: " .. tostring(path))
        return
    end

    local xml = loadXMLFile("farmlandProgressXML", path)
    if xml == nil or xml == 0 then
        log("Failed to load config XML: " .. tostring(path))
        return
    end

    local defaultBlocked = getXMLBool(xml, "farmlandProgress.settings#defaultBlocked")
    if defaultBlocked ~= nil then
        self.config.defaultBlocked = defaultBlocked
    else
        self.config.defaultBlocked = true
    end

    self.config.whitelist = {}

    local i = 0
    while true do
        local key = string.format("farmlandProgress.farmlands.farmland(%d)", i)
        if not hasXMLProperty(xml, key) then
            break
        end

        local farmlandId = getXMLInt(xml, key .. "#id")
        if farmlandId ~= nil then
            local rule = {
                text = getXMLString(xml, key .. "#text") or "",
                requirements = {},
                soldFillTypes = {},
                metricRequirements = {}
            }

            for _, def in ipairs(self.requirementDefs) do
                local value = getXMLFloat(xml, key .. "#" .. def.xmlAttr)
                if value ~= nil and value > 0 then
                    table.insert(rule.requirements, {
                        xmlAttr = def.xmlAttr,
                        stateKey = def.stateKey,
                        label = def.label,
                        unit = def.unit,
                        decimals = def.decimals,
                        required = value
                    })
                end
            end

            local j = 0
            while true do
                local soldKey = string.format("%s.soldFillType(%d)", key, j)
                if not hasXMLProperty(xml, soldKey) then
                    break
                end

                local fillTypeName = normalizeFillTypeName(getXMLString(xml, soldKey .. "#fillType"))
                local amount = getXMLFloat(xml, soldKey .. "#amount")

                if fillTypeName ~= nil and fillTypeName ~= "" and amount ~= nil and amount > 0 then
                    table.insert(rule.soldFillTypes, {
                        fillType = fillTypeName,
                        amount = amount
                    })
                end

                j = j + 1
            end

            for _, metricName in ipairs(self.metricsConfig.metricOrder or {}) do
                local metricDef = self:getMetricDef(metricName)
                if metricDef ~= nil then
                    local earnedValue = getXMLFloat(xml, key .. "#requiredMetricEarned_" .. metricName)
                    if earnedValue ~= nil and earnedValue > 0 then
                        table.insert(rule.metricRequirements, {
                            metricName = metricName,
                            field = "earned",
                            required = earnedValue,
                            label = metricDef.label or metricName,
                            roundDigits = metricDef.roundDigits or 0
                        })
                    end

                    local availableAttr = key .. "#requiredMetric_" .. metricName
                    local availableValue = getXMLFloat(xml, availableAttr)
                    if availableValue == nil then
                        availableValue = getXMLFloat(xml, key .. "#requiredMetricAvailable_" .. metricName)
                    end
                    if availableValue ~= nil and availableValue > 0 then
                        table.insert(rule.metricRequirements, {
                            metricName = metricName,
                            field = "available",
                            required = availableValue,
                            label = metricDef.label or metricName,
                            roundDigits = metricDef.roundDigits or 0
                        })
                    end

                    if metricDef.trackSpent then
                        local spentValue = getXMLFloat(xml, key .. "#requiredMetricSpent_" .. metricName)
                        if spentValue ~= nil and spentValue > 0 then
                            table.insert(rule.metricRequirements, {
                                metricName = metricName,
                                field = "spent",
                                required = spentValue,
                                label = metricDef.label or metricName,
                                roundDigits = metricDef.roundDigits or 0
                            })
                        end
                    end
                end
            end

            self.config.whitelist[farmlandId] = rule

            log(string.format(
                "Loaded rule: farmlandId=%d requirements=%d soldFillTypes=%d metricRequirements=%d",
                farmlandId,
                #rule.requirements,
                #rule.soldFillTypes,
                #rule.metricRequirements
            ))
        end

        i = i + 1
    end

    delete(xml)
end

function FarmlandProgressGate:loadMetricsConfig()
    local path = self.modDirectory .. "map/config/metricsConfig.xml"

    self.metricsConfig = {
        metrics = {},
        metricOrder = {}
    }

    if path == nil or path == "" then
        log("Metrics config path is invalid")
        return
    end

    if not fileExists(path) then
        log("Metrics config not found: " .. tostring(path))
        return
    end

    local xml = loadXMLFile("farmlandProgressMetricsXML", path)
    if xml == nil or xml == 0 then
        log("Failed to load metrics config XML: " .. tostring(path))
        return
    end

    local i = 0
    while true do
        local metricKey = string.format("metrics.metric(%d)", i)
        if not hasXMLProperty(xml, metricKey) then
            break
        end

        local metricName = getXMLString(xml, metricKey .. "#name")
        if metricName ~= nil and metricName ~= "" then
            local trackSpent = getXMLBool(xml, metricKey .. "#trackSpent")
            local roundDigits = getXMLInt(xml, metricKey .. "#roundDigits")
            local metricDef = {
                name = tostring(metricName),
                label = getXMLString(xml, metricKey .. "#label") or tostring(metricName),
                trackSpent = trackSpent == true,
                roundDigits = roundDigits ~= nil and roundDigits or 0,
                sources = {}
            }

            local j = 0
            while true do
                local sourceKey = string.format("%s.source(%d)", metricKey, j)
                if not hasXMLProperty(xml, sourceKey) then
                    break
                end

                local sourceType = getXMLString(xml, sourceKey .. "#type") or "state"
                local coefficient = getXMLFloat(xml, sourceKey .. "#coefficient") or 0

                local sourceDef = {
                    type = tostring(sourceType),
                    coefficient = coefficient,
                    key = getXMLString(xml, sourceKey .. "#key"),
                    fillType = normalizeFillTypeName(getXMLString(xml, sourceKey .. "#fillType")),
                    label = getXMLString(xml, sourceKey .. "#label")
                }

                table.insert(metricDef.sources, sourceDef)
                j = j + 1
            end

            self.metricsConfig.metrics[metricDef.name] = metricDef
            table.insert(self.metricsConfig.metricOrder, metricDef.name)

            log(string.format(
                "Loaded metric: name=%s sources=%d trackSpent=%s",
                tostring(metricDef.name),
                #metricDef.sources,
                tostring(metricDef.trackSpent)
            ))
        end

        i = i + 1
    end

    delete(xml)
end

-- =====================================================
-- SAVEGAME
-- =====================================================

function FarmlandProgressGate:loadFromXMLFile(xmlFile, key)
    if xmlFile == nil or xmlFile == 0 or key == nil then
        return
    end

    self.progressByFarm = {}

    local i = 0
    while true do
        local farmKey = string.format("%s.farm(%d)", key, i)
        if not hasXMLProperty(xmlFile, farmKey) then
            break
        end

        local farmId = getXMLInt(xmlFile, farmKey .. "#farmId")
        if farmId ~= nil and farmId ~= 0 then
            local state = self:getFarmState(farmId, true)

            for stateKey, value in pairs(self.stateTemplate) do
                if type(value) == "number" then
                    state[stateKey] = getXMLFloat(xmlFile, farmKey .. "#" .. stateKey) or 0
                end
            end

            state.soldFillTypes = {}
            state.metricStates = {}

            local j = 0
            while true do
                local soldKey = string.format("%s.soldFillTypes.fillType(%d)", farmKey, j)
                if not hasXMLProperty(xmlFile, soldKey) then
                    break
                end

                local fillTypeName = normalizeFillTypeName(getXMLString(xmlFile, soldKey .. "#name"))
                local amount = getXMLFloat(xmlFile, soldKey .. "#amount") or 0

                if fillTypeName ~= nil and fillTypeName ~= "" and amount > 0 then
                    state.soldFillTypes[fillTypeName] = amount
                end

                j = j + 1
            end

            local k = 0
            while true do
                local metricKey = string.format("%s.metrics.metric(%d)", farmKey, k)
                if not hasXMLProperty(xmlFile, metricKey) then
                    break
                end

                local metricName = getXMLString(xmlFile, metricKey .. "#name")
                if metricName ~= nil and metricName ~= "" then
                    state.metricStates[metricName] = {
                        adjustment = getXMLFloat(xmlFile, metricKey .. "#adjustment") or 0,
                        spent = getXMLFloat(xmlFile, metricKey .. "#spent") or 0
                    }
                end

                k = k + 1
            end
        end

        i = i + 1
    end

    self.progressDataDirty = false
    log("Progress state loaded from savegame")
end

function FarmlandProgressGate:saveToXMLFile(xmlFile, key, usedModNames)
    if xmlFile == nil or xmlFile == 0 or key == nil then
        return
    end

    local i = 0
    for farmId, state in pairs(self.progressByFarm) do
        local farmKey = string.format("%s.farm(%d)", key, i)

        setXMLInt(xmlFile, farmKey .. "#farmId", farmId)

        for stateKey, value in pairs(self.stateTemplate) do
            if type(value) == "number" then
                setXMLFloat(xmlFile, farmKey .. "#" .. stateKey, state[stateKey] or 0)
            end
        end

        local j = 0
        for fillTypeName, amount in pairs(state.soldFillTypes or {}) do
            local soldKey = string.format("%s.soldFillTypes.fillType(%d)", farmKey, j)
            setXMLString(xmlFile, soldKey .. "#name", tostring(fillTypeName))
            setXMLFloat(xmlFile, soldKey .. "#amount", amount or 0)
            j = j + 1
        end

        local k = 0
        for metricName, metricState in pairs(state.metricStates or {}) do
            local metricKey = string.format("%s.metrics.metric(%d)", farmKey, k)
            setXMLString(xmlFile, metricKey .. "#name", tostring(metricName))
            setXMLFloat(xmlFile, metricKey .. "#adjustment", safeNumber(metricState.adjustment, 0))
            setXMLFloat(xmlFile, metricKey .. "#spent", safeNumber(metricState.spent, 0))
            k = k + 1
        end

        i = i + 1
    end
end

function FarmlandProgressGate:loadProgressFromSavegameFile()
    if not self:isServer() then
        return
    end

    local xmlFile = self:loadXmlFile("farmlandProgress")
    if xmlFile == nil or xmlFile == 0 then
        log("No custom progress savegame file found, starting with empty state")
        return
    end

    self:loadFromXMLFile(xmlFile, "farmlandProgress")
    delete(xmlFile)
end

function FarmlandProgressGate:saveProgressToSavegameFile()
    if not self:isServer() then
        return
    end

    local xmlFile = self:createXmlFile("farmlandProgress")
    if xmlFile == nil or xmlFile == 0 then
        log("Failed to create custom progress savegame XML file")
        return
    end

    self:saveToXMLFile(xmlFile, "farmlandProgress", nil)
    saveXMLFile(xmlFile)
    delete(xmlFile)
    self.progressDataDirty = false
    debugLog("Progress state saved to custom savegame file")
end

function FarmlandProgressGate:installSavegameHooks()
    if self.savegameHooksInstalled then
        return
    end

    if g_currentMission == nil then
        return
    end

    local installed = false

    if type(g_currentMission.saveToXMLFile) == "function" then
        g_currentMission.saveToXMLFile = Utils.appendedFunction(g_currentMission.saveToXMLFile, function(...)
            FarmlandProgressGate:saveProgressToSavegameFile()
        end)
        installed = true
    end

    if type(g_currentMission.saveSavegame) == "function" then
        g_currentMission.saveSavegame = Utils.appendedFunction(g_currentMission.saveSavegame, function(...)
            FarmlandProgressGate:saveProgressToSavegameFile()
        end)
        installed = true
    end

    if installed then
        self.savegameHooksInstalled = true
        log("Savegame hooks installed")
    else
        log("Warning: no savegame hook target found, fallback will be deleteMap only")
    end
end

-- =====================================================
-- METRICS
-- =====================================================

function FarmlandProgressGate:getNumericProgressKeys()
    local keys = {}
    for key, value in pairs(self.stateTemplate) do
        if type(value) == "number" then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    return keys
end

function FarmlandProgressGate:getMetricSourceValueForFarm(farmId, sourceDef, state)
    if sourceDef == nil then
        return 0
    end

    state = state or self:getFarmState(farmId, false)
    if state == nil then
        return 0
    end

    if sourceDef.type == "state" then
        local sourceKey = sourceDef.key
        if sourceKey == nil or sourceKey == "" then
            return 0
        end

        return safeNumber(state[sourceKey], 0)
    end

    if sourceDef.type == "soldFillType" then
        local fillTypeName = sourceDef.fillType
        if fillTypeName == nil or fillTypeName == "" then
            return 0
        end

        if fillTypeName == "*" or fillTypeName == "ALL" then
            local total = 0
            for _, amount in pairs(state.soldFillTypes or {}) do
                total = total + safeNumber(amount, 0)
            end
            return total
        end

        return safeNumber((state.soldFillTypes or {})[fillTypeName], 0)
    end

    return 0
end

function FarmlandProgressGate:calculateMetricComputedValue(farmId, metricName, state)
    local metricDef = self:getMetricDef(metricName)
    if metricDef == nil then
        return 0
    end

    state = state or self:getFarmState(farmId, false)
    if state == nil then
        return 0
    end

    local computed = 0

    for _, sourceDef in ipairs(metricDef.sources or {}) do
        local sourceValue = self:getMetricSourceValueForFarm(farmId, sourceDef, state)
        local coefficient = safeNumber(sourceDef.coefficient, 0)
        computed = computed + (sourceValue * coefficient)
    end

    if metricDef.roundDigits ~= nil then
        computed = roundTo(computed, metricDef.roundDigits)
    end

    return computed
end

function FarmlandProgressGate:getMetricSnapshotForFarm(farmId, metricName)
    local metricDef = self:getMetricDef(metricName)
    if metricDef == nil then
        return nil
    end

    local state = self:getFarmState(farmId, false)
    local runtimeState = self:getMetricRuntimeState(farmId, metricName, false)
    local computed = self:calculateMetricComputedValue(farmId, metricName, state)
    local adjustment = 0
    local spent = 0

    if runtimeState ~= nil then
        adjustment = safeNumber(runtimeState.adjustment, 0)
        spent = safeNumber(runtimeState.spent, 0)
    end

    local earned = computed + adjustment
    if metricDef.roundDigits ~= nil then
        earned = roundTo(earned, metricDef.roundDigits)
    end

    local available = earned
    if metricDef.trackSpent then
        available = earned - spent
        if metricDef.roundDigits ~= nil then
            available = roundTo(available, metricDef.roundDigits)
        end
    end

    return {
        name = metricDef.name,
        label = metricDef.label,
        trackSpent = metricDef.trackSpent,
        roundDigits = metricDef.roundDigits,
        computed = computed,
        adjustment = adjustment,
        earned = earned,
        spent = spent,
        available = available
    }
end

function FarmlandProgressGate:getAllMetricSnapshotsForFarm(farmId)
    local result = {}
    for _, metricName in ipairs(self.metricsConfig.metricOrder or {}) do
        local snapshot = self:getMetricSnapshotForFarm(farmId, metricName)
        if snapshot ~= nil then
            result[metricName] = snapshot
        end
    end
    return result
end

function FarmlandProgressGate:getAllProgressDataForFarm(farmId)
    local state = self:getFarmState(farmId, false)
    local data = {
        state = {},
        soldFillTypes = {},
        metrics = self:getAllMetricSnapshotsForFarm(farmId)
    }

    if state == nil then
        return data
    end

    for key, value in pairs(state) do
        if type(value) == "number" then
            data.state[key] = value
        end
    end

    for fillTypeName, amount in pairs(state.soldFillTypes or {}) do
        data.soldFillTypes[fillTypeName] = amount
    end

    return data
end

function FarmlandProgressGate:setMetricFieldValue(farmId, metricName, fieldName, value)
    local metricDef = self:getMetricDef(metricName)
    if metricDef == nil then
        return false, "Unknown metric"
    end

    local runtimeState = self:getMetricRuntimeState(farmId, metricName, true)
    if runtimeState == nil then
        return false, "No runtime state"
    end

    fieldName = tostring(fieldName or "earned")
    value = safeNumber(value, 0)
    local snapshot = self:getMetricSnapshotForFarm(farmId, metricName)
    local computed = snapshot ~= nil and snapshot.computed or 0
    local currentEarned = snapshot ~= nil and snapshot.earned or computed

    if fieldName == "earned" or fieldName == "value" then
        runtimeState.adjustment = value - computed
    elseif fieldName == "adjustment" then
        runtimeState.adjustment = value
    elseif fieldName == "spent" then
        if not metricDef.trackSpent then
            return false, "Metric does not track spent"
        end
        runtimeState.spent = value
    elseif fieldName == "available" then
        if metricDef.trackSpent then
            runtimeState.spent = currentEarned - value
        else
            runtimeState.adjustment = value - computed
        end
    else
        return false, "Unsupported metric field"
    end

    self:markDirty()
    return true, nil
end

function FarmlandProgressGate:addMetricFieldValue(farmId, metricName, fieldName, delta)
    local snapshot = self:getMetricSnapshotForFarm(farmId, metricName)
    if snapshot == nil then
        return false, "Unknown metric"
    end

    fieldName = tostring(fieldName or "earned")
    local currentValue = 0

    if fieldName == "earned" or fieldName == "value" then
        currentValue = snapshot.earned
        fieldName = "earned"
    elseif fieldName == "adjustment" then
        currentValue = snapshot.adjustment
    elseif fieldName == "spent" then
        currentValue = snapshot.spent
    elseif fieldName == "available" then
        currentValue = snapshot.available
    else
        return false, "Unsupported metric field"
    end

    return self:setMetricFieldValue(farmId, metricName, fieldName, currentValue + safeNumber(delta, 0))
end

function FarmlandProgressGate:resetMetricValue(farmId, metricName)
    local runtimeState = self:getMetricRuntimeState(farmId, metricName, true)
    if runtimeState == nil then
        return false
    end

    runtimeState.adjustment = 0
    runtimeState.spent = 0
    self:markDirty()
    return true
end

-- =====================================================
-- LOGIC
-- =====================================================

function FarmlandProgressGate:getRule(farmlandId)
    if farmlandId == nil then
        return nil
    end

    return self.config.whitelist[farmlandId]
end

function FarmlandProgressGate:formatRequirementProgress(current, required, decimals, unit)
    local roundedCurrent = roundTo(current or 0, decimals or 0)
    local roundedRequired = roundTo(required or 0, decimals or 0)
    local unitSuffix = ""

    if unit ~= nil and unit ~= "" then
        unitSuffix = " " .. tostring(unit)
    end

    return string.format(
        "%." .. (decimals or 0) .. "f / %." .. (decimals or 0) .. "f%s",
        roundedCurrent,
        roundedRequired,
        unitSuffix
    )
end

function FarmlandProgressGate:buildRequirementMessage(farmId, requirement, compact)
    local state = self:getFarmState(farmId, false)
    local current = 0
    if state ~= nil then
        current = state[requirement.stateKey] or 0
    end

    local required = requirement.required or 0
    local decimals = requirement.decimals or 0
    local progressText = self:formatRequirementProgress(current, required, decimals, requirement.unit)

    if compact then
        return progressText
    end

    return string.format(
        "%s: %s",
        tostring(requirement.label),
        progressText
    )
end

function FarmlandProgressGate:buildSoldFillTypeMessage(farmId, requirement, compact)
    local current = self:getSoldFillTypeAmountForFarm(farmId, requirement.fillType)
    local required = requirement.amount or 0
    local displayName = self:getFillTypeDisplayName(requirement.fillType)
    local progressText = self:formatRequirementProgress(current, required, 0, "л")

    if compact then
        return progressText
    end

    return string.format(
        "продать %s: %s",
        tostring(displayName),
        progressText
    )
end

function FarmlandProgressGate:buildMetricRequirementMessage(farmId, requirement, compact)
    local snapshot = self:getMetricSnapshotForFarm(farmId, requirement.metricName)
    local current = 0
    if snapshot ~= nil then
        current = safeNumber(snapshot[requirement.field], 0)
    end

    local required = requirement.required or 0
    local decimals = requirement.roundDigits or 0
    local progressText = self:formatRequirementProgress(current, required, decimals, nil)

    if compact then
        return progressText
    end

    local fieldLabel = "значение"
    if requirement.field == "earned" then
        fieldLabel = "заработано"
    elseif requirement.field == "spent" then
        fieldLabel = "потрачено"
    elseif requirement.field == "available" then
        fieldLabel = "доступно"
    end

    return string.format(
        "%s (%s): %s",
        tostring(requirement.label or requirement.metricName),
        tostring(fieldLabel),
        progressText
    )
end

function FarmlandProgressGate:getBlockReason(farmlandId, farmId)
    if farmlandId == nil then
        return true, "Не удалось определить участок"
    end

    if farmlandId == 1 then
        return false, nil
    end

    local rule = self:getRule(farmlandId)
    if rule == nil then
        if self.config.defaultBlocked then
            return true, "Этот участок пока недоступен для покупки"
        end

        return false, nil
    end

    local state = self:getFarmState(farmId, false)
    local failedMessages = {}

    for _, requirement in ipairs(rule.requirements) do
        local currentValue = 0
        if state ~= nil then
            currentValue = state[requirement.stateKey] or 0
        end

        local requiredValue = requirement.required or 0
        if currentValue + 0.00001 < requiredValue then
            table.insert(failedMessages, self:buildRequirementMessage(farmId, requirement))
        end
    end

    for _, soldRequirement in ipairs(rule.soldFillTypes) do
        local currentValue = self:getSoldFillTypeAmountForFarm(farmId, soldRequirement.fillType)
        local requiredValue = soldRequirement.amount or 0
        if currentValue + 0.00001 < requiredValue then
            table.insert(failedMessages, self:buildSoldFillTypeMessage(farmId, soldRequirement))
        end
    end

    for _, metricRequirement in ipairs(rule.metricRequirements or {}) do
        local snapshot = self:getMetricSnapshotForFarm(farmId, metricRequirement.metricName)
        local currentValue = 0
        if snapshot ~= nil then
            currentValue = safeNumber(snapshot[metricRequirement.field], 0)
        end

        local requiredValue = metricRequirement.required or 0
        if currentValue + 0.00001 < requiredValue then
            table.insert(failedMessages, self:buildMetricRequirementMessage(farmId, metricRequirement))
        end
    end

    if #failedMessages > 0 then
        local prefix = rule.text
        if prefix ~= nil and prefix ~= "" then
            return true, string.format("%s:\n• %s", prefix, table.concat(failedMessages, "\n• "))
        end

        return true, table.concat(failedMessages, "\n")
    end

    return false, nil
end

function FarmlandProgressGate:showReasonLocal(text)
    if text == nil or text == "" then
        return
    end

    if InfoDialog ~= nil and InfoDialog.show ~= nil then
        InfoDialog.show(text)
        return
    end

    if g_currentMission ~= nil and g_currentMission.showBlinkingWarning ~= nil then
        g_currentMission:showBlinkingWarning(text, 3000)
    else
        print(string.format("%s %s", LOG_PREFIX, tostring(text)))
    end
end

function FarmlandProgressGate:showReasonForFarm(farmId, text)
    if text == nil or text == "" then
        return
    end

    local localFarmId = self:getLocalFarmId()

    if self:isServer() and g_server ~= nil and self:isClient() and localFarmId ~= nil and localFarmId == farmId then
        self:showReasonLocal(text)
    end

    if self:isServer() and g_server ~= nil then
        g_server:broadcastEvent(FarmlandProgressMessageEvent.new(farmId, text), nil, nil, nil)
    elseif self:isClient() then
        self:showReasonLocal(text)
    else
        self:showReasonLocal(text)
    end
end

function FarmlandProgressGate:refundBlockedPurchase(farmlandId, farmId)
    if g_currentMission == nil or g_currentMission.addMoney == nil then
        return
    end

    if not self:isServer() then
        return
    end

    local farmland = g_farmlandManager:getFarmlandById(farmlandId)
    if farmland == nil then
        log(string.format("Refund skipped: farmlandId=%s not found", tostring(farmlandId)))
        return
    end

    local price = farmland.price or 0
    if price <= 0 then
        log(string.format("Refund skipped: farmlandId=%s invalid price=%s", tostring(farmlandId), tostring(price)))
        return
    end

    g_currentMission:addMoney(price, farmId, MoneyType.SHOP_PROPERTY_BUY, true)

    log(string.format(
        "Refunded blocked purchase: farmlandId=%s farmId=%s price=%s",
        tostring(farmlandId),
        tostring(farmId),
        tostring(price)
    ))
end

function FarmlandProgressGate:isVehicleSpecificDistanceStat(statName)
    return statName == "tractorDistance"
        or statName == "carDistance"
        or statName == "truckDistance"
end

function FarmlandProgressGate:shouldIgnoreDuplicateDistanceStat(farmId, statName, deltaValue)
    if farmId == nil or farmId == 0 or type(deltaValue) ~= "number" then
        return false
    end

    if statName == "traveledDistance" then
        self.lastDistanceStatByFarm[farmId] = {
            value = deltaValue,
            time = g_time or 0
        }
        return false
    end

    if not self:isVehicleSpecificDistanceStat(statName) then
        return false
    end

    local lastDistanceStat = self.lastDistanceStatByFarm[farmId]
    if lastDistanceStat == nil then
        return false
    end

    local now = g_time or 0
    if math.abs((lastDistanceStat.value or 0) - deltaValue) < 0.00001 and (now - (lastDistanceStat.time or 0)) <= 1000 then
        return true
    end

    return false
end

function FarmlandProgressGate:addProgressByStat(farmId, statName, deltaValue, sourceName)
    if not self:isServer() or not self:isSystemEnabled() then
        return
    end

    if self:shouldIgnoreDuplicateDistanceStat(farmId, statName, deltaValue) then
        debugLog(string.format("STAT skipped as duplicate distance source=%s farmId=%s stat=%s value=%s", tostring(sourceName or "unknown"), tostring(farmId), tostring(statName), tostring(deltaValue)))
        return
    end

    local mapping = self.statMappings[statName]
    if mapping == nil then
        debugLog(string.format("STAT ignored source=%s farmId=%s stat=%s value=%s reason=no_mapping", tostring(sourceName or "unknown"), tostring(farmId), tostring(statName), tostring(deltaValue)))
        return
    end

    if farmId == nil or farmId == 0 then
        debugLog(string.format("STAT ignored source=%s farmId=%s stat=%s value=%s reason=invalid_farm", tostring(sourceName or "unknown"), tostring(farmId), tostring(statName), tostring(deltaValue)))
        return
    end

    local state = self:getFarmState(farmId, true)
    local stateKey = mapping.stateKey
    local scale = mapping.scale or 1
    local currentValue = state[stateKey] or 0
    local appliedValue = deltaValue * scale

    state[stateKey] = currentValue + appliedValue
    self:markDirty()
    self:debugStatEvent(sourceName, farmId, statName, deltaValue, appliedValue, stateKey, state[stateKey])
end

-- =====================================================
-- HOOKS
-- =====================================================

function FarmlandProgressGate:installFarmlandHooks()
    if g_farmlandManager == nil then
        log("g_farmlandManager is nil")
        return
    end

    local manager = g_farmlandManager

    if type(manager.setLandOwnership) ~= "function" then
        log("setLandOwnership not found")
        return
    end

    manager.setLandOwnership = Utils.overwrittenFunction(manager.setLandOwnership, function(selfObj, superFunc, farmlandId, farmId, loadFromSavegame, ...)
        if not FarmlandProgressGate:isServer() then
            return superFunc(selfObj, farmlandId, farmId, loadFromSavegame, ...)
        end

        local currentOwner = selfObj:getFarmlandOwner(farmlandId)

        if loadFromSavegame == true then
            return superFunc(selfObj, farmlandId, farmId, loadFromSavegame, ...)
        end

        if farmId == FarmlandManager.NO_OWNER_FARM_ID then
            return superFunc(selfObj, farmlandId, farmId, loadFromSavegame, ...)
        end

        if currentOwner == farmId then
            return superFunc(selfObj, farmlandId, farmId, loadFromSavegame, ...)
        end

        if not FarmlandProgressGate:isSystemEnabled() then
            return superFunc(selfObj, farmlandId, farmId, loadFromSavegame, ...)
        end

        local blocked, reason = FarmlandProgressGate:getBlockReason(farmlandId, farmId)
        if blocked then
            FarmlandProgressGate:refundBlockedPurchase(farmlandId, farmId)
            FarmlandProgressGate:showReasonForFarm(farmId, reason)
            log(string.format(
                "Blocked farmland purchase: farmlandId=%s farmId=%s reason=%s",
                tostring(farmlandId),
                tostring(farmId),
                tostring(reason)
            ))
            return false
        end

        local result = superFunc(selfObj, farmlandId, farmId, loadFromSavegame, ...)

        if result ~= false and FarmlandProgressGate:isSystemEnabled() then
            local rule = FarmlandProgressGate:getRule(farmlandId)
            if rule ~= nil and rule.metricRequirements ~= nil then
                for _, metricRequirement in ipairs(rule.metricRequirements) do
                    if metricRequirement.field == "available" then
                        local metricName = metricRequirement.metricName
                        local requiredValue = safeNumber(metricRequirement.required, 0)

                        if metricName ~= nil and metricName ~= "" and requiredValue > 0 then
                            local runtimeState = FarmlandProgressGate:getMetricRuntimeState(farmId, metricName, true)
                            if runtimeState ~= nil then
                                runtimeState.spent = safeNumber(runtimeState.spent, 0) + requiredValue
                                FarmlandProgressGate:markDirty()

                                log(string.format(
                                    "Metric spent after purchase: farmlandId=%s farmId=%s metric=%s spent+=%s",
                                    tostring(farmlandId),
                                    tostring(farmId),
                                    tostring(metricName),
                                    tostring(requiredValue)
                                ))
                            end
                        end
                    end
                end
            end
        end

        return result
    end)

    log("Hook installed on setLandOwnership")
end

function FarmlandProgressGate:installStatsHooks()
    if not self:isServer() then
        return false
    end

    if g_farmManager == nil then
        log("g_farmManager is nil")
        return false
    end

    local manager = g_farmManager

    if type(manager.updateFarmStats) ~= "function" then
        log("updateFarmStats not found")
        return false
    end

    if self.statsHooksInstalled and self.installedUpdateFarmStatsFunc ~= nil and manager.updateFarmStats == self.installedUpdateFarmStatsFunc then
        return true
    end

    local wrappedFunction = Utils.overwrittenFunction(manager.updateFarmStats, function(selfObj, superFunc, farmId, statName, value, ...)
        local total, changed = superFunc(selfObj, farmId, statName, value, ...)

        if FarmlandProgressGate:isServer() then
            debugLog(string.format("updateFarmStats called farmId=%s stat=%s value=%s total=%s changed=%s", tostring(farmId), tostring(statName), tostring(value), tostring(total), tostring(changed)))

            if type(value) == "number" and value ~= 0 then
                FarmlandProgressGate:addProgressByStat(farmId, statName, value, "updateFarmStats")
            end
        end

        return total, changed
    end)

    manager.updateFarmStats = wrappedFunction
    self.installedUpdateFarmStatsFunc = wrappedFunction
    self.statsHooksInstalled = true
    log("Hook installed on updateFarmStats")
    return true
end

function FarmlandProgressGate:installStationFillHook(station, methodName, sourceName)
    if station == nil or type(station[methodName]) ~= "function" or not self:markStationHookInstalled(station, methodName) then
        return false
    end

    station[methodName] = Utils.overwrittenFunction(station[methodName], function(selfObj, superFunc, farmId, fillLevelDelta, fillTypeIndex, ...)
        local applied = superFunc(selfObj, farmId, fillLevelDelta, fillTypeIndex, ...)

        if type(applied) == "number" then
            FarmlandProgressGate:debugSellEvent(sourceName, farmId, fillTypeIndex, g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeNameByIndex ~= nil and g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex) or nil, fillLevelDelta, applied)
        end

        if type(applied) == "number" and applied > 0 and fillTypeIndex ~= nil then
            FarmlandProgressGate:recordSoldFillType(farmId, fillTypeIndex, applied, sourceName, fillLevelDelta)
        end

        return applied
    end)

    return true
end

function FarmlandProgressGate:installSellingStationHooks()
    if not self:isServer() then
        return
    end

    if g_currentMission == nil or g_currentMission.storageSystem == nil then
        return
    end

    local stations = g_currentMission.storageSystem:getUnloadingStations()
    if stations == nil then
        return
    end

    local installedNow = 0

    for _, station in pairs(stations) do
        if station ~= nil and station.isSellingPoint then
            if self:installStationFillHook(station, "addFillLevelFromTool", "addFillLevelFromTool") then
                installedNow = installedNow + 1
            end

            if self:installStationFillHook(station, "addFillLevel", "addFillLevel") then
                installedNow = installedNow + 1
            end

            if self:installStationFillHook(station, "addFillLevelFromPickup", "addFillLevelFromPickup") then
                installedNow = installedNow + 1
            end

            if self:installStationFillHook(station, "addFillLevelFromObject", "addFillLevelFromObject") then
                installedNow = installedNow + 1
            end
        end
    end

    if installedNow > 0 then
        self.sellHooksInstalledCount = (self.sellHooksInstalledCount or 0) + installedNow
        log(string.format("Hook installed on selling stations: +%d (total %d)", installedNow, self.sellHooksInstalledCount))
    end
end

function FarmlandProgressGate:installHooks()
    self:installFarmlandHooks()
    self:installStatsHooks()
    self:installSellingStationHooks()
    self:installSavegameHooks()
end

-- =====================================================
-- UPDATE
-- =====================================================

function FarmlandProgressGate:update(dt)
    if not self:isServer() then
        return
    end

    self.sellHookRetryTimer = (self.sellHookRetryTimer or 0) + dt
    self.statsHookRetryTimer = (self.statsHookRetryTimer or 0) + dt

    if self.sellHookRetryTimer >= 5000 then
        self.sellHookRetryTimer = 0
        self:installSellingStationHooks()
        self:installSavegameHooks()
    end

    if self.statsHookRetryTimer >= 1000 then
        self.statsHookRetryTimer = 0

        local manager = g_farmManager
        local statsHookMissing = not self.statsHooksInstalled

        if manager ~= nil and self.installedUpdateFarmStatsFunc ~= nil and manager.updateFarmStats ~= self.installedUpdateFarmStatsFunc then
            self.statsHooksInstalled = false
            statsHookMissing = true
        end

        if statsHookMissing then
            self:installStatsHooks()
        end
    end
end

-- =====================================================
-- CONSOLE
-- =====================================================

function FarmlandProgressGate:consoleSetPlowedHa(value)
    local v = tonumber(value)
    local farmId = self:getLocalFarmId()

    if v == nil or farmId == nil then
        print("Usage: saSetPlowedHa 10")
        return
    end

    local state = self:getFarmState(farmId, true)
    state.plowedHa = v
    self:markDirty()

    print(string.format("%s farmId=%d plowedHa set to %.1f", LOG_PREFIX, farmId, v))
end

function FarmlandProgressGate:consoleGetPlowedHa()
    local farmId = self:getLocalFarmId()
    if farmId == nil then
        print(string.format("%s no local farm", LOG_PREFIX))
        return
    end

    local state = self:getFarmState(farmId, false)
    local value = 0
    if state ~= nil then
        value = state.plowedHa or 0
    end

    print(string.format("%s farmId=%d current plowedHa = %.1f", LOG_PREFIX, farmId, value))
end

function FarmlandProgressGate:consoleCheckFarmland(farmlandIdValue)
    local farmlandId = tonumber(farmlandIdValue)
    local farmId = self:getLocalFarmId()

    if farmlandId == nil or farmId == nil then
        print("Usage: saCheckFarmland 119")
        return
    end

    local blocked, reason = self:getBlockReason(farmlandId, farmId)

    print(string.format(
        "%s farmlandId=%d farmId=%d blocked=%s reason=%s",
        LOG_PREFIX,
        farmlandId,
        farmId,
        tostring(blocked),
        tostring(reason)
    ))
end

function FarmlandProgressGate:consoleDumpProgress()
    local farmId = self:getLocalFarmId()
    if farmId == nil then
        print(string.format("%s no local farm", LOG_PREFIX))
        return
    end

    local state = self:getFarmState(farmId, false)
    if state == nil then
        print(string.format("%s no progress for farmId=%d", LOG_PREFIX, farmId))
        return
    end

    print(string.format("%s ===== Progress farmId=%d =====", LOG_PREFIX, farmId))

    for _, def in ipairs(self.requirementDefs) do
        local value = state[def.stateKey]
        if value ~= nil then
            print(string.format("%s %s = %s", LOG_PREFIX, def.stateKey, tostring(roundTo(value, def.decimals or 0))))
        end
    end

    print(string.format("%s ===== Sold FillTypes farmId=%d =====", LOG_PREFIX, farmId))
    for fillTypeName, amount in pairs(state.soldFillTypes) do
        print(string.format(
            "%s soldFillTypes[%s / %s] = %s",
            LOG_PREFIX,
            tostring(fillTypeName),
            tostring(self:getFillTypeDisplayName(fillTypeName)),
            tostring(roundTo(amount, 0))
        ))
    end

    print(string.format("%s ===== Metrics farmId=%d =====", LOG_PREFIX, farmId))
    local snapshots = self:getAllMetricSnapshotsForFarm(farmId)
    for _, metricName in ipairs(self.metricsConfig.metricOrder or {}) do
        local snapshot = snapshots[metricName]
        if snapshot ~= nil then
            print(string.format(
                "%s metric[%s] computed=%s adjustment=%s earned=%s spent=%s available=%s",
                LOG_PREFIX,
                tostring(metricName),
                tostring(snapshot.computed),
                tostring(snapshot.adjustment),
                tostring(snapshot.earned),
                tostring(snapshot.spent),
                tostring(snapshot.available)
            ))
        end
    end
end

function FarmlandProgressGate:consoleResetProgress()
    local farmId = self:getLocalFarmId()
    if farmId == nil then
        print(string.format("%s no local farm", LOG_PREFIX))
        return
    end

    self:resetFarmState(farmId)
    print(string.format("%s progress reset for farmId=%d", LOG_PREFIX, farmId))
end

function FarmlandProgressGate:consoleSetSoldFillType(fillTypeName, amountValue)
    local normalized = normalizeFillTypeName(fillTypeName)
    local amount = tonumber(amountValue)
    local farmId = self:getLocalFarmId()

    if normalized == nil or normalized == "" or amount == nil or farmId == nil then
        print("Usage: saSetSoldFillType FLOUR 100000")
        return
    end

    local state = self:getFarmState(farmId, true)
    state.soldFillTypes[normalized] = amount
    self:markDirty()

    print(string.format("%s farmId=%d soldFillTypes[%s] set to %.0f", LOG_PREFIX, farmId, normalized, amount))
end

function FarmlandProgressGate:consoleGetSoldFillType(fillTypeName)
    local normalized = normalizeFillTypeName(fillTypeName)
    local farmId = self:getLocalFarmId()

    if normalized == nil or normalized == "" or farmId == nil then
        print("Usage: saGetSoldFillType FLOUR")
        return
    end

    print(string.format(
        "%s farmId=%d soldFillTypes[%s / %s] = %.0f",
        LOG_PREFIX,
        farmId,
        normalized,
        self:getFillTypeDisplayName(normalized),
        self:getSoldFillTypeAmountForFarm(farmId, normalized)
    ))
end

function FarmlandProgressGate:consoleListProgressFields()
    print(string.format("%s Available progress fields:", LOG_PREFIX))
    local keys = self:getNumericProgressKeys()
    for _, key in ipairs(keys) do
        print(string.format("%s   %s", LOG_PREFIX, tostring(key)))
    end
    print(string.format("%s soldFillTypes are managed via saGetSoldFillType / saSetSoldFillType / saAddSoldFillType / saResetSoldFillType", LOG_PREFIX))
end

function FarmlandProgressGate:consoleGetProgress(fieldName)
    fieldName = tostring(fieldName or "")
    local farmId = self:getLocalFarmId()

    if fieldName == "" or farmId == nil then
        print("Usage: saGetProgress workedHa")
        return
    end

    local state = self:getFarmState(farmId, false)
    local value = 0
    if state ~= nil then
        value = safeNumber(state[fieldName], 0)
    end

    print(string.format("%s farmId=%d %s = %s", LOG_PREFIX, farmId, fieldName, tostring(value)))
end

function FarmlandProgressGate:consoleSetProgress(fieldName, value)
    fieldName = tostring(fieldName or "")
    local numericValue = tonumber(value)
    local farmId = self:getLocalFarmId()

    if fieldName == "" or numericValue == nil or farmId == nil then
        print("Usage: saSetProgress workedHa 10")
        return
    end

    if self.stateTemplate[fieldName] == nil or type(self.stateTemplate[fieldName]) ~= "number" then
        print(string.format("%s Unknown numeric progress field: %s", LOG_PREFIX, fieldName))
        return
    end

    local state = self:getFarmState(farmId, true)
    state[fieldName] = numericValue
    self:markDirty()

    print(string.format("%s farmId=%d %s set to %s", LOG_PREFIX, farmId, fieldName, tostring(numericValue)))
end

function FarmlandProgressGate:consoleAddProgress(fieldName, value)
    fieldName = tostring(fieldName or "")
    local numericValue = tonumber(value)
    local farmId = self:getLocalFarmId()

    if fieldName == "" or numericValue == nil or farmId == nil then
        print("Usage: saAddProgress workedHa 5")
        return
    end

    if self.stateTemplate[fieldName] == nil or type(self.stateTemplate[fieldName]) ~= "number" then
        print(string.format("%s Unknown numeric progress field: %s", LOG_PREFIX, fieldName))
        return
    end

    local state = self:getFarmState(farmId, true)
    state[fieldName] = safeNumber(state[fieldName], 0) + numericValue
    self:markDirty()

    print(string.format("%s farmId=%d %s increased by %s -> %s", LOG_PREFIX, farmId, fieldName, tostring(numericValue), tostring(state[fieldName])))
end

function FarmlandProgressGate:consoleResetProgressField(fieldName)
    fieldName = tostring(fieldName or "")
    local farmId = self:getLocalFarmId()

    if fieldName == "" or farmId == nil then
        print("Usage: saResetProgressField workedHa")
        return
    end

    if self.stateTemplate[fieldName] == nil or type(self.stateTemplate[fieldName]) ~= "number" then
        print(string.format("%s Unknown numeric progress field: %s", LOG_PREFIX, fieldName))
        return
    end

    local state = self:getFarmState(farmId, true)
    state[fieldName] = 0
    self:markDirty()

    print(string.format("%s farmId=%d %s reset to 0", LOG_PREFIX, farmId, fieldName))
end

function FarmlandProgressGate:consoleAddSoldFillType(fillTypeName, amountValue)
    local normalized = normalizeFillTypeName(fillTypeName)
    local amount = tonumber(amountValue)
    local farmId = self:getLocalFarmId()

    if normalized == nil or normalized == "" or amount == nil or farmId == nil then
        print("Usage: saAddSoldFillType FLOUR 1000")
        return
    end

    self:addSoldFillTypeAmountForFarm(farmId, normalized, amount)
    print(string.format("%s farmId=%d soldFillTypes[%s] increased by %.0f -> %.0f", LOG_PREFIX, farmId, normalized, amount, self:getSoldFillTypeAmountForFarm(farmId, normalized)))
end

function FarmlandProgressGate:consoleResetSoldFillType(fillTypeName)
    local normalized = normalizeFillTypeName(fillTypeName)
    local farmId = self:getLocalFarmId()

    if normalized == nil or normalized == "" or farmId == nil then
        print("Usage: saResetSoldFillType FLOUR")
        return
    end

    local state = self:getFarmState(farmId, true)
    state.soldFillTypes[normalized] = nil
    self:markDirty()
    print(string.format("%s farmId=%d soldFillTypes[%s] reset", LOG_PREFIX, farmId, normalized))
end

function FarmlandProgressGate:consoleListMetrics()
    print(string.format("%s Available metrics:", LOG_PREFIX))
    for _, metricName in ipairs(self.metricsConfig.metricOrder or {}) do
        local metricDef = self:getMetricDef(metricName)
        print(string.format("%s   %s (trackSpent=%s)", LOG_PREFIX, tostring(metricName), tostring(metricDef ~= nil and metricDef.trackSpent or false)))
    end
end

function FarmlandProgressGate:consoleGetMetric(metricName, fieldName)
    metricName = tostring(metricName or "")
    fieldName = tostring(fieldName or "available")
    local farmId = self:getLocalFarmId()

    if metricName == "" or farmId == nil then
        print("Usage: saGetMetric reputation available")
        return
    end

    local snapshot = self:getMetricSnapshotForFarm(farmId, metricName)
    if snapshot == nil then
        print(string.format("%s Unknown metric: %s", LOG_PREFIX, metricName))
        return
    end

    local value = snapshot[fieldName]
    if value == nil then
        print(string.format("%s Unsupported metric field: %s", LOG_PREFIX, fieldName))
        return
    end

    print(string.format("%s farmId=%d metric[%s].%s = %s", LOG_PREFIX, farmId, metricName, fieldName, tostring(value)))
end

function FarmlandProgressGate:consoleSetMetric(metricName, fieldName, value)
    metricName = tostring(metricName or "")
    fieldName = tostring(fieldName or "available")
    local numericValue = tonumber(value)
    local farmId = self:getLocalFarmId()

    if metricName == "" or numericValue == nil or farmId == nil then
        print("Usage: saSetMetric reputation available 100")
        return
    end

    local success, err = self:setMetricFieldValue(farmId, metricName, fieldName, numericValue)
    if not success then
        print(string.format("%s Failed to set metric: %s", LOG_PREFIX, tostring(err)))
        return
    end

    local snapshot = self:getMetricSnapshotForFarm(farmId, metricName)
    print(string.format(
        "%s farmId=%d metric[%s] -> computed=%s adjustment=%s earned=%s spent=%s available=%s",
        LOG_PREFIX,
        farmId,
        metricName,
        tostring(snapshot.computed),
        tostring(snapshot.adjustment),
        tostring(snapshot.earned),
        tostring(snapshot.spent),
        tostring(snapshot.available)
    ))
end

function FarmlandProgressGate:consoleAddMetric(metricName, fieldName, deltaValue)
    metricName = tostring(metricName or "")
    fieldName = tostring(fieldName or "available")
    local delta = tonumber(deltaValue)
    local farmId = self:getLocalFarmId()

    if metricName == "" or delta == nil or farmId == nil then
        print("Usage: saAddMetric reputation available 5")
        return
    end

    local success, err = self:addMetricFieldValue(farmId, metricName, fieldName, delta)
    if not success then
        print(string.format("%s Failed to add metric: %s", LOG_PREFIX, tostring(err)))
        return
    end

    local snapshot = self:getMetricSnapshotForFarm(farmId, metricName)
    print(string.format(
        "%s farmId=%d metric[%s] -> computed=%s adjustment=%s earned=%s spent=%s available=%s",
        LOG_PREFIX,
        farmId,
        metricName,
        tostring(snapshot.computed),
        tostring(snapshot.adjustment),
        tostring(snapshot.earned),
        tostring(snapshot.spent),
        tostring(snapshot.available)
    ))
end

function FarmlandProgressGate:consoleResetMetric(metricName)
    metricName = tostring(metricName or "")
    local farmId = self:getLocalFarmId()

    if metricName == "" or farmId == nil then
        print("Usage: saResetMetric reputation")
        return
    end

    local success = self:resetMetricValue(farmId, metricName)
    if not success then
        print(string.format("%s Unknown metric: %s", LOG_PREFIX, metricName))
        return
    end

    local snapshot = self:getMetricSnapshotForFarm(farmId, metricName)
    print(string.format(
        "%s farmId=%d metric[%s] reset -> earned=%s spent=%s available=%s",
        LOG_PREFIX,
        farmId,
        metricName,
        tostring(snapshot.earned),
        tostring(snapshot.spent),
        tostring(snapshot.available)
    ))
end

-- =====================================================
-- LIFECYCLE
-- =====================================================

function FarmlandProgressGate:loadMap()
    self:loadMetricsConfig()
    self:loadConfig()
    self:loadProgressFromSavegameFile()
    self:applyExternalToggles()
    self:installHooks()
    self:installSavegameHooks()

    addConsoleCommand("saSetPlowedHa", "Set plowed hectares for testing", "consoleSetPlowedHa", self)
    addConsoleCommand("saGetPlowedHa", "Show current plowed hectares", "consoleGetPlowedHa", self)
    addConsoleCommand("saCheckFarmland", "Check if farmland is blocked", "consoleCheckFarmland", self)
    addConsoleCommand("saDumpProgress", "Dump tracked progress counters", "consoleDumpProgress", self)
    addConsoleCommand("saResetProgress", "Reset tracked progress counters", "consoleResetProgress", self)
    addConsoleCommand("saSetSoldFillType", "Set sold fillType amount for testing", "consoleSetSoldFillType", self)
    addConsoleCommand("saGetSoldFillType", "Show sold fillType amount", "consoleGetSoldFillType", self)

    addConsoleCommand("saListProgressFields", "List all numeric progress fields", "consoleListProgressFields", self)
    addConsoleCommand("saGetProgress", "Show progress field value", "consoleGetProgress", self)
    addConsoleCommand("saSetProgress", "Set progress field value", "consoleSetProgress", self)
    addConsoleCommand("saAddProgress", "Add delta to progress field", "consoleAddProgress", self)
    addConsoleCommand("saResetProgressField", "Reset one numeric progress field", "consoleResetProgressField", self)

    addConsoleCommand("saAddSoldFillType", "Add sold fillType amount", "consoleAddSoldFillType", self)
    addConsoleCommand("saResetSoldFillType", "Reset one sold fillType amount", "consoleResetSoldFillType", self)

    addConsoleCommand("saListMetrics", "List configured metrics", "consoleListMetrics", self)
    addConsoleCommand("saGetMetric", "Show metric field value", "consoleGetMetric", self)
    addConsoleCommand("saSetMetric", "Set metric field value", "consoleSetMetric", self)
    addConsoleCommand("saAddMetric", "Add delta to metric field", "consoleAddMetric", self)
    addConsoleCommand("saResetMetric", "Reset metric runtime values", "consoleResetMetric", self)

    log("Loaded")
end

function FarmlandProgressGate:deleteMap()
    if self:isServer() then
        self:saveProgressToSavegameFile()
    end

    removeConsoleCommand("saSetPlowedHa")
    removeConsoleCommand("saGetPlowedHa")
    removeConsoleCommand("saCheckFarmland")
    removeConsoleCommand("saDumpProgress")
    removeConsoleCommand("saResetProgress")
    removeConsoleCommand("saSetSoldFillType")
    removeConsoleCommand("saGetSoldFillType")

    removeConsoleCommand("saListProgressFields")
    removeConsoleCommand("saGetProgress")
    removeConsoleCommand("saSetProgress")
    removeConsoleCommand("saAddProgress")
    removeConsoleCommand("saResetProgressField")

    removeConsoleCommand("saAddSoldFillType")
    removeConsoleCommand("saResetSoldFillType")

    removeConsoleCommand("saListMetrics")
    removeConsoleCommand("saGetMetric")
    removeConsoleCommand("saSetMetric")
    removeConsoleCommand("saAddMetric")
    removeConsoleCommand("saResetMetric")
end

addModEventListener(FarmlandProgressGate)