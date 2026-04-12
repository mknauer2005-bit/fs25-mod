PlaceableDynamicFuelPrice = {}

local PlaceableDynamicFuelPrice_mt = Class(PlaceableDynamicFuelPrice)
PlaceableDynamicFuelPrice.DEBUG = false

local function dfpClamp(value, minValue, maxValue)
    if value == nil then
        return minValue
    end

    if minValue ~= nil and value < minValue then
        return minValue
    end

    if maxValue ~= nil and value > maxValue then
        return maxValue
    end

    return value
end

local function dfpGetName(self)
    if self == nil then
        return "unknown"
    end

    return tostring(self.configFileName or self.xmlFilename or self.customEnvironment or "unknown")
end

local function dfpDbg(self, fmt, ...)
    if not PlaceableDynamicFuelPrice.DEBUG then
        return
    end

    local prefix = string.format("[DynamicFuelPrice][DEBUG][%s] ", dfpGetName(self))
    if select("#", ...) > 0 then
        print(prefix .. string.format(tostring(fmt), ...))
    else
        print(prefix .. tostring(fmt))
    end
end

local function dfpWarn(self, fmt, ...)
    local prefix = string.format("[DynamicFuelPrice][%s] ", dfpGetName(self))
    if select("#", ...) > 0 then
        Logging.warning(prefix .. tostring(fmt), ...)
    else
        Logging.warning(prefix .. tostring(fmt))
    end
end

local function getSpec(self)
    self.spec_dynamicFuelPrice = self.spec_dynamicFuelPrice or {}
    return self.spec_dynamicFuelPrice
end


local function dfpSafeGetFillTypeName(fillTypeIndex)
    if fillTypeIndex == nil then
        return "nil"
    end

    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeNameByIndex ~= nil then
        local ok, name = pcall(g_fillTypeManager.getFillTypeNameByIndex, g_fillTypeManager, fillTypeIndex)
        if ok and name ~= nil then
            return tostring(name)
        end
    end

    return tostring(fillTypeIndex)
end

local function dfpGetEconomyPricePerLiter(fillTypeIndex)
    if fillTypeIndex == nil or fillTypeIndex == FillType.UNKNOWN then
        return nil
    end

    if g_currentMission == nil or g_currentMission.economyManager == nil then
        return nil
    end

    local ok, value = pcall(function()
        return g_currentMission.economyManager:getPricePerLiter(fillTypeIndex)
    end)

    if ok then
        return tonumber(value)
    end

    return nil
end

local function dfpGetDisplayMoneyValue(amount)
    local value = tonumber(amount) or 0
    local originalValue = value

    if _G.AdditionalCurrencies ~= nil and type(_G.AdditionalCurrencies.getCurrency) == "function" then
        local okCurrency, currency = pcall(function()
            return _G.AdditionalCurrencies:getCurrency()
        end)

        if okCurrency and currency ~= nil and _G.AdditionalCurrencies.converter == true then
            local factor = tonumber(currency.factor) or 1

            if factor > 0 and factor ~= 1 then
                if factor < 1 then
                    value = value / factor
                else
                    value = value * factor
                end
            end

            if PlaceableDynamicFuelPrice.DEBUG then
                local currencyName = tostring(currency.unitShort or currency.unit or "unknown")
                print(string.format("[DynamicFuelPrice][DEBUG][displayMoney] raw=%.6f factor=%.6f converter=%s currency=%s result=%.6f", originalValue, factor, tostring(_G.AdditionalCurrencies.converter), currencyName, value))
            end
        elseif PlaceableDynamicFuelPrice.DEBUG then
            print(string.format("[DynamicFuelPrice][DEBUG][displayMoney] raw=%.6f converter disabled or currency unavailable -> result=%.6f", originalValue, value))
        end
    elseif PlaceableDynamicFuelPrice.DEBUG then
        print(string.format("[DynamicFuelPrice][DEBUG][displayMoney] raw=%.6f AdditionalCurrencies missing -> result=%.6f", originalValue, value))
    end

    return value
end

function PlaceableDynamicFuelPrice.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(PlaceableBuyingStation, specializations)
end

function PlaceableDynamicFuelPrice.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "setFuelPrice", PlaceableDynamicFuelPrice.setFuelPrice)
    SpecializationUtil.registerFunction(placeableType, "updateFuelPrice", PlaceableDynamicFuelPrice.updateFuelPrice)
    SpecializationUtil.registerFunction(placeableType, "updatePriceDisplays", PlaceableDynamicFuelPrice.updatePriceDisplays)
    SpecializationUtil.registerFunction(placeableType, "getCurrentFuelPrice", PlaceableDynamicFuelPrice.getCurrentFuelPrice)
    SpecializationUtil.registerFunction(placeableType, "getDynamicFuelDeltaPercent", PlaceableDynamicFuelPrice.getDynamicFuelDeltaPercent)
    SpecializationUtil.registerFunction(placeableType, "injectDynamicFuelPriceIntoLoadTriggers", PlaceableDynamicFuelPrice.injectDynamicFuelPriceIntoLoadTriggers)
    SpecializationUtil.registerFunction(placeableType, "installDynamicFuelFillVehicleOverride", PlaceableDynamicFuelPrice.installDynamicFuelFillVehicleOverride)
    SpecializationUtil.registerFunction(placeableType, "getDieselPriceScaleFromBuyingStationXML", PlaceableDynamicFuelPrice.getDieselPriceScaleFromBuyingStationXML)
    SpecializationUtil.registerFunction(placeableType, "getDefaultBaseFuelPrice", PlaceableDynamicFuelPrice.getDefaultBaseFuelPrice)
    SpecializationUtil.registerFunction(placeableType, "refreshBaseFuelPriceFromGame", PlaceableDynamicFuelPrice.refreshBaseFuelPriceFromGame)
    SpecializationUtil.registerFunction(placeableType, "syncBuyingStationPriceScale", PlaceableDynamicFuelPrice.syncBuyingStationPriceScale)
    SpecializationUtil.registerFunction(placeableType, "applyDisplayClipDistance", PlaceableDynamicFuelPrice.applyDisplayClipDistance)
