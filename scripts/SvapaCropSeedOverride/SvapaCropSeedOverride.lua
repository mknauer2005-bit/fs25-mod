-- SvapaCropSeedOverride
-- Custom seed/crop behavior for FS25 sowing machines and planters.
--
-- Main logic:
-- 1) Empty tank => vanilla behavior.
-- 2) Tank has SEEDS => only configured seedMode fruits are selectable.
-- 3) Tank has configured crop fillType => machine is locked to this fruit,
--    tank keeps real fillType (no conversion to SEEDS), unload keeps same fillType.

SvapaCropSeedOverride = {}

SvapaCropSeedOverride.DEBUG_ENABLED = true
SvapaCropSeedOverride.CONFIG_RELATIVE_PATH = "scripts/SvapaCropSeedOverride/ConfigCropSeedOverride.xml"
SvapaCropSeedOverride.savegameSchemaRegistered = false

SvapaCropSeedOverride.DEFAULT_PROFILES = {
    SOWINGMACHINE = {
        seedChoiceFruitNames = {"GRASS", "OILSEEDRADISH", "SPINACH"},
        cropFillFruitNames = {"WHEAT", "BARLEY", "OAT", "CANOLA", "RICELONGGRAIN", "PEA"}
    },
    PLANTER = {
        seedChoiceFruitNames = {"SUGARBEET", "COTTON", "GREENBEAN"},
        cropFillFruitNames = {"MAIZE", "SORGHUM", "SUNFLOWER", "SOYBEAN"}
    }
}

function SvapaCropSeedOverride.debugLog(fmt, ...)
    if not SvapaCropSeedOverride.DEBUG_ENABLED then
        return
    end

    if Logging ~= nil and Logging.info ~= nil then
        local ok, message = pcall(string.format, fmt, ...)
        local finalMessage
        if ok then
            finalMessage = "[SvapaCropSeedOverride] " .. tostring(message)
        else
            finalMessage = "[SvapaCropSeedOverride] LOG_FORMAT_ERROR fmt='" .. tostring(fmt) .. "' err='" .. tostring(message) .. "'"
        end
        Logging.info("%s", finalMessage)
    end
end

function SvapaCropSeedOverride.fillTypeToString(fillTypeIndex)
    if fillTypeIndex == nil then
        return "nil"
    end

    if g_fillTypeManager ~= nil then
        local desc = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if desc ~= nil and desc.name ~= nil then
            return string.format("%s(%d)", tostring(desc.name), fillTypeIndex)
        end
    end

    return tostring(fillTypeIndex)
end

function SvapaCropSeedOverride.debugWarning(fmt, ...)
    if Logging ~= nil and Logging.warning ~= nil then
        local ok, message = pcall(string.format, fmt, ...)
        local finalMessage
        if ok then
            finalMessage = "[SvapaCropSeedOverride] " .. tostring(message)
        else
            finalMessage = "[SvapaCropSeedOverride] LOG_FORMAT_ERROR fmt='" .. tostring(fmt) .. "' err='" .. tostring(message) .. "'"
        end
        Logging.warning("%s", finalMessage)
    end
end

function SvapaCropSeedOverride.cloneArray(array)
    local copy = {}
    if array ~= nil then
        for i, v in ipairs(array) do
            copy[i] = v
        end
    end
    return copy
end

function SvapaCropSeedOverride.getFruitIndexByName(name)
    local desc = g_fruitTypeManager:getFruitTypeByName(name)
    return desc ~= nil and desc.index or nil
end

function SvapaCropSeedOverride.getConfigPath()
    local baseDir = g_currentModDirectory or ""
    return baseDir .. SvapaCropSeedOverride.CONFIG_RELATIVE_PATH
end

function SvapaCropSeedOverride.loadConfigProfiles()
    local configPath = SvapaCropSeedOverride.getConfigPath()
    local xmlFile = loadXMLFile("SvapaCropSeedOverrideConfig", configPath)

    if xmlFile == nil or xmlFile == 0 then
        SvapaCropSeedOverride.debugWarning("Config not found: %s. Using defaults.", configPath)
        return SvapaCropSeedOverride.DEFAULT_PROFILES
    end

    local profiles = {}
    local i = 0
    while true do
        local profileKey = string.format("cropSeedOverride.profiles.profile(%d)", i)
        if not hasXMLProperty(xmlFile, profileKey) then
            break
        end

        local profileName = getXMLString(xmlFile, profileKey .. "#name")
        if profileName ~= nil and profileName ~= "" then
            local seedModeFruits = {}
            local seedNames = getXMLString(xmlFile, profileKey .. ".seedMode#fruits")
            if seedNames ~= nil then
                for token in string.gmatch(seedNames, "%S+") do
                    table.insert(seedModeFruits, token)
                end
            end

            local cropFillFruits = {}
            local rates = {}
            local j = 0
            while true do
                local fruitKey = string.format("%s.cropMode.fruit(%d)", profileKey, j)
                if not hasXMLProperty(xmlFile, fruitKey) then
                    break
                end

                local fruitName = getXMLString(xmlFile, fruitKey .. "#name")
                local rate = getXMLFloat(xmlFile, fruitKey .. "#rate")
                if fruitName ~= nil and fruitName ~= "" then
                    table.insert(cropFillFruits, fruitName)
                    if rate ~= nil then
                        rates[fruitName] = rate
                    end
                end

                j = j + 1
            end

            profiles[profileName] = {
                seedChoiceFruitNames = seedModeFruits,
                cropFillFruitNames = cropFillFruits,
                realRatesLitersPerSqm = rates
            }
        end

        i = i + 1
    end

    delete(xmlFile)

    if next(profiles) == nil then
        SvapaCropSeedOverride.debugWarning("Config parsed but no valid profiles found. Using defaults.")
        return SvapaCropSeedOverride.DEFAULT_PROFILES
    end

    return profiles