end

function PlaceableDynamicFuelPrice.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableDynamicFuelPrice)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableDynamicFuelPrice)
    SpecializationUtil.registerEventListener(placeableType, "onReadStream", PlaceableDynamicFuelPrice)
    SpecializationUtil.registerEventListener(placeableType, "onWriteStream", PlaceableDynamicFuelPrice)
    SpecializationUtil.registerEventListener(placeableType, "onReadUpdateStream", PlaceableDynamicFuelPrice)
    SpecializationUtil.registerEventListener(placeableType, "onWriteUpdateStream", PlaceableDynamicFuelPrice)
    SpecializationUtil.registerEventListener(placeableType, "onDayChanged", PlaceableDynamicFuelPrice)
    SpecializationUtil.registerEventListener(placeableType, "loadFromXMLFile", PlaceableDynamicFuelPrice)
    SpecializationUtil.registerEventListener(placeableType, "saveToXMLFile", PlaceableDynamicFuelPrice)
end

function PlaceableDynamicFuelPrice.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("DynamicFuelPrice")

    schema:register(XMLValueType.BOOL,  basePath .. ".dynamicFuelPrice#enabled", "Enable dynamic diesel price", true)
    schema:register(XMLValueType.BOOL,  basePath .. ".dynamicFuelPrice#debug", "Enable debug output", false)
    schema:register(XMLValueType.FLOAT, basePath .. ".dynamicFuelPrice#basePrice", "Base diesel purchase price per liter")
    schema:register(XMLValueType.FLOAT, basePath .. ".dynamicFuelPrice#minMultiplier", "Minimum multiplier relative to basePrice", 0.65)
    schema:register(XMLValueType.FLOAT, basePath .. ".dynamicFuelPrice#maxMultiplier", "Maximum multiplier relative to basePrice", 2.00)
    schema:register(XMLValueType.FLOAT, basePath .. ".dynamicFuelPrice#dailyDownMax", "Maximum negative daily change in multiplier units", 0.35)
    schema:register(XMLValueType.FLOAT, basePath .. ".dynamicFuelPrice#dailyUpMax", "Maximum positive daily change in multiplier units", 0.60)
    schema:register(XMLValueType.FLOAT, basePath .. ".dynamicFuelPrice#reversionStrength", "Pull back toward base price each day", 0.12)
    schema:register(XMLValueType.BOOL,  basePath .. ".dynamicFuelPrice#randomizeOnNewSave", "Randomize immediately on first new save load", false)
    schema:register(XMLValueType.FLOAT, basePath .. ".dynamicFuelPrice#displayClipDistance", "Clip distance for generated 3D price characters", 500)

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".dynamicFuelPrice.display(?)#node", "Display start node", nil, false)
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".dynamicFuelPrice.displays.display(?)#node", "Display start node", nil, false)
    schema:register(XMLValueType.STRING,     basePath .. ".dynamicFuelPrice.display(?)#font", "Font name", "DIGIT")
    schema:register(XMLValueType.STRING,     basePath .. ".dynamicFuelPrice.displays.display(?)#font", "Font name", "DIGIT")
    schema:register(XMLValueType.STRING,     basePath .. ".dynamicFuelPrice.display(?)#alignment", "LEFT/CENTER/RIGHT", "RIGHT")
    schema:register(XMLValueType.STRING,     basePath .. ".dynamicFuelPrice.displays.display(?)#alignment", "LEFT/CENTER/RIGHT", "RIGHT")
    schema:register(XMLValueType.FLOAT,      basePath .. ".dynamicFuelPrice.display(?)#size", "Character size", 0.03)
    schema:register(XMLValueType.FLOAT,      basePath .. ".dynamicFuelPrice.displays.display(?)#size", "Character size", 0.03)
    schema:register(XMLValueType.FLOAT,      basePath .. ".dynamicFuelPrice.display(?)#scaleX", "Scale X", 1)
    schema:register(XMLValueType.FLOAT,      basePath .. ".dynamicFuelPrice.displays.display(?)#scaleX", "Scale X", 1)
    schema:register(XMLValueType.FLOAT,      basePath .. ".dynamicFuelPrice.display(?)#scaleY", "Scale Y", 1)
    schema:register(XMLValueType.FLOAT,      basePath .. ".dynamicFuelPrice.displays.display(?)#scaleY", "Scale Y", 1)
    schema:register(XMLValueType.STRING,     basePath .. ".dynamicFuelPrice.display(?)#mask", "Display mask", "0.00")
    schema:register(XMLValueType.STRING,     basePath .. ".dynamicFuelPrice.displays.display(?)#mask", "Display mask", "0.00")
    schema:register(XMLValueType.FLOAT,      basePath .. ".dynamicFuelPrice.display(?)#emissiveScale", "Emissive scale", 0.2)
    schema:register(XMLValueType.FLOAT,      basePath .. ".dynamicFuelPrice.displays.display(?)#emissiveScale", "Emissive scale", 0.2)
    schema:register(XMLValueType.COLOR,      basePath .. ".dynamicFuelPrice.display(?)#color", "Visible color", {0.9, 0.9, 0.9, 1})
    schema:register(XMLValueType.COLOR,      basePath .. ".dynamicFuelPrice.displays.display(?)#color", "Visible color", {0.9, 0.9, 0.9, 1})
    schema:register(XMLValueType.COLOR,      basePath .. ".dynamicFuelPrice.display(?)#hiddenColor", "Hidden color", nil)
    schema:register(XMLValueType.COLOR,      basePath .. ".dynamicFuelPrice.displays.display(?)#hiddenColor", "Hidden color", nil)
    schema:register(XMLValueType.STRING,     basePath .. ".dynamicFuelPrice.display(?)#prefix", "Optional text prefix", "")
    schema:register(XMLValueType.STRING,     basePath .. ".dynamicFuelPrice.displays.display(?)#prefix", "Optional text prefix", "")
    schema:register(XMLValueType.STRING,     basePath .. ".dynamicFuelPrice.display(?)#suffix", "Optional text suffix", "")
    schema:register(XMLValueType.STRING,     basePath .. ".dynamicFuelPrice.displays.display(?)#suffix", "Optional text suffix", "")
    schema:register(XMLValueType.FLOAT,      basePath .. ".dynamicFuelPrice.display(?)#clipDistance", "Clip distance for this display", nil)
    schema:register(XMLValueType.FLOAT,      basePath .. ".dynamicFuelPrice.displays.display(?)#clipDistance", "Clip distance for this display", nil)

    schema:setXMLSpecializationType()
end

function PlaceableDynamicFuelPrice.registerSavegameXMLPaths(schema, basePath)
    schema:register(XMLValueType.FLOAT, basePath .. ".dynamicFuelPrice#currentPrice", "Current station diesel price")
    schema:register(XMLValueType.FLOAT, basePath .. ".dynamicFuelPrice#lastMultiplier", "Current station multiplier")
end

function PlaceableDynamicFuelPrice:applyDisplayClipDistance(characterLine, clipDistance)
    if characterLine == nil or characterLine.characters == nil then
        return
    end

    clipDistance = clipDistance or 500
    if clipDistance <= 0 then
        return
    end

    for _, shape in ipairs(characterLine.characters) do
        if shape ~= nil and shape ~= 0 and entityExists(shape) then
            setClipDistance(shape, clipDistance)
        end
    end
end

local function loadDisplayEntries(self, xmlRootKey)
    local spec = getSpec(self)
    self.xmlFile:iterate(xmlRootKey, function(_, displayKey)
        local displayNode = self.xmlFile:getValue(displayKey .. "#node", nil, self.components, self.i3dMappings)
        dfpDbg(self, "Inspect display entry '%s' -> node=%s", tostring(displayKey), tostring(displayNode))

        if displayNode ~= nil then
            local fontName = string.upper(self.xmlFile:getValue(displayKey .. "#font", "DIGIT"))
            local fontMaterial = g_materialManager:getFontMaterial(fontName, self.customEnvironment)

            if fontMaterial ~= nil then
                local display = {}
                local alignmentStr = self.xmlFile:getValue(displayKey .. "#alignment", "RIGHT")
                local alignment = RenderText["ALIGN_" .. string.upper(alignmentStr)] or RenderText.ALIGN_RIGHT
                local size = self.xmlFile:getValue(displayKey .. "#size", 0.03)
                local scaleX = self.xmlFile:getValue(displayKey .. "#scaleX", 1)
                local scaleY = self.xmlFile:getValue(displayKey .. "#scaleY", 1)
                local mask = self.xmlFile:getValue(displayKey .. "#mask", "0.00")
                local emissiveScale = self.xmlFile:getValue(displayKey .. "#emissiveScale", 0.2)
                local color = self.xmlFile:getValue(displayKey .. "#color", {0.9, 0.9, 0.9, 1}, true)
                local hiddenColor = self.xmlFile:getValue(displayKey .. "#hiddenColor", nil, true)
                local clipDistance = self.xmlFile:getValue(displayKey .. "#clipDistance", spec.displayClipDistance or 500)

                display.prefix = self.xmlFile:getValue(displayKey .. "#prefix", "")
                display.suffix = self.xmlFile:getValue(displayKey .. "#suffix", "")
                display.formatStr, display.formatPrecision = Utils.maskToFormat(mask)
                display.characterLine = CharacterLine.new(displayNode, fontMaterial, string.len(mask) + string.len(display.prefix) + string.len(display.suffix))
                display.characterLine:setSizeAndScale(size, scaleX, scaleY)
                display.characterLine:setTextAlignment(alignment)
                display.characterLine:setColor(color, hiddenColor, emissiveScale)
                self:applyDisplayClipDistance(display.characterLine, clipDistance)
                display.clipDistance = clipDistance
                table.insert(spec.displays, display)
                dfpDbg(self, "Display registered: node=%s font=%s mask=%s clipDistance=%s", tostring(displayNode), tostring(fontName), tostring(mask), tostring(clipDistance))
            else
                dfpWarn(self, "Font material '%s' not found for display '%s'", tostring(fontName), tostring(displayKey))
            end
        end
    end)