end

function SvapaCropSeedOverride.resolveProfileData(profileName)
    local definition = SvapaCropSeedOverride.PROFILES[profileName]
    if definition == nil then
        return nil
    end

    local data = {
        name = profileName,
        seedChoiceFruits = {},
        seedChoiceSet = {},
        cropFillToFruit = {},
        allowedFillTypes = {FillType.SEEDS},
        allowedFillTypeSet = {[FillType.SEEDS] = true},
        rateByFruitIndex = {}
    }

    for _, fruitName in ipairs(definition.seedChoiceFruitNames or {}) do
        local fruitIndex = SvapaCropSeedOverride.getFruitIndexByName(fruitName)
        if fruitIndex ~= nil then
            table.insert(data.seedChoiceFruits, fruitIndex)
            data.seedChoiceSet[fruitIndex] = true
        else
            SvapaCropSeedOverride.debugWarning("Unknown seedMode fruit '%s' in profile '%s'", tostring(fruitName), profileName)
        end
    end

    for _, fruitName in ipairs(definition.cropFillFruitNames or {}) do
        local fruitIndex = SvapaCropSeedOverride.getFruitIndexByName(fruitName)
        local fillTypeIndex = fruitIndex ~= nil and g_fruitTypeManager:getFillTypeIndexByFruitTypeIndex(fruitIndex) or nil

        if fruitIndex ~= nil and fillTypeIndex ~= nil then
            data.cropFillToFruit[fillTypeIndex] = fruitIndex
            table.insert(data.allowedFillTypes, fillTypeIndex)
            data.allowedFillTypeSet[fillTypeIndex] = true

            local rate = definition.realRatesLitersPerSqm ~= nil and definition.realRatesLitersPerSqm[fruitName] or nil
            if rate ~= nil then
                data.rateByFruitIndex[fruitIndex] = rate
            end
        else
            SvapaCropSeedOverride.debugWarning("Unknown cropMode fruit '%s' in profile '%s'", tostring(fruitName), profileName)
        end
    end

    return data
end

function SvapaCropSeedOverride.detectProfileName(self)
    local spec = self.spec_sowingMachine
    if spec == nil or spec.saOriginalSeeds == nil then
        return "SOWINGMACHINE"
    end

    for _, fruitIndex in ipairs(spec.saOriginalSeeds) do
        local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitIndex)
        if fruitDesc ~= nil then
            local name = fruitDesc.name
            if name == "MAIZE" or name == "SORGHUM" or name == "SUNFLOWER" or name == "SOYBEAN" or name == "SUGARBEET" or name == "COTTON" or name == "GREENBEAN" then
                return "PLANTER"
            end
        end
    end

    return "SOWINGMACHINE"
end

function SvapaCropSeedOverride.getOrCreateProfile(self)
    local spec = self.spec_sowingMachine
    if spec == nil then
        return nil
    end

    if spec.saCropSeedProfile ~= nil then
        return spec.saCropSeedProfile
    end

    spec.saOriginalSeeds = spec.saOriginalSeeds or SvapaCropSeedOverride.cloneArray(spec.seeds)
    local profileName = SvapaCropSeedOverride.detectProfileName(self)
    spec.saCropSeedProfile = SvapaCropSeedOverride.resolveProfileData(profileName)
    SvapaCropSeedOverride.debugLog("profile resolved: vehicle='%s' profile='%s'", tostring(self.configFileName), tostring(profileName))

    return spec.saCropSeedProfile
end

function SvapaCropSeedOverride.getSeedTankFillLevel(self)
    local spec = self.spec_sowingMachine
    if spec == nil then
        return 0
    end

    return self:getFillUnitFillLevel(spec.fillUnitIndex)
end

function SvapaCropSeedOverride.isSeedTankEmpty(self)
    local spec = self.spec_sowingMachine
    if spec == nil then
        return true
    end

    return self:getFillUnitFillLevel(spec.fillUnitIndex) <= self:getFillTypeChangeThreshold(spec.fillUnitIndex)
end

function SvapaCropSeedOverride.getCurrentFillTypeForSeedTank(self)
    local spec = self.spec_sowingMachine
    if spec == nil then
        return FillType.UNKNOWN
    end

    local fillType = self:getFillUnitFillType(spec.fillUnitIndex)
    return fillType ~= nil and fillType or FillType.UNKNOWN
end

function SvapaCropSeedOverride.restoreVanillaMode(self)
    local spec = self.spec_sowingMachine
    if spec == nil then
        return
    end

    local originalSeeds = spec.saOriginalSeeds or spec.seeds
    if originalSeeds == nil or #originalSeeds == 0 then
        return
    end

    local currentFruit = spec.seeds ~= nil and spec.seeds[spec.currentSeed] or nil

    spec.seeds = SvapaCropSeedOverride.cloneArray(originalSeeds)
    spec.allowsSeedChanging = true
    spec.seedFillType = FillType.SEEDS

    local targetIndex = 1
    if currentFruit ~= nil then
        for i, fruitIndex in ipairs(spec.seeds) do
            if fruitIndex == currentFruit then
                targetIndex = i
                break
            end
        end
    end

    spec.currentSeed = targetIndex
    self:setSeedIndex(targetIndex, true)
    self:setFillUnitForcedMaterialFillType(spec.fillUnitIndex, nil)
end

function SvapaCropSeedOverride.setSeedsList(self, seeds, preferredFruit, allowChange)
    local spec = self.spec_sowingMachine
    if spec == nil or seeds == nil or #seeds == 0 then
        return
    end

    spec.seeds = SvapaCropSeedOverride.cloneArray(seeds)
    spec.allowsSeedChanging = allowChange

    local targetIndex = 1
    if preferredFruit ~= nil then
        for i, fruitIndex in ipairs(spec.seeds) do
            if fruitIndex == preferredFruit then
                targetIndex = i
                break
            end
        end
    end

    spec.currentSeed = targetIndex
    self:setSeedIndex(targetIndex, true)
end

function SvapaCropSeedOverride.applyModeFromFillType(self, fillType)
    local spec = self.spec_sowingMachine
    local profile = SvapaCropSeedOverride.getOrCreateProfile(self)
    if spec == nil or profile == nil then
        return
    end

    if SvapaCropSeedOverride.isSeedTankEmpty(self) then
        SvapaCropSeedOverride.restoreVanillaMode(self)
        return
    end

    if fillType == nil or fillType == FillType.UNKNOWN then
        fillType = SvapaCropSeedOverride.getCurrentFillTypeForSeedTank(self)
    end

    if fillType == FillType.SEEDS then
        local preferredFruit = profile.seedChoiceFruits[1]
        local currentFruit = spec.seeds ~= nil and spec.seeds[spec.currentSeed] or nil
        if currentFruit ~= nil and profile.seedChoiceSet[currentFruit] then
            preferredFruit = currentFruit
        end

        spec.seedFillType = FillType.SEEDS
        SvapaCropSeedOverride.setSeedsList(self, profile.seedChoiceFruits, preferredFruit, true)
        self:setFillUnitForcedMaterialFillType(spec.fillUnitIndex, FillType.SEEDS)
        SvapaCropSeedOverride.debugLog("apply mode: SEEDS vehicle='%s' fillUnit=%d", tostring(self.configFileName), spec.fillUnitIndex)
        return
    end

    local forcedFruit = profile.cropFillToFruit[fillType]
    if forcedFruit ~= nil then
        spec.seedFillType = fillType
        SvapaCropSeedOverride.setSeedsList(self, {forcedFruit}, forcedFruit, false)
        self:setFillUnitForcedMaterialFillType(spec.fillUnitIndex, fillType)
        SvapaCropSeedOverride.debugLog("apply mode: CROP vehicle='%s' fillType='%s' fruitIndex=%s", tostring(self.configFileName), SvapaCropSeedOverride.fillTypeToString(fillType), tostring(forcedFruit))
    else
        SvapaCropSeedOverride.debugLog("apply mode: ignored unknown fillType='%s' vehicle='%s'", SvapaCropSeedOverride.fillTypeToString(fillType), tostring(self.configFileName))
    end
end

function SvapaCropSeedOverride.getModeConsumptionFillType(self)
    local profile = SvapaCropSeedOverride.getOrCreateProfile(self)
    if profile == nil then
        return FillType.SEEDS
    end

    local fillType = SvapaCropSeedOverride.getCurrentFillTypeForSeedTank(self)
    if profile.cropFillToFruit[fillType] ~= nil then
        return fillType
    end

    return FillType.SEEDS
end