end

local function subscribeDayChanged(self)
    local spec = getSpec(self)

    if not self.isServer or spec.dayChangedSubscribed then
        return
    end

    if g_messageCenter == nil then
        dfpWarn(self, "g_messageCenter is nil, DAY_CHANGED subscription skipped")
        return
    end

    spec.dayChangedCallback = function()
        local currentSpec = getSpec(self)
        dfpDbg(self, "DAY_CHANGED message received: isServer=%s enabled=%s", tostring(self.isServer), tostring(currentSpec.enabled))
        if self.isServer and currentSpec.enabled then
            PlaceableDynamicFuelPrice.updateFuelPrice(self, false)
        end
    end

    g_messageCenter:subscribe(MessageType.DAY_CHANGED, spec.dayChangedCallback)
    spec.dayChangedSubscribed = true
    dfpDbg(self, "Subscribed to MessageType.DAY_CHANGED")
end

local function unsubscribeDayChanged(self)
    local spec = getSpec(self)

    if spec.dayChangedSubscribed and spec.dayChangedCallback ~= nil and g_messageCenter ~= nil then
        g_messageCenter:unsubscribe(MessageType.DAY_CHANGED, spec.dayChangedCallback)
        dfpDbg(self, "Unsubscribed from MessageType.DAY_CHANGED")
    end

    spec.dayChangedSubscribed = false
    spec.dayChangedCallback = nil
end