function SvapaCropSeedOverride.registerSavegameXMLPaths(schema, basePath)
    local key = basePath .. ".svapaCropSeedOverride"
    schema:register(XMLValueType.STRING, key .. "#fillType", "Saved fill type for SvapaCropSeedOverride tank restore")
    schema:register(XMLValueType.FLOAT, key .. "#fillLevel", "Saved fill level for SvapaCropSeedOverride tank restore")
end

function SvapaCropSeedOverride.registerGlobalSavegameSchemaPaths()
    if SvapaCropSeedOverride.savegameSchemaRegistered then
        return
    end

    local schema = Vehicle ~= nil and Vehicle.xmlSchemaSavegame or nil
    if schema == nil then
        return
    end

    schema:register(XMLValueType.STRING, "vehicles.vehicle(?).sowingMachine.svapaCropSeedOverride#fillType", "Saved fill type for SvapaCropSeedOverride tank restore")
    schema:register(XMLValueType.FLOAT, "vehicles.vehicle(?).sowingMachine.svapaCropSeedOverride#fillLevel", "Saved fill level for SvapaCropSeedOverride tank restore")

    SvapaCropSeedOverride.savegameSchemaRegistered = true
    SvapaCropSeedOverride.debugLog("registered global savegame schema paths for svapaCropSeedOverride")
end

function SvapaCropSeedOverride.onPostLoad(self, superFunc, savegame)
    superFunc(self, savegame)

    local spec = self.spec_sowingMachine
    local profile = SvapaCropSeedOverride.getOrCreateProfile(self)
    if spec == nil or profile == nil then
        return
    end

    SvapaCropSeedOverride.extendSeedTankSupportedFillTypes(self)
    SvapaCropSeedOverride.rebuildFillTypeSources(self)

    if self.isServer and spec.saSavedFillTypeIndex ~= nil and (spec.saSavedFillLevel or 0) > 0 then
        local currentLevel = self:getFillUnitFillLevel(spec.fillUnitIndex)
        local threshold = self:getFillTypeChangeThreshold(spec.fillUnitIndex)
        if currentLevel <= threshold then
            local restored = self:addFillUnitFillLevel(self:getOwnerFarmId(), spec.fillUnitIndex, spec.saSavedFillLevel, spec.saSavedFillTypeIndex, ToolType.UNDEFINED, nil)
            SvapaCropSeedOverride.debugLog(
                "restore saved tank: vehicle='%s' fillType=%s level=%s result=%s",
                tostring(self.configFileName),
                SvapaCropSeedOverride.fillTypeToString(spec.saSavedFillTypeIndex),
                tostring(spec.saSavedFillLevel),
                tostring(restored)
            )
        end
        spec.saSavedFillTypeIndex = nil
        spec.saSavedFillLevel = nil
    end

    if SvapaCropSeedOverride.isSeedTankEmpty(self) then
        SvapaCropSeedOverride.restoreVanillaMode(self)
    else
        SvapaCropSeedOverride.applyModeFromFillType(self, SvapaCropSeedOverride.getCurrentFillTypeForSeedTank(self))
    end
end

function SvapaCropSeedOverride.onLoad(self, superFunc, savegame)
    superFunc(self, savegame)
    SvapaCropSeedOverride.registerGlobalSavegameSchemaPaths()

    local spec = self.spec_sowingMachine
    if spec == nil then
        return
    end

    SvapaCropSeedOverride.getOrCreateProfile(self)
    SvapaCropSeedOverride.extendSeedTankSupportedFillTypes(self)

    if savegame ~= nil and savegame.xmlFile ~= nil and savegame.key ~= nil then
        local key = savegame.key .. ".sowingMachine.svapaCropSeedOverride"
        local savedFillTypeName = savegame.xmlFile:getValue(key .. "#fillType")
        local savedFillLevel = savegame.xmlFile:getValue(key .. "#fillLevel", 0)

        if savedFillTypeName ~= nil and savedFillTypeName ~= "" and savedFillLevel > 0 then
            local savedFillTypeIndex = FillType[savedFillTypeName]
            if savedFillTypeIndex ~= nil then
                spec.saSavedFillTypeIndex = savedFillTypeIndex
                spec.saSavedFillLevel = savedFillLevel
                SvapaCropSeedOverride.debugLog(
                    "load saved tank marker: vehicle='%s' fillType=%s level=%s",
                    tostring(self.configFileName),
                    SvapaCropSeedOverride.fillTypeToString(savedFillTypeIndex),
                    tostring(savedFillLevel)
                )
            end
        end
    end
end

function SvapaCropSeedOverride.saveToXMLFile(self, superFunc, xmlFile, key, usedModNames)
    superFunc(self, xmlFile, key, usedModNames)

    local spec = self.spec_sowingMachine
    if spec == nil then
        return
    end

    SvapaCropSeedOverride.debugLog("save hook entered: vehicle='%s' key='%s'", tostring(self.configFileName), tostring(key))

    local fillUnitIndex = spec.fillUnitIndex
    local fillLevel = self:getFillUnitFillLevel(fillUnitIndex)
    local threshold = self:getFillTypeChangeThreshold(fillUnitIndex)
    local fillType = self:getFillUnitFillType(fillUnitIndex)
    local fillTypeDesc = fillType ~= nil and g_fillTypeManager:getFillTypeByIndex(fillType) or nil

    local saveKey = key .. ".svapaCropSeedOverride"
    if fillLevel > threshold and fillType ~= nil and fillType ~= FillType.UNKNOWN and fillTypeDesc ~= nil and fillTypeDesc.name ~= nil then
        xmlFile:setValue(saveKey .. "#fillType", fillTypeDesc.name)
        xmlFile:setValue(saveKey .. "#fillLevel", fillLevel)
        SvapaCropSeedOverride.debugLog("save tank marker: vehicle='%s' fillType=%s level=%s", tostring(self.configFileName), SvapaCropSeedOverride.fillTypeToString(fillType), tostring(fillLevel))
    else
        xmlFile:setValue(saveKey .. "#fillType", "")
        xmlFile:setValue(saveKey .. "#fillLevel", 0)
    end
end

function SvapaCropSeedOverride.extendSeedTankSupportedFillTypes(self)
    local spec = self.spec_sowingMachine
    local profile = SvapaCropSeedOverride.getOrCreateProfile(self)
    local specFillUnit = self.spec_fillUnit
    if spec == nil or profile == nil or specFillUnit == nil then
        return
    end

    local fillUnit = specFillUnit.fillUnits[spec.fillUnitIndex]
    if fillUnit == nil or fillUnit.supportedFillTypes == nil then
        return
    end

    for fillTypeIndex, _ in pairs(profile.allowedFillTypeSet) do
        fillUnit.supportedFillTypes[fillTypeIndex] = true
    end

    SvapaCropSeedOverride.debugLog("extended supportedFillTypes: vehicle='%s' fillUnit=%s count=%s", tostring(self.configFileName), tostring(spec.fillUnitIndex), tostring(table.size(fillUnit.supportedFillTypes)))
end