function PlaceableDynamicFuelPrice:onLoad(savegame)
    local spec = getSpec(self)
    local key = "placeable.dynamicFuelPrice"

    spec.enabled = self.xmlFile:getValue(key .. "#enabled", true)
    spec.debug = self.xmlFile:getValue(key .. "#debug", PlaceableDynamicFuelPrice.DEBUG)
    PlaceableDynamicFuelPrice.DEBUG = spec.debug
    spec.displays = {}
    spec.dirtyFlag = self:getNextDirtyFlag()
    spec.lastDeltaPercent = spec.lastDeltaPercent or 0
    spec.dayChangedSubscribed = false
    spec.dayChangedCallback = nil

    dfpDbg(self, "onLoad start: enabled=%s", tostring(spec.enabled))

    if not spec.enabled then
        dfpDbg(self, "Specialization disabled in XML")
        return
    end

    spec.minMultiplier = self.xmlFile:getValue(key .. "#minMultiplier", 0.65)
    spec.maxMultiplier = self.xmlFile:getValue(key .. "#maxMultiplier", 2.00)
    spec.dailyDownMax = self.xmlFile:getValue(key .. "#dailyDownMax", 0.35)
    spec.dailyUpMax = self.xmlFile:getValue(key .. "#dailyUpMax", 0.60)
    spec.reversionStrength = self.xmlFile:getValue(key .. "#reversionStrength", 0.12)
    spec.randomizeOnNewSave = self.xmlFile:getValue(key .. "#randomizeOnNewSave", false)
    spec.displayClipDistance = self.xmlFile:getValue(key .. "#displayClipDistance", 500)

    spec.basePrice = self.xmlFile:getValue(key .. "#basePrice", self:getDefaultBaseFuelPrice())
    if spec.basePrice == nil or spec.basePrice <= 0 then
        spec.basePrice = 1
    end

    self:refreshBaseFuelPriceFromGame()

    spec.currentPrice = spec.currentPrice or spec.basePrice
    spec.lastMultiplier = spec.lastMultiplier or (spec.currentPrice / math.max(spec.basePrice, 0.0001))

    dfpDbg(self, "Config loaded: basePrice=%.4f currentPrice=%.4f lastMultiplier=%.6f min=%.3f max=%.3f down=%.3f up=%.3f reversion=%.3f clipDistance=%s", spec.basePrice, spec.currentPrice or 0, spec.lastMultiplier or 0, spec.minMultiplier, spec.maxMultiplier, spec.dailyDownMax, spec.dailyUpMax, spec.reversionStrength, tostring(spec.displayClipDistance))

    if (savegame == nil or savegame.resetVehicles) and self.isServer and spec.randomizeOnNewSave then
        dfpDbg(self, "Randomizing on new save")
        self:updateFuelPrice(true)
    else
        dfpDbg(self, "Skipping randomizeOnNewSave branch; currentPrice=%.4f lastMultiplier=%.4f", spec.currentPrice or 0, spec.lastMultiplier or 0)
    end

    loadDisplayEntries(self, key .. ".display")
    loadDisplayEntries(self, key .. ".displays.display")
    dfpDbg(self, "Displays total=%d", #spec.displays)

    self:injectDynamicFuelPriceIntoLoadTriggers()
    self:syncBuyingStationPriceScale()
    self:updatePriceDisplays()
    subscribeDayChanged(self)
    dfpDbg(self, "onLoad finish")
end

function PlaceableDynamicFuelPrice:onDelete()
    local spec = getSpec(self)
    if not spec.enabled then
        unsubscribeDayChanged(self)
        return
    end

    dfpDbg(self, "onDelete")
    unsubscribeDayChanged(self)

    local buyingStation = self.getBuyingStation ~= nil and self:getBuyingStation() or nil
    if buyingStation ~= nil and buyingStation.loadTriggers ~= nil then
        for _, loadTrigger in ipairs(buyingStation.loadTriggers) do
            if loadTrigger.saDynamicFuelPriceOriginalFillVehicle ~= nil then
                loadTrigger.fillVehicle = loadTrigger.saDynamicFuelPriceOriginalFillVehicle
                loadTrigger.saDynamicFuelPriceOriginalFillVehicle = nil
                loadTrigger.saDynamicFuelPricePlaceable = nil
            end
        end
    end
end

function PlaceableDynamicFuelPrice:onReadStream(streamId, connection)
    if connection:getIsServer() then
        local spec = getSpec(self)
        spec.enabled = streamReadBool(streamId)
        spec.basePrice = streamReadFloat32(streamId)
        spec.currentPrice = streamReadFloat32(streamId)
        spec.lastMultiplier = streamReadFloat32(streamId)
        spec.lastDeltaPercent = streamReadFloat32(streamId)
        dfpDbg(self, "onReadStream: enabled=%s base=%.4f current=%.4f mult=%.4f delta=%.4f", tostring(spec.enabled), spec.basePrice or 0, spec.currentPrice or 0, spec.lastMultiplier or 0, spec.lastDeltaPercent or 0)
        self:syncBuyingStationPriceScale()
        self:updatePriceDisplays()
    end
end

function PlaceableDynamicFuelPrice:onWriteStream(streamId, connection)
    if not connection:getIsServer() then
        local spec = getSpec(self)
        streamWriteBool(streamId, spec.enabled == true)
        streamWriteFloat32(streamId, spec.basePrice or 0)
        streamWriteFloat32(streamId, spec.currentPrice or 0)
        streamWriteFloat32(streamId, spec.lastMultiplier or 1)
        streamWriteFloat32(streamId, spec.lastDeltaPercent or 0)
    end
end

function PlaceableDynamicFuelPrice:onReadUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        local spec = getSpec(self)
        if streamReadBool(streamId) then
            spec.currentPrice = streamReadFloat32(streamId)
            spec.lastMultiplier = streamReadFloat32(streamId)
            spec.lastDeltaPercent = streamReadFloat32(streamId)
            dfpDbg(self, "onReadUpdateStream: current=%.4f mult=%.4f delta=%.4f", spec.currentPrice or 0, spec.lastMultiplier or 0, spec.lastDeltaPercent or 0)
            self:syncBuyingStationPriceScale()
            self:updatePriceDisplays()
        end
    end
end

function PlaceableDynamicFuelPrice:onWriteUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        local spec = getSpec(self)
        local hasUpdate = spec.dirtyFlag ~= nil and bitAND(dirtyMask, spec.dirtyFlag) ~= 0
        if streamWriteBool(streamId, hasUpdate) then
            streamWriteFloat32(streamId, spec.currentPrice or 0)
            streamWriteFloat32(streamId, spec.lastMultiplier or 1)
            streamWriteFloat32(streamId, spec.lastDeltaPercent or 0)
        end
    end
end

function PlaceableDynamicFuelPrice:loadFromXMLFile(xmlFile, key)
    local spec = getSpec(self)

    if spec.enabled == nil then
        spec.enabled = true
    end

    if spec.enabled then
        local loadedCurrentPrice = xmlFile:getValue(key .. ".dynamicFuelPrice#currentPrice", spec.currentPrice)
        local loadedLastMultiplier = xmlFile:getValue(key .. ".dynamicFuelPrice#lastMultiplier", spec.lastMultiplier)
        spec.currentPrice = loadedCurrentPrice
        spec.lastMultiplier = loadedLastMultiplier
        dfpDbg(self, "loadFromXMLFile: key=%s loadedCurrentPrice=%.6f loadedLastMultiplier=%.6f", tostring(key), spec.currentPrice or 0, spec.lastMultiplier or 0)
    end
end

function PlaceableDynamicFuelPrice:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = getSpec(self)
    if spec.enabled then
        xmlFile:setValue(key .. ".dynamicFuelPrice#currentPrice", spec.currentPrice)
        xmlFile:setValue(key .. ".dynamicFuelPrice#lastMultiplier", spec.lastMultiplier)
        dfpDbg(self, "saveToXMLFile: key=%s savingCurrentPrice=%.6f savingLastMultiplier=%.6f basePrice=%.6f", tostring(key), spec.currentPrice or 0, spec.lastMultiplier or 0, spec.basePrice or 0)
    end
end

function PlaceableDynamicFuelPrice:onDayChanged()
    local spec = getSpec(self)
    dfpDbg(self, "onDayChanged event: isServer=%s enabled=%s", tostring(self.isServer), tostring(spec.enabled))
    if self.isServer and spec.enabled then
        self:updateFuelPrice(false)
    end
end

function PlaceableDynamicFuelPrice:getDieselPriceScaleFromBuyingStationXML()
    local xmlFile = self.xmlFile
    local priceScale = 1

    xmlFile:iterate("placeable.buyingStation.fillType", function(_, fillTypeKey)
        local fillTypeName = xmlFile:getValue(fillTypeKey .. "#name")
        local entryPriceScale = xmlFile:getValue(fillTypeKey .. "#priceScale", 1)

        dfpDbg(self, "getDieselPriceScaleFromBuyingStationXML: entry=%s fillTypeName=%s entryPriceScale=%.6f", tostring(fillTypeKey), tostring(fillTypeName), tonumber(entryPriceScale) or -1)

        if fillTypeName ~= nil and string.upper(fillTypeName) == "DIESEL" then
            priceScale = entryPriceScale
            dfpDbg(self, "getDieselPriceScaleFromBuyingStationXML: DIESEL matched -> selected priceScale=%.6f", tonumber(priceScale) or -1)
            return false
        end
        return true
    end)

    dfpDbg(self, "getDieselPriceScaleFromBuyingStationXML: final priceScale=%.6f", tonumber(priceScale) or -1)
    return priceScale
end

function PlaceableDynamicFuelPrice:getDefaultBaseFuelPrice()
    local dieselIndex = g_fillTypeManager:getFillTypeIndexByName("DIESEL")
    local dieselName = dfpSafeGetFillTypeName(dieselIndex)
    local globalPrice = 1
    local priceScale = self:getDieselPriceScaleFromBuyingStationXML()

    if dieselIndex ~= nil and dieselIndex ~= FillType.UNKNOWN and g_currentMission ~= nil and g_currentMission.economyManager ~= nil then
        globalPrice = g_currentMission.economyManager:getPricePerLiter(dieselIndex)
    end

    local finalBasePrice = (tonumber(globalPrice) or 0) * (tonumber(priceScale) or 1)

    dfpDbg(self, "getDefaultBaseFuelPrice: dieselIndex=%s dieselName=%s economyPricePerLiter=%.6f priceScale=%.6f finalBasePrice=%.6f", tostring(dieselIndex), tostring(dieselName), tonumber(globalPrice) or -1, tonumber(priceScale) or -1, tonumber(finalBasePrice) or -1)

    return finalBasePrice
end

function PlaceableDynamicFuelPrice:refreshBaseFuelPriceFromGame()
    local spec = getSpec(self)
    local oldBasePrice = spec.basePrice
    local refreshedBasePrice = self:getDefaultBaseFuelPrice()

    if refreshedBasePrice == nil or refreshedBasePrice <= 0 then
        dfpWarn(self, "refreshBaseFuelPriceFromGame: invalid refreshedBasePrice=%s, fallback to old/spec base", tostring(refreshedBasePrice))
        refreshedBasePrice = spec.basePrice or 1
    end

    spec.basePrice = refreshedBasePrice
    dfpDbg(self, "refreshBaseFuelPriceFromGame: oldBasePrice=%.6f newBasePrice=%.6f", tonumber(oldBasePrice) or -1, tonumber(spec.basePrice) or -1)
    return spec.basePrice
end

function PlaceableDynamicFuelPrice:syncBuyingStationPriceScale()
    local spec = getSpec(self)
    if not spec.enabled then
        return
    end

    local buyingStation = self.getBuyingStation ~= nil and self:getBuyingStation() or nil
    if buyingStation == nil then
        dfpWarn(self, "syncBuyingStationPriceScale: buyingStation missing")
        return
    end

    local dieselIndex = g_fillTypeManager ~= nil and g_fillTypeManager:getFillTypeIndexByName("DIESEL") or nil
    if dieselIndex == nil or dieselIndex == FillType.UNKNOWN then
        dfpWarn(self, "syncBuyingStationPriceScale: invalid dieselIndex=%s", tostring(dieselIndex))
        return
    end

    local fillType = g_fillTypeManager ~= nil and g_fillTypeManager:getFillTypeByIndex(dieselIndex) or nil
    local basePricePerLiter = fillType ~= nil and tonumber(fillType.pricePerLiter) or nil
    local currentPrice = tonumber(spec.currentPrice) or 0

    if basePricePerLiter == nil or basePricePerLiter <= 0 then
        dfpWarn(self, "syncBuyingStationPriceScale: invalid fillType.pricePerLiter=%s for dieselIndex=%s", tostring(basePricePerLiter), tostring(dieselIndex))
        return
    end

    local newPriceScale = currentPrice / basePricePerLiter

    buyingStation.fillTypePricesScale = buyingStation.fillTypePricesScale or {}
    buyingStation.fillTypePricesScale[dieselIndex] = newPriceScale

    dfpDbg(self, "syncBuyingStationPriceScale: dieselIndex=%s fillTypeBasePrice=%.6f currentPrice=%.6f newPriceScale=%.6f", tostring(dieselIndex), basePricePerLiter, currentPrice, newPriceScale)
end

function PlaceableDynamicFuelPrice:getCurrentFuelPrice(fillTypeIndex)
    local spec = getSpec(self)
    local fillTypeName = dfpSafeGetFillTypeName(fillTypeIndex)

    if spec.enabled and fillTypeIndex == FillType.DIESEL then
        dfpDbg(self, "getCurrentFuelPrice: fillType=%s using dynamic currentPrice=%.6f basePrice=%.6f lastMultiplier=%.6f", tostring(fillTypeName), spec.currentPrice or 0, spec.basePrice or 0, spec.lastMultiplier or 0)
        return spec.currentPrice
    end

    local fallbackPrice = dfpGetEconomyPricePerLiter(fillTypeIndex) or 0
    dfpDbg(self, "getCurrentFuelPrice: fillType=%s using economy fallback price=%.6f", tostring(fillTypeName), fallbackPrice)
    return fallbackPrice
end

function PlaceableDynamicFuelPrice:getDynamicFuelDeltaPercent()
    local spec = getSpec(self)
    return spec.lastDeltaPercent or 0
end

function PlaceableDynamicFuelPrice:setFuelPrice(newPrice)
    local spec = getSpec(self)
    if not spec.enabled then
        return
    end

    local minPrice = spec.basePrice * spec.minMultiplier
    local maxPrice = spec.basePrice * spec.maxMultiplier
    spec.currentPrice = dfpClamp(newPrice, minPrice, maxPrice)
    spec.lastMultiplier = spec.currentPrice / math.max(spec.basePrice, 0.0001)

    dfpDbg(self, "setFuelPrice: requested=%.6f minPrice=%.6f maxPrice=%.6f clamped=%.6f resultingMultiplier=%.6f", newPrice or 0, minPrice or 0, maxPrice or 0, spec.currentPrice or 0, spec.lastMultiplier or 0)

    self:syncBuyingStationPriceScale()
    self:updatePriceDisplays()

    if self.isServer and spec.dirtyFlag ~= nil then
        self:raiseDirtyFlags(spec.dirtyFlag)
    end
end

function PlaceableDynamicFuelPrice:updateFuelPrice(isInitial)
    local spec = getSpec(self)
    if not spec.enabled then
        return
    end

    local oldPrice = spec.currentPrice
    local oldBasePrice = spec.basePrice
    local oldMultiplier = spec.lastMultiplier
    local refreshedBasePrice = self:refreshBaseFuelPriceFromGame()

    spec.currentPrice = refreshedBasePrice
    local currentMultiplier = 1.0

    dfpDbg(self, "updateFuelPrice start: isInitial=%s oldPrice=%.6f oldBasePrice=%.6f oldMultiplier=%.6f refreshedBasePrice=%.6f", tostring(isInitial), oldPrice or 0, oldBasePrice or 0, oldMultiplier or 0, refreshedBasePrice or 0)

    local upwardRoomFactor = dfpClamp((spec.maxMultiplier - currentMultiplier) / math.max(spec.maxMultiplier - 1.0, 0.0001), 0, 1)
    local downwardRoomFactor = dfpClamp((currentMultiplier - spec.minMultiplier) / math.max(1.0 - spec.minMultiplier, 0.0001), 0, 1)

    upwardRoomFactor = math.max(upwardRoomFactor, 0.05)
    downwardRoomFactor = math.max(downwardRoomFactor, 0.05)

    local maxUpToday = spec.dailyUpMax * upwardRoomFactor
    local maxDownToday = spec.dailyDownMax * downwardRoomFactor

    local randomChange = math.random() * (maxUpToday + maxDownToday) - maxDownToday
    local reversionBias = (1.0 - currentMultiplier) * spec.reversionStrength

    dfpDbg(self, "updateFuelPrice ranges: currentMultiplier=%.6f upwardRoomFactor=%.6f downwardRoomFactor=%.6f maxUpToday=%.6f maxDownToday=%.6f randomChange=%.6f reversionBias=%.6f", currentMultiplier or 0, upwardRoomFactor or 0, downwardRoomFactor or 0, maxUpToday or 0, maxDownToday or 0, randomChange or 0, reversionBias or 0)

    local newMultiplier = currentMultiplier + randomChange + reversionBias
    newMultiplier = dfpClamp(newMultiplier, spec.minMultiplier, spec.maxMultiplier)

    if isInitial and math.abs(newMultiplier - currentMultiplier) < 0.01 then
        newMultiplier = dfpClamp(currentMultiplier + 0.05, spec.minMultiplier, spec.maxMultiplier)
    end

    local newPrice = refreshedBasePrice * newMultiplier

    spec.lastDeltaPercent = 0
    if oldPrice ~= nil and oldPrice > 0 then
        spec.lastDeltaPercent = ((newPrice - oldPrice) / oldPrice) * 100
    end

    spec.lastMultiplier = newMultiplier

    dfpDbg(self, "updateFuelPrice end: old=%.6f refreshedBase=%.6f new=%.6f oldMult=%.6f newMult=%.6f deltaPercent=%.6f", oldPrice or 0, refreshedBasePrice or 0, newPrice or 0, currentMultiplier or 0, newMultiplier or 0, spec.lastDeltaPercent or 0)

    self:setFuelPrice(newPrice)
end

function PlaceableDynamicFuelPrice:updatePriceDisplays()
    local spec = getSpec(self)
    if spec.displays == nil or spec.currentPrice == nil then
        return
    end

    local displayMoneyValue = dfpGetDisplayMoneyValue(spec.currentPrice)

    for index, display in ipairs(spec.displays) do
        if display.characterLine ~= nil then
            local intPart, floatPart = math.modf(displayMoneyValue)
            local precision = display.formatPrecision or 0
            local multiplier = 10 ^ precision
            local decimals = math.abs(math.floor(floatPart * multiplier + 0.5))

            if decimals >= multiplier then
                intPart = intPart + 1
                decimals = 0
            end

            local value = string.format(display.formatStr, intPart, decimals)
            local finalText = string.format("%s%s%s", display.prefix or "", value, display.suffix or "")
            display.characterLine:setText(finalText)
            dfpDbg(self, "updatePriceDisplays[%d]: basePrice=%.6f rawCurrentPrice=%.6f displayMoneyValue=%.6f format='%s' precision=%s text='%s'", index, spec.basePrice or 0, spec.currentPrice or 0, displayMoneyValue or 0, tostring(display.formatStr), tostring(display.formatPrecision), tostring(finalText))
        end
    end
end

function PlaceableDynamicFuelPrice:injectDynamicFuelPriceIntoLoadTriggers()
    local spec = getSpec(self)
    if not spec.enabled then
        return
    end

    local buyingStation = self.getBuyingStation ~= nil and self:getBuyingStation() or nil
    if buyingStation == nil or buyingStation.loadTriggers == nil then
        dfpWarn(self, "buyingStation or loadTriggers missing")
        return
    end

    dfpDbg(self, "Injecting into %d loadTriggers for buyingStation=%s", #buyingStation.loadTriggers, tostring(buyingStation))
    for _, loadTrigger in ipairs(buyingStation.loadTriggers) do
        self:installDynamicFuelFillVehicleOverride(loadTrigger)
    end
end

function PlaceableDynamicFuelPrice:installDynamicFuelFillVehicleOverride(loadTrigger)
    if loadTrigger == nil or loadTrigger.saDynamicFuelPriceOriginalFillVehicle ~= nil then
        return
    end

    loadTrigger.saDynamicFuelPricePlaceable = self
    loadTrigger.saDynamicFuelPriceOriginalFillVehicle = loadTrigger.fillVehicle

    dfpDbg(self, "Installing fillVehicle override on trigger=%s", tostring(loadTrigger.triggerNode or loadTrigger))

    loadTrigger.fillVehicle = function(triggerSelf, vehicle, delta, dt)
        local placeable = triggerSelf.saDynamicFuelPricePlaceable
        if placeable ~= nil then
            dfpDbg(placeable, "fillVehicle start: delta=%.4f dt=%.4f vehicle=%s", delta or 0, dt or 0, tostring(vehicle))
        end

        if triggerSelf.fillLitersPerSecond ~= nil then
            delta = math.min(delta, triggerSelf.fillLitersPerSecond * 0.001 * dt)
        end

        local farmId = vehicle:getActiveFarm()

        if triggerSelf.sourceObject ~= nil then
            local sourceFuelFillLevel = triggerSelf.sourceObject:getFillUnitFillLevel(triggerSelf.fillUnitIndex)
            if sourceFuelFillLevel > 0 and g_currentMission.accessHandler:canFarmAccess(farmId, triggerSelf.sourceObject) then
                delta = math.min(delta, sourceFuelFillLevel)
                if delta <= 0 then
                    return 0
                end
            else
                return 0
            end
        end

        local fillType = triggerSelf:getCurrentFillType()
        local fillTypeName = dfpSafeGetFillTypeName(fillType)
        local economyPricePerLiter = dfpGetEconomyPricePerLiter(fillType)

        if placeable ~= nil then
            dfpDbg(placeable, "fillVehicle current fillType: index=%s name=%s economyPricePerLiter=%.6f", tostring(fillType), tostring(fillTypeName), economyPricePerLiter or -1)
        end

        local fillUnitIndex
        if triggerSelf.vehicleToFillUnitIndices[vehicle] ~= nil then
            for _, vehicleFillUnitIndex in pairs(triggerSelf.vehicleToFillUnitIndices[vehicle]) do
                if vehicle:getFillUnitCanBeFilled(vehicleFillUnitIndex, fillType) then
                    fillUnitIndex = vehicleFillUnitIndex
                    break
                end
            end
        end

        if fillUnitIndex == nil then
            return 0
        end

        if vehicle.getCustomFillTriggerSpeedFactor ~= nil then
            delta = delta * vehicle:getCustomFillTriggerSpeedFactor(triggerSelf, fillUnitIndex, fillType)
        end

        delta = vehicle:addFillUnitFillLevel(farmId, fillUnitIndex, delta, fillType, ToolType.TRIGGER, nil)

        if delta > 0 then
            if triggerSelf.sourceObject ~= nil then
                triggerSelf.sourceObject:addFillUnitFillLevel(farmId, triggerSelf.fillUnitIndex, -delta, fillType, ToolType.TRIGGER, nil)
            else
                local currentPlaceable = triggerSelf.saDynamicFuelPricePlaceable
                local pricePerLiter = currentPlaceable:getCurrentFuelPrice(fillType)
                local price = delta * pricePerLiter
                g_farmManager:updateFarmStats(farmId, "expenses", price)
                g_currentMission:addMoney(-price, farmId, triggerSelf.moneyChangeType, true)
                dfpDbg(currentPlaceable, "fillVehicle charged: fillType=%s liters=%.6f economyPricePerLiter=%.6f dynamicPricePerLiter=%.6f total=%.6f farmId=%s", tostring(fillTypeName), delta or 0, economyPricePerLiter or -1, pricePerLiter or 0, price or 0, tostring(farmId))
            end
        end

        return delta
    end
end