function SvapaCropSeedOverride.rebuildFillTypeSources(self)
    local spec = self.spec_sowingMachine
    local profile = SvapaCropSeedOverride.getOrCreateProfile(self)
    if spec == nil or profile == nil then
        return
    end

    spec.fillTypeSources = {}
    for _, fillTypeIndex in ipairs(profile.allowedFillTypes) do
        spec.fillTypeSources[fillTypeIndex] = {}
    end

    FillUnit.addFillTypeSources(spec.fillTypeSources, self.rootVehicle, self, profile.allowedFillTypes)
    SvapaCropSeedOverride.debugLog("rebuild sources: vehicle='%s' built sources for %d fillTypes", tostring(self.configFileName), #profile.allowedFillTypes)
end

function SvapaCropSeedOverride.getFillUnitSupportsFillType(self, superFunc, fillUnitIndex, fillType)
    local vanilla = superFunc(self, fillUnitIndex, fillType)
    if vanilla then
        SvapaCropSeedOverride.debugLog("supports: VANILLA true vehicle='%s' unit=%s fillType=%s", tostring(self.configFileName), tostring(fillUnitIndex), SvapaCropSeedOverride.fillTypeToString(fillType))
        return true
    end

    local spec = self.spec_sowingMachine
    local profile = SvapaCropSeedOverride.getOrCreateProfile(self)
    if spec == nil or profile == nil or fillUnitIndex ~= spec.fillUnitIndex then
        SvapaCropSeedOverride.debugLog("supports: false (not sowing unit/profile) vehicle='%s' unit=%s fillType=%s", tostring(self.configFileName), tostring(fillUnitIndex), SvapaCropSeedOverride.fillTypeToString(fillType))
        return false
    end

    if fillType == FillType.SEEDS then
        SvapaCropSeedOverride.debugLog("supports: forced true for SEEDS vehicle='%s' unit=%s", tostring(self.configFileName), tostring(fillUnitIndex))
        return true
    end

    local allow = profile.allowedFillTypeSet[fillType] == true
    SvapaCropSeedOverride.debugLog("supports: CUSTOM %s vehicle='%s' unit=%s fillType=%s", tostring(allow), tostring(self.configFileName), tostring(fillUnitIndex), SvapaCropSeedOverride.fillTypeToString(fillType))
    return allow
end

function SvapaCropSeedOverride.getFillUnitAllowsFillType(self, superFunc, fillUnitIndex, fillType)
    local vanilla = superFunc(self, fillUnitIndex, fillType)
    if vanilla then
        SvapaCropSeedOverride.debugLog("allows: VANILLA true vehicle='%s' unit=%s fillType=%s", tostring(self.configFileName), tostring(fillUnitIndex), SvapaCropSeedOverride.fillTypeToString(fillType))
        return true
    end

    if fillType == nil then
        SvapaCropSeedOverride.debugLog("allows: false (nil fillType) vehicle='%s' unit=%s", tostring(self.configFileName), tostring(fillUnitIndex))
        return false
    end

    local spec = self.spec_sowingMachine
    local profile = SvapaCropSeedOverride.getOrCreateProfile(self)
    if spec == nil or profile == nil or fillUnitIndex ~= spec.fillUnitIndex then
        SvapaCropSeedOverride.debugLog("allows: false (not sowing unit/profile) vehicle='%s' unit=%s fillType=%s", tostring(self.configFileName), tostring(fillUnitIndex), SvapaCropSeedOverride.fillTypeToString(fillType))
        return false
    end

    if profile.allowedFillTypeSet[fillType] ~= true then
        if fillType == FillType.SEEDS then
            SvapaCropSeedOverride.debugLog("allows: forced true for SEEDS vehicle='%s' unit=%s", tostring(self.configFileName), tostring(fillUnitIndex))
            return true
        end
        SvapaCropSeedOverride.debugLog("allows: false (fillType not in profile) vehicle='%s' unit=%s fillType=%s", tostring(self.configFileName), tostring(fillUnitIndex), SvapaCropSeedOverride.fillTypeToString(fillType))
        return false
    end

    local currentFillType = self:getFillUnitFillType(fillUnitIndex)
    local currentFillLevel = self:getFillUnitFillLevel(fillUnitIndex)
    local threshold = self:getFillTypeChangeThreshold(fillUnitIndex)

    local allow = currentFillLevel <= threshold or currentFillType == FillType.UNKNOWN or currentFillType == nil or currentFillType == fillType
    SvapaCropSeedOverride.debugLog(
        "allows: CUSTOM %s vehicle='%s' unit=%s incoming=%s current=%s level=%s threshold=%s",
        tostring(allow),
        tostring(self.configFileName),
        tostring(fillUnitIndex),
        SvapaCropSeedOverride.fillTypeToString(fillType),
        SvapaCropSeedOverride.fillTypeToString(currentFillType),
        tostring(currentFillLevel),
        tostring(threshold)
    )
    return allow
end

function SvapaCropSeedOverride.onStateChange(self, superFunc, state, data)
    superFunc(self, state, data)

    local spec = self.spec_sowingMachine
    if spec == nil then
        return
    end

    if state == VehicleStateChange.ATTACH or state == VehicleStateChange.DETACH or state == VehicleStateChange.FILLTYPE_CHANGE then
        SvapaCropSeedOverride.debugLog("state change: vehicle='%s' state=%s -> rebuild sources", tostring(self.configFileName), tostring(state))
        SvapaCropSeedOverride.extendSeedTankSupportedFillTypes(self)
        SvapaCropSeedOverride.rebuildFillTypeSources(self)
    end
end

function SvapaCropSeedOverride.addFillUnitFillLevel(self, superFunc, farmId, fillUnitIndex, fillLevelDelta, fillType, toolType, fillInfo)
    local spec = self.spec_sowingMachine
    local profile = SvapaCropSeedOverride.getOrCreateProfile(self)

    if spec == nil or profile == nil or fillUnitIndex ~= spec.fillUnitIndex then
        return superFunc(self, farmId, fillUnitIndex, fillLevelDelta, fillType, toolType, fillInfo)
    end

    -- In MP, server is authoritative for fill mutations. Clients follow via synced fill/type events.
    if not self.isServer then
        return superFunc(self, farmId, fillUnitIndex, fillLevelDelta, fillType, toolType, fillInfo)
    end

    SvapaCropSeedOverride.debugLog(
        "addFill start: vehicle='%s' unit=%s delta=%s fillType=%s currentType=%s currentLevel=%s",
        tostring(self.configFileName),
        tostring(fillUnitIndex),
        tostring(fillLevelDelta),
        SvapaCropSeedOverride.fillTypeToString(fillType),
        SvapaCropSeedOverride.fillTypeToString(self:getFillUnitFillType(fillUnitIndex)),
        tostring(self:getFillUnitFillLevel(fillUnitIndex))
    )

    -- Defensive detection of incoming fillType: some call paths may provide shifted arg positions.
    local incomingFillType = fillType
    if profile.allowedFillTypeSet[incomingFillType] ~= true and profile.allowedFillTypeSet[toolType] == true then
        incomingFillType = toolType
    end
    if profile.allowedFillTypeSet[incomingFillType] ~= true and type(fillLevelDelta) == "number" and profile.allowedFillTypeSet[fillLevelDelta] == true then
        incomingFillType = fillLevelDelta
    end

    -- Important: set seedFillType BEFORE vanilla logic to prevent conversion to SEEDS.
    if fillLevelDelta > 0 and incomingFillType ~= nil and profile.allowedFillTypeSet[incomingFillType] == true then
        local currentFillType = self:getFillUnitFillType(fillUnitIndex)
        local currentFillLevel = self:getFillUnitFillLevel(fillUnitIndex)
        local threshold = self:getFillTypeChangeThreshold(fillUnitIndex)

        -- If different material is already inside, cleanly empty first to avoid invalid mixed/infinite transitions.
        if currentFillLevel > threshold and currentFillType ~= nil and currentFillType ~= FillType.UNKNOWN and currentFillType ~= incomingFillType then
            local removed = superFunc(self, farmId, fillUnitIndex, -currentFillLevel, currentFillType, toolType, fillInfo)
            SvapaCropSeedOverride.debugLog(
                "addFill replace: emptied old fillType=%s removed=%s before incoming=%s",
                SvapaCropSeedOverride.fillTypeToString(currentFillType),
                tostring(removed),
                SvapaCropSeedOverride.fillTypeToString(incomingFillType)
            )
        end

        spec.seedFillType = incomingFillType
        local cropFruit = profile.cropFillToFruit[incomingFillType]
        if cropFruit ~= nil then
            self:setSeedFruitType(cropFruit, true)
        end
        self:setFillUnitForcedMaterialFillType(fillUnitIndex, incomingFillType)
        SvapaCropSeedOverride.debugLog("addFill detected incoming fillType=%s (raw fillType=%s toolType=%s)", SvapaCropSeedOverride.fillTypeToString(incomingFillType), SvapaCropSeedOverride.fillTypeToString(fillType), tostring(toolType))
    end

    local result = superFunc(self, farmId, fillUnitIndex, fillLevelDelta, fillType, toolType, fillInfo)
    SvapaCropSeedOverride.debugLog(
        "addFill done: vehicle='%s' unit=%s result=%s newType=%s newLevel=%s",
        tostring(self.configFileName),
        tostring(fillUnitIndex),
        tostring(result),
        SvapaCropSeedOverride.fillTypeToString(self:getFillUnitFillType(fillUnitIndex)),
        tostring(self:getFillUnitFillLevel(fillUnitIndex))
    )

    if result ~= 0 then
        if self:getFillUnitFillLevel(fillUnitIndex) <= self:getFillTypeChangeThreshold(fillUnitIndex) then
            self:setFillUnitForcedMaterialFillType(fillUnitIndex, nil)
            SvapaCropSeedOverride.restoreVanillaMode(self)
        else
            local currentFillType = self:getFillUnitFillType(fillUnitIndex)
            self:setFillUnitForcedMaterialFillType(fillUnitIndex, currentFillType)
            SvapaCropSeedOverride.applyModeFromFillType(self, currentFillType)
        end
    end

    return result
end

function SvapaCropSeedOverride.getIsSeedChangeAllowed(self, superFunc)
    local spec = self.spec_sowingMachine
    local profile = SvapaCropSeedOverride.getOrCreateProfile(self)
    if spec == nil or profile == nil then
        return superFunc(self)
    end

    if SvapaCropSeedOverride.isSeedTankEmpty(self) then
        return superFunc(self)
    end

    local fillType = SvapaCropSeedOverride.getCurrentFillTypeForSeedTank(self)
    if profile.cropFillToFruit[fillType] ~= nil then
        return false
    end

    return true
end

function SvapaCropSeedOverride.onChangedFillType(self, superFunc, fillUnitIndex, fillTypeIndex, oldFillTypeIndex)
    superFunc(self, fillUnitIndex, fillTypeIndex, oldFillTypeIndex)

    local spec = self.spec_sowingMachine
    if spec ~= nil and fillUnitIndex == spec.fillUnitIndex then
        if SvapaCropSeedOverride.isSeedTankEmpty(self) then
            SvapaCropSeedOverride.restoreVanillaMode(self)
        else
            SvapaCropSeedOverride.applyModeFromFillType(self, fillTypeIndex)
        end
    end
end

function SvapaCropSeedOverride.onUpdateTick(self, superFunc, dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    superFunc(self, dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)

    local spec = self.spec_sowingMachine
    local profile = SvapaCropSeedOverride.getOrCreateProfile(self)
    if spec == nil or profile == nil then
        return
    end

    if SvapaCropSeedOverride.isSeedTankEmpty(self) then
        if spec.seeds ~= nil and spec.saOriginalSeeds ~= nil and #spec.seeds ~= #spec.saOriginalSeeds then
            SvapaCropSeedOverride.restoreVanillaMode(self)
        end
        return
    end

    local currentFillType = SvapaCropSeedOverride.getCurrentFillTypeForSeedTank(self)
    local forcedFruit = profile.cropFillToFruit[currentFillType]

    if forcedFruit ~= nil then
        local currentFruit = spec.seeds ~= nil and spec.seeds[spec.currentSeed] or nil
        if currentFruit ~= forcedFruit or #spec.seeds ~= 1 or spec.allowsSeedChanging ~= false then
            SvapaCropSeedOverride.applyModeFromFillType(self, currentFillType)
        end
    elseif currentFillType == FillType.SEEDS then
        local currentFruit = spec.seeds ~= nil and spec.seeds[spec.currentSeed] or nil
        if currentFruit == nil or profile.seedChoiceSet[currentFruit] ~= true or spec.allowsSeedChanging ~= true then
            SvapaCropSeedOverride.applyModeFromFillType(self, FillType.SEEDS)
        end
    end
end

function SvapaCropSeedOverride.onEndWorkAreaProcessing(self, superFunc, dt, hasProcessed)
    local spec = self.spec_sowingMachine
    local profile = SvapaCropSeedOverride.getOrCreateProfile(self)
    if spec == nil or profile == nil or not self.isServer then
        return superFunc(self, dt, hasProcessed)
    end

    local oldSeedFillType = spec.seedFillType
    spec.seedFillType = SvapaCropSeedOverride.getModeConsumptionFillType(self)

    local currentFruit = spec.workAreaParameters ~= nil and spec.workAreaParameters.seedsFruitType or nil
    local realRateLitersPerSqm = currentFruit ~= nil and profile.rateByFruitIndex[currentFruit] or nil

    if realRateLitersPerSqm ~= nil and spec.workAreaParameters.lastChangedArea > 0 then
        local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(currentFruit)
        if fruitDesc ~= nil then
            spec.saOriginalSeedUsagePerSqm = spec.saOriginalSeedUsagePerSqm or {}
            if spec.saOriginalSeedUsagePerSqm[currentFruit] == nil then
                spec.saOriginalSeedUsagePerSqm[currentFruit] = fruitDesc.seedUsagePerSqm
            end
            fruitDesc.seedUsagePerSqm = realRateLitersPerSqm
        end
    end

    superFunc(self, dt, hasProcessed)

    if realRateLitersPerSqm ~= nil and currentFruit ~= nil then
        local fruitDesc = g_fruitTypeManager:getFruitTypeByIndex(currentFruit)
        if fruitDesc ~= nil and spec.saOriginalSeedUsagePerSqm ~= nil and spec.saOriginalSeedUsagePerSqm[currentFruit] ~= nil then
            fruitDesc.seedUsagePerSqm = spec.saOriginalSeedUsagePerSqm[currentFruit]
        end
    end

    spec.seedFillType = oldSeedFillType
end

function SvapaCropSeedOverride.install()
    if SvapaCropSeedOverride.isInstalled then
        return
    end

    SvapaCropSeedOverride.PROFILES = SvapaCropSeedOverride.loadConfigProfiles()
    SvapaCropSeedOverride.registerGlobalSavegameSchemaPaths()

    SowingMachine.onLoad = Utils.overwrittenFunction(SowingMachine.onLoad, SvapaCropSeedOverride.onLoad)
    SowingMachine.onPostLoad = Utils.overwrittenFunction(SowingMachine.onPostLoad, SvapaCropSeedOverride.onPostLoad)
    SowingMachine.saveToXMLFile = Utils.overwrittenFunction(SowingMachine.saveToXMLFile, SvapaCropSeedOverride.saveToXMLFile)
    if SowingMachine.registerSavegameXMLPaths ~= nil then
        SowingMachine.registerSavegameXMLPaths = Utils.appendedFunction(SowingMachine.registerSavegameXMLPaths, SvapaCropSeedOverride.registerSavegameXMLPaths)
    else
        SowingMachine.registerSavegameXMLPaths = SvapaCropSeedOverride.registerSavegameXMLPaths
    end
    SowingMachine.addFillUnitFillLevel = Utils.overwrittenFunction(SowingMachine.addFillUnitFillLevel, SvapaCropSeedOverride.addFillUnitFillLevel)
    SowingMachine.getIsSeedChangeAllowed = Utils.overwrittenFunction(SowingMachine.getIsSeedChangeAllowed, SvapaCropSeedOverride.getIsSeedChangeAllowed)
    SowingMachine.onChangedFillType = Utils.overwrittenFunction(SowingMachine.onChangedFillType, SvapaCropSeedOverride.onChangedFillType)
    SowingMachine.onStateChange = Utils.overwrittenFunction(SowingMachine.onStateChange, SvapaCropSeedOverride.onStateChange)
    SowingMachine.onUpdateTick = Utils.overwrittenFunction(SowingMachine.onUpdateTick, SvapaCropSeedOverride.onUpdateTick)
    SowingMachine.onEndWorkAreaProcessing = Utils.overwrittenFunction(SowingMachine.onEndWorkAreaProcessing, SvapaCropSeedOverride.onEndWorkAreaProcessing)

    SvapaCropSeedOverride.isInstalled = true
    SvapaCropSeedOverride.debugLog("installed")
end

SvapaCropSeedOverride.install()
