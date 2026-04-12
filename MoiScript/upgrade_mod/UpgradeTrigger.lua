UpgradeTrigger = {}
UpgradeTrigger.MOD_NAME = g_currentModName
UpgradeTrigger.MOD_DIR = g_currentModDirectory

local UT_STATIC_MOD_NAME = g_currentModName
local UT_LOG_PREFIX = "[UpgradeTrigger]"
local UT_MOD_DIR = UpgradeTrigger.MOD_DIR or g_currentModDirectory or ""
local UT_DEBUG = false
local UT_DEBUG_VERBOSE = false

local function utFormatLogMessage(message, ...)
    local template = tostring(message or "")
    local argsCount = select("#", ...)
    if argsCount == 0 then
        return template
    end

    local ok, formatted = pcall(string.format, template, ...)
    if ok then
        return formatted
    end

    return template
end

local function utLog(message, ...)
    if not UT_DEBUG then
        return
    end

    print(string.format("%s [DEBUG] %s", UT_LOG_PREFIX, utFormatLogMessage(message, ...)))
end

local function utLogVerbose(message, ...)
    if not UT_DEBUG_VERBOSE then
        return
    end

    print(string.format("%s [VERBOSE] %s", UT_LOG_PREFIX, utFormatLogMessage(message, ...)))
end

local function utWarn(message, ...)
    print(string.format("%s [WARN] %s", UT_LOG_PREFIX, utFormatLogMessage(message, ...)))
end

local function utFormatDisplayMoney(value)
    local amount = tonumber(value) or 0
    local customCandidates = {
        {obj = _G.g_currencyManager, fn = "formatMoney", mode = "method"},
        {obj = _G.g_currencyManager, fn = "getMoneyString", mode = "method"},
        {obj = _G.g_currencyConverter, fn = "formatMoney", mode = "method"},
        {obj = _G.g_currencyConverter, fn = "toDisplayString", mode = "method"},
        {obj = _G.g_customCurrency, fn = "formatMoney", mode = "method"},
        {obj = _G.CurrencyUtil, fn = "formatMoney", mode = "function"},
        {obj = _G.CurrencyUtil, fn = "getMoneyString", mode = "function"}
    }

    for _, candidate in ipairs(customCandidates) do
        local obj = candidate.obj
        local fn = obj ~= nil and obj[candidate.fn] or nil
        if type(fn) == "function" then
            local ok, result = nil, nil
            if candidate.mode == "method" then
                ok, result = pcall(fn, obj, amount)
            else
                ok, result = pcall(fn, amount)
            end

            if ok and result ~= nil and result ~= "" then
                utLog(string.format("money display formatter=custom.%s raw=%s display='%s'", tostring(candidate.fn), tostring(amount), tostring(result)))
                return tostring(result)
            end
        end
    end

    if g_i18n ~= nil and g_i18n.formatMoney ~= nil then
        local fallback = g_i18n:formatMoney(amount, 0, true, true)
        utLog(string.format("money display formatter=fallback.g_i18n raw=%s display='%s'", tostring(amount), tostring(fallback)))
        return fallback
    end

    local rawText = tostring(amount)
    utWarn(string.format("money display formatter=raw raw=%s display='%s'", tostring(amount), rawText))
    return rawText
end

local function utError(message, ...)
    print(string.format("%s [ERROR] %s", UT_LOG_PREFIX, utFormatLogMessage(message, ...)))
end

local function utSafeRemoveTrigger(triggerNode)
    if triggerNode == nil or triggerNode == 0 then
        return
    end

    if entityExists ~= nil and not entityExists(triggerNode) then
        utLog("utSafeRemoveTrigger skipped: trigger node already deleted (%s)", tostring(triggerNode))
        return
    end

    local ok, err = pcall(removeTrigger, triggerNode)
    if not ok then
        utWarn("utSafeRemoveTrigger failed for node=%s: %s", tostring(triggerNode), tostring(err))
    end
end

local function utNormalizeDir(dir)
    if dir == nil or dir == "" then
        return ""
    end

    if dir:sub(-1) ~= "/" and dir:sub(-1) ~= "\\" then
        dir = dir .. "/"
    end

    return dir
end

local function utGetDirname(path)
    if path == nil or path == "" then
        return ""
    end

    local normalized = tostring(path):gsub("\\", "/")
    local dir = normalized:match("^(.*)/[^/]*$")
    return utNormalizeDir(dir or "")
end

local function utResolveModDir()
    if UT_MOD_DIR ~= nil and UT_MOD_DIR ~= "" then
        return utNormalizeDir(UT_MOD_DIR)
    end

    if UpgradeTrigger.MOD_DIR ~= nil and UpgradeTrigger.MOD_DIR ~= "" then
        return utNormalizeDir(UpgradeTrigger.MOD_DIR)
    end

    if g_currentModDirectory ~= nil and g_currentModDirectory ~= "" then
        return utNormalizeDir(g_currentModDirectory)
    end

    return ""
end

local UT_GUI_XML = utResolveModDir() .. "scripts/upgrade_mod/gui/UpgradeGUI.xml"

local UT_UPGRADE_XML_SCHEMA = nil
local UT_PLACEABLE_INFO_XML_SCHEMA = nil

local function utGetUpgradeXMLSchema()
    if UT_UPGRADE_XML_SCHEMA ~= nil then
        return UT_UPGRADE_XML_SCHEMA
    end

    local schema = XMLSchema.new("upgrades")
    schema:register(XMLValueType.STRING, "upgrades.upgrade(?)#sourceUniqueId")
    schema:register(XMLValueType.STRING, "upgrades.upgrade(?)#title")
    schema:register(XMLValueType.STRING, "upgrades.upgrade(?)#description")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrade(?)#price")
    schema:register(XMLValueType.STRING, "upgrades.upgrade(?).spawn(?)#xmlFilename")
    schema:register(XMLValueType.STRING, "upgrades.upgrade(?).spawn(?)#uniqueId")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrade(?).spawn(?)#offsetX")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrade(?).spawn(?)#offsetY")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrade(?).spawn(?)#offsetZ")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrade(?).spawn(?)#rotOffsetX")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrade(?).spawn(?)#rotOffsetY")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrade(?).spawn(?)#rotOffsetZ")
    schema:register(XMLValueType.STRING, "upgrades.upgrades.upgrade(?)#sourceUniqueId")
    schema:register(XMLValueType.STRING, "upgrades.upgrades.upgrade(?)#title")
    schema:register(XMLValueType.STRING, "upgrades.upgrades.upgrade(?)#description")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrades.upgrade(?)#price")
    schema:register(XMLValueType.STRING, "upgrades.upgrades.upgrade(?).spawn(?)#xmlFilename")
    schema:register(XMLValueType.STRING, "upgrades.upgrades.upgrade(?).spawn(?)#uniqueId")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrades.upgrade(?).spawn(?)#offsetX")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrades.upgrade(?).spawn(?)#offsetY")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrades.upgrade(?).spawn(?)#offsetZ")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrades.upgrade(?).spawn(?)#rotOffsetX")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrades.upgrade(?).spawn(?)#rotOffsetY")
    schema:register(XMLValueType.FLOAT, "upgrades.upgrades.upgrade(?).spawn(?)#rotOffsetZ")

    UT_UPGRADE_XML_SCHEMA = schema
    return schema
end

local function utGetPlaceableInfoSchema()
    if UT_PLACEABLE_INFO_XML_SCHEMA ~= nil then
        return UT_PLACEABLE_INFO_XML_SCHEMA
    end

    local schema = XMLSchema.new("placeableInfo")
    schema:register(XMLValueType.STRING, "placeable.storeData.name")
    schema:register(XMLValueType.STRING, "placeable.storeData.image")
    schema:register(XMLValueType.STRING, "placeable.storeData.functions.function")
    schema:register(XMLValueType.STRING, "placeable.storeData.functions.function(?)")

    UT_PLACEABLE_INFO_XML_SCHEMA = schema
    return schema
end

local function utTryGetText(key)
    if g_i18n == nil or key == nil or key == "" then
        return nil
    end

    local ok, text = pcall(function()
        return g_i18n:getText(key)
    end)

    if ok and text ~= nil and text ~= "" then
        return text
    end

    return nil
end

local function utResolveL10NText(rawText)
    if rawText == nil or rawText == "" then
        return rawText
    end

    if type(rawText) ~= "string" then
        return tostring(rawText)
    end

    if rawText:sub(1, 6) == "$l10n_" then
        return utTryGetText(rawText:sub(7)) or rawText
    end

    return rawText
end

local function utResolveActionText(rawText)
    local fallback = utTryGetText("action_orderUpgrade") or utTryGetText("action_openUpgrade") or utTryGetText("action_activateObject") or "Open upgrade"

    if rawText == nil or rawText == "" then
        return fallback
    end

    if type(rawText) ~= "string" then
        return tostring(rawText)
    end

    if rawText:sub(1, 6) == "$l10n_" then
        local key = rawText:sub(7)
        return utTryGetText(key) or fallback
    end

    if rawText:match("^[%a_][%w_%.%-]*$") ~= nil then
        local translated = utTryGetText(rawText)
        if translated ~= nil and translated ~= "" then
            return translated
        end
    end

    return rawText
end

local function utNodeName(nodeId)
    if nodeId == nil or nodeId == 0 or getName == nil then
        return "nil"
    end

    local ok, name = pcall(getName, nodeId)
    if ok and name ~= nil and name ~= "" then
        return tostring(name)
    end

    return tostring(nodeId)
end

local function utDumpNodeRecursive(nodeId, depth, outLines, maxDepth)
    depth = depth or 0
    maxDepth = maxDepth or 4
    if nodeId == nil or nodeId == 0 or depth > maxDepth then
        return
    end

    table.insert(outLines, string.rep("  ", depth) .. "- " .. utNodeName(nodeId) .. " [" .. tostring(nodeId) .. "]")

    if getNumOfChildren == nil or getChildAt == nil then
        return
    end

    local count = getNumOfChildren(nodeId)
    for i = 0, count - 1 do
        utDumpNodeRecursive(getChildAt(nodeId, i), depth + 1, outLines, maxDepth)
    end
end

local function utFindChildByName(nodeId, wantedName)
    if nodeId == nil or nodeId == 0 or wantedName == nil or wantedName == "" then
        return nil
    end

    if getName ~= nil and getName(nodeId) == wantedName then
        return nodeId
    end

    if getNumOfChildren == nil or getChildAt == nil then
        return nil
    end

    local childCount = getNumOfChildren(nodeId)
    for i = 0, childCount - 1 do
        local child = getChildAt(nodeId, i)
        local found = utFindChildByName(child, wantedName)
        if found ~= nil then
            return found
        end
    end

    return nil
end

local function utExposeGlobal(name, value)
    _G[name] = value

    local rootEnv = getfenv ~= nil and getfenv(0) or nil
    if rootEnv ~= nil then
        rootEnv[name] = value
    end
end

g_upgradeTriggerOnCreateData = g_upgradeTriggerOnCreateData or {}

local function utGetMapDir()
    if g_currentMission ~= nil and g_currentMission.baseDirectory ~= nil then
        return utNormalizeDir(g_currentMission.baseDirectory)
    end

    return ""
end

local function utIsAbsolutePath(path)
    if path == nil or path == "" then
        return false
    end

    local normalized = tostring(path):gsub("\\", "/")
    if normalized:match("^[A-Za-z]:/") ~= nil then
        return true
    end

    if normalized:sub(1, 1) == "/" then
        return true
    end

    if normalized:sub(1, 2) == "//" then
        return true
    end

    return false
end

local function utSafeReplace(value, pattern, replacement)
    if value == nil then
        return nil
    end

    return tostring(value):gsub(pattern, function()
        return tostring(replacement or "")
    end)
end

local function utResolveConfigPath(rawPath, baseDir)
    if rawPath == nil or rawPath == "" then
        return nil
    end

    local result = tostring(rawPath)
    result = utSafeReplace(result, "%$moddir%$", utResolveModDir())
    result = utSafeReplace(result, "%$mapdir%$", utGetMapDir())

    if utIsAbsolutePath(result) then
        return result
    end

    local resolvedBaseDir = baseDir or utResolveModDir()
    local resolved = Utils.getFilename(result, resolvedBaseDir)
    return resolved
end

local function utResolveStoreAssetPath(rawPath, xmlBaseDir)
    if rawPath == nil or rawPath == "" then
        return nil
    end

    local normalized = tostring(rawPath):gsub("\\", "/")
    normalized = utSafeReplace(normalized, "%$moddir%$", utResolveModDir())
    normalized = utSafeReplace(normalized, "%$mapdir%$", utGetMapDir())

    if normalized:sub(1, 6) == "$data/" then
        return normalized
    end

    if utIsAbsolutePath(normalized) then
        return normalized
    end

    if normalized:sub(1, 4) == "map/" or normalized:sub(1, 11) == "placeables/" then
        return Utils.getFilename(normalized, utGetMapDir())
    end

    return Utils.getFilename(normalized, xmlBaseDir or utResolveModDir())
end

local function utResolveNodeObject(nodeId)
    if g_currentMission == nil or nodeId == nil then
        return nil
    end

    local currentNode = nodeId
    while currentNode ~= nil and currentNode ~= 0 do
        local object = g_currentMission.nodeToObject[currentNode]
        if object ~= nil then
            return object
        end

        if getParent == nil then
            break
        end

        currentNode = getParent(currentNode)
    end

    return nil
end

local function utIsPlayerActor(otherActorId, otherShapeId)
    local mission = g_currentMission
    if mission == nil then
        return false
    end

    local player = mission.player
    local localPlayer = g_localPlayer

    if player ~= nil and (otherActorId == player.rootNode or otherShapeId == player.rootNode) then
        return true
    end

    if localPlayer ~= nil and (otherActorId == localPlayer.rootNode or otherShapeId == localPlayer.rootNode) then
        return true
    end

    local objectFromShape = utResolveNodeObject(otherShapeId)
    local objectFromActor = utResolveNodeObject(otherActorId)

    return objectFromShape == player or objectFromShape == localPlayer or objectFromActor == player or objectFromActor == localPlayer
end

local function utGetFarmId()
    if g_currentMission == nil then
        return AccessHandler.EVERYONE
    end

    if g_currentMission.missionDynamicInfo ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer and g_localPlayer ~= nil then
        return g_localPlayer:getFarmId()
    end

    if g_currentMission.getFarmId ~= nil then
        local farmId = g_currentMission:getFarmId()
        if farmId ~= nil then
            return farmId
        end
    end

    return FarmManager.SINGLEPLAYER_FARM_ID or 1
end

local function utGetFarm()
    local farmId = utGetFarmId()
    if g_farmManager ~= nil and farmId ~= nil then
        return g_farmManager:getFarmById(farmId), farmId
    end

    return nil, farmId
end

local function utShowInfo(text)
    if g_currentMission ~= nil and g_currentMission.addIngameNotification ~= nil then
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, tostring(text))
        return
    end

    if g_gui ~= nil and g_gui.showInfoDialog ~= nil then
        g_gui:showInfoDialog({text = tostring(text)})
        return
    end

    utLog("INFO: " .. tostring(text))
end

local function utResolveUpgradeFailReasonKey(reasonCode)
    local reasonToKey = {
        ["precheck_no_spawn_entries"] = "ui_upgradeReason_noSpawnEntries",
        ["precheck_no_buy_api"] = "ui_upgradeReason_noBuyApi",
        ["precheck_missing_xml"] = "ui_upgradeReason_missingXml",
        ["precheck_unresolved_xml"] = "ui_upgradeReason_unresolvedXml",
        ["precheck_missing_file"] = "ui_upgradeReason_missingFile",
        ["precheck_store_item_not_found"] = "ui_upgradeReason_storeItemNotFound",
        ["precheck_missing_icon"] = "ui_upgradeReason_missingIcon",
        ["missing xmlFilename"] = "ui_upgradeReason_missingXml",
        ["no placeableSystem"] = "ui_upgradeReason_noPlaceableSystem",
        ["store item not found"] = "ui_upgradeReason_storeItemNotFound",
        ["BuyPlaceableData API unavailable"] = "ui_upgradeReason_noBuyApi",
        ["BuyPlaceableData.new failed"] = "ui_upgradeReason_buyInitFailed",
        ["buy call failed"] = "ui_upgradeReason_buyCallFailed",
        ["buy returned false"] = "ui_upgradeReason_buyReturnedFalse",
        ["buy callback reported failure"] = "ui_upgradeReason_buyCallbackFailed"
    }

    return reasonToKey[reasonCode] or "ui_upgradeReason_unknown"
end

local function utBuildUpgradeFailMessage(reasonCode, detail)
    local title = utTryGetText("ui_upgradeImpossibleTitle") or "Модернизация предприятия невозможна"
    local reasonLabel = utTryGetText("ui_upgradeImpossibleReasonLabel") or "Причина"

    local reasonKey = utResolveUpgradeFailReasonKey(reasonCode)
    local reasonText = utTryGetText(reasonKey) or tostring(reasonCode or "")

    if detail ~= nil and detail ~= "" then
        reasonText = reasonText .. " (" .. tostring(detail) .. ")"
    end

    return string.format("%s\n%s: %s", tostring(title), tostring(reasonLabel), tostring(reasonText))
end

local function utShowYesNo(text, callback, target, args)
    local function forwardYesNo(...)
        if callback == nil then
            return
        end

        local resolvedYes = nil
        local count = select("#", ...)

        for i = 1, count do
            local value = select(i, ...)
            if type(value) == "boolean" then
                resolvedYes = value
                break
            end
        end

        if resolvedYes == nil then
            resolvedYes = false
        end

        callback(target, resolvedYes, args)
    end

    if g_gui ~= nil and g_gui.showYesNoDialog ~= nil then
        g_gui:showYesNoDialog({
            text = tostring(text),
            callback = forwardYesNo
        })
        return
    end

    if YesNoDialog ~= nil and YesNoDialog.show ~= nil then
        YesNoDialog.show(forwardYesNo, target, tostring(text))
        return
    end

    if callback ~= nil then
        callback(target, true, args)
    end
end

local function utNodeLooksLikeTrigger(nodeId)
    if nodeId == nil or nodeId == 0 then
        return false
    end

    local name = string.lower(utNodeName(nodeId))
    if name == "ut_playertrigger" or name == "upgradetrigger" or name == "playertrigger" or name == "interactiontrigger" then
        return true
    end
    if string.find(name, "trigger", 1, true) ~= nil then
        return true
    end
    if string.find(name, "col", 1, true) ~= nil then
        return true
    end
    if string.find(name, "interaction", 1, true) ~= nil then
        return true
    end
    return false
end

local function utFindTriggerNode(rootNode)
    if rootNode == nil or rootNode == 0 then
        return nil
    end

    local exactNames = {
        "ut_playerTrigger",
        "upgradeTrigger",
        "playerTrigger",
        "interactionTrigger",
        "gs_playerTrigger"
    }

    for _, wantedName in ipairs(exactNames) do
        local found = utFindChildByName(rootNode, wantedName)
        if found ~= nil then
            return found
        end
    end

    if utNodeLooksLikeTrigger(rootNode) then
        return rootNode
    end

    if getNumOfChildren == nil or getChildAt == nil then
        return rootNode
    end

    local queue = {rootNode}
    local qIndex = 1

    while qIndex <= #queue do
        local current = queue[qIndex]
        qIndex = qIndex + 1

        if current ~= rootNode and utNodeLooksLikeTrigger(current) then
            return current
        end

        local count = getNumOfChildren(current)
        for i = 0, count - 1 do
            table.insert(queue, getChildAt(current, i))
        end
    end

    return rootNode
end

local function utRegisterOnCreateAliases()
    local modName = g_currentModName or UT_STATIC_MOD_NAME or UpgradeTrigger.MOD_NAME

    if modName ~= nil and modName ~= "" then
        _G[modName] = _G[modName] or {}
        _G[modName].UpgradeTrigger_onCreate = UpgradeTrigger_onCreate
    end

    _G.modOnCreate = _G.modOnCreate or {}
    _G.modOnCreate.UpgradeTrigger_onCreate = UpgradeTrigger_onCreate

    UpgradeTrigger.onCreate = UpgradeTrigger_onCreate
    utExposeGlobal("UpgradeTrigger_onCreate", UpgradeTrigger_onCreate)
end

local function utGetPlaceableUniqueId(placeable)
    if placeable == nil then
        return nil
    end

    if placeable.getUniqueId ~= nil then
        local uniqueId = placeable:getUniqueId()
        if uniqueId ~= nil and uniqueId ~= "" then
            return tostring(uniqueId)
        end
    end

    if placeable.uniqueId ~= nil and placeable.uniqueId ~= "" then
        return tostring(placeable.uniqueId)
    end

    return nil
end

local function utRotateOffset(offsetX, offsetZ, yaw)
    local cosYaw = math.cos(yaw or 0)
    local sinYaw = math.sin(yaw or 0)
    local worldX = (offsetX or 0) * cosYaw - (offsetZ or 0) * sinYaw
    local worldZ = (offsetX or 0) * sinYaw + (offsetZ or 0) * cosYaw

    return worldX, worldZ
end

local function utGetPlaceableConfigFilename(placeable)
    if placeable == nil then
        return nil
    end

    if placeable.configFileName ~= nil and placeable.configFileName ~= "" then
        return placeable.configFileName
    end

    if placeable.xmlFilename ~= nil and placeable.xmlFilename ~= "" then
        return placeable.xmlFilename
    end

    if placeable.filename ~= nil and placeable.filename ~= "" then
        return placeable.filename
    end

    return nil
end

local function utBuildPlaceableFallbackInfo(placeable)
    local storeItem = nil

    if placeable ~= nil then
        if placeable.getStoreItem ~= nil then
            storeItem = placeable:getStoreItem()
        else
            storeItem = placeable.storeItem
        end
    end

    local title = nil
    if placeable ~= nil and placeable.getName ~= nil then
        title = placeable:getName()
    end

    local description = nil
    if storeItem ~= nil then
        description = storeItem.description or storeItem.name
    end

    local imageFilename = nil
    if storeItem ~= nil then
        imageFilename = storeItem.imageFilename or storeItem.image or storeItem.iconFilename
    end

    return {
        name = title,
        enterpriseDescription = description,
        imageFilename = imageFilename
    }
end

local function utNormalizeComparablePath(path)
    if path == nil or path == "" then
        return nil
    end
    return tostring(path):gsub("\\", "/"):lower()
end

local function utNormalizePath(path)
    if path == nil or path == "" then
        return nil
    end
    return tostring(path):gsub("\\", "/")
end

local function utIsImageAbsolutePath(path)
    if path == nil or path == "" then
        return false
    end

    local normalized = utNormalizePath(path)
    return normalized:match("^[A-Za-z]:/") ~= nil or normalized:sub(1, 1) == "/"
end

local function utResolveImagePath(path, baseDir)
    local normalized = utNormalizePath(path)
    if normalized == nil or normalized == "" then
        return nil
    end

    if utIsImageAbsolutePath(normalized) then
        return normalized
    end

    if baseDir == nil or baseDir == "" or Utils == nil or Utils.getFilename == nil then
        return normalized
    end

    local resolved = Utils.getFilename(normalized, baseDir)
    if resolved ~= nil and resolved ~= "" then
        resolved = utNormalizePath(resolved)
    end
    return resolved
end

local function utResolveStoreItemByXmlFilename(targetFilename)
    if g_storeManager == nil or targetFilename == nil or targetFilename == "" then
        return nil
    end

    local directLookups = {
        g_storeManager.getItemByXMLFilename,
        g_storeManager.getItemByXmlFilename,
        g_storeManager.getItemByFilename
    }

    for _, lookupFn in ipairs(directLookups) do
        if type(lookupFn) == "function" then
            local ok, item = pcall(lookupFn, g_storeManager, targetFilename)
            if ok and item ~= nil then
                return item
            end
        end
    end

    local targetNormalized = utNormalizeComparablePath(targetFilename)
    if targetNormalized == nil then
        return nil
    end

    local targetBasename = targetNormalized:match("([^/]+)$")
    for _, storeItem in pairs(g_storeManager.items or {}) do
        local candidatePaths = {
            storeItem ~= nil and storeItem.xmlFilename or nil,
            storeItem ~= nil and storeItem.filename or nil,
            storeItem ~= nil and storeItem.configFileName or nil
        }

        for _, candidate in ipairs(candidatePaths) do
            local candidateNormalized = utNormalizeComparablePath(candidate)
            if candidateNormalized ~= nil and (candidateNormalized == targetNormalized or candidateNormalized:match("([^/]+)$") == targetBasename) then
                return storeItem
            end
        end
    end

    return nil
end

local function utLoadPlaceableInfo(configFilename)
    if configFilename == nil or configFilename == "" then
        return nil
    end

    local resolvedFilename = utResolveConfigPath(configFilename, utGetMapDir()) or configFilename
    if resolvedFilename == nil or resolvedFilename == "" then
        return nil
    end

    local xmlFile = nil
    if loadXMLFile ~= nil then
        xmlFile = loadXMLFile("upgradePlaceableInfo", resolvedFilename)
    end

    if xmlFile == nil or xmlFile == 0 then
        utWarn("Не удалось открыть XML предприятия: " .. tostring(resolvedFilename))
        return nil
    end

    utLog("utLoadPlaceableInfo: reading '" .. tostring(resolvedFilename) .. "'")

    local storeName = getXMLString(xmlFile, "placeable.storeData.name")
    local storeImage = getXMLString(xmlFile, "placeable.storeData.image")
    local storeFunction = getXMLString(xmlFile, "placeable.storeData.functions.function")

    if (storeFunction == nil or storeFunction == "") and hasXMLProperty ~= nil and hasXMLProperty(xmlFile, "placeable.storeData.functions.function(0)") then
        storeFunction = getXMLString(xmlFile, "placeable.storeData.functions.function(0)")
    end

    delete(xmlFile)

    local storeItem = utResolveStoreItemByXmlFilename(resolvedFilename)
    local storeItemImage = storeItem ~= nil and (storeItem.imageFilename or storeItem.image or storeItem.iconFilename) or nil
    local imageFromStoreItem = storeItemImage ~= nil and storeItemImage ~= ""

    utLog(string.format(
        "utLoadPlaceableInfo store lookup: xml='%s' storeItemFound=%s storeItemImage='%s' fallbackStoreDataImage='%s'",
        tostring(resolvedFilename),
        tostring(storeItem ~= nil),
        tostring(storeItemImage),
        tostring(storeImage)
    ))

    local result = {
        xmlFilename = resolvedFilename,
        name = utResolveL10NText(storeName),
        imageFilename = imageFromStoreItem and storeItemImage or storeImage,
        enterpriseDescription = utResolveL10NText(storeFunction)
    }

    utLog(string.format(
        "utLoadPlaceableInfo result: xml='%s' name='%s' enterpriseDescription='%s' image='%s'",
        tostring(result.xmlFilename),
        tostring(result.name),
        tostring(result.enterpriseDescription),
        tostring(result.imageFilename)
    ))

    return result
end

local function utGetPlaceableOwnerFarmId(placeable)
    if placeable == nil then
        return nil
    end

    if placeable.getOwnerFarmId ~= nil then
        local farmId = placeable:getOwnerFarmId()
        if farmId ~= nil then
            return farmId
        end
    end

    return placeable.ownerFarmId
end

function UpgradeTrigger_onCreate(nodeId)
    local rawConfigPath = getUserAttribute(nodeId, "upgradeConfig")
    local actionTextRaw = getUserAttribute(nodeId, "actionText")
    if actionTextRaw == nil or actionTextRaw == "" then
        actionTextRaw = "$l10n_action_orderUpgrade"
    end
    local actionText = utResolveActionText(actionTextRaw)
    local triggerNode = utFindTriggerNode(nodeId)

    table.insert(g_upgradeTriggerOnCreateData, {
        rootNode = nodeId,
        nodeId = triggerNode,
        upgradeConfig = rawConfigPath,
        actionText = actionText
    })
end

utRegisterOnCreateAliases()

UpgradeTriggerManager = {}
local UpgradeTriggerManager_mt = Class(UpgradeTriggerManager)

function UpgradeTriggerManager.new(mission)
    local self = setmetatable({}, UpgradeTriggerManager_mt)

    self.mission = mission
    self.triggers = {}
    self.triggerByNode = {}
    self.playerTrigger = nil
    self.guiLoaded = false
    self.guiInstance = nil
    self.tempSpawnXmlFiles = {}

    return self
end

function UpgradeTriggerManager:delete()
    for _, trigger in ipairs(self.triggers) do
        if trigger.isRegistered then
            g_currentMission.activatableObjectsSystem:removeActivatable(trigger.activatable)
            trigger.isRegistered = false
        end

        if trigger.triggerNode ~= nil then
            utSafeRemoveTrigger(trigger.triggerNode)
            trigger.triggerNode = nil
        end

        if trigger.config ~= nil and trigger.config.xmlFile ~= nil then
            if type(trigger.config.xmlFile) == "table" and trigger.config.xmlFile.delete ~= nil then
                trigger.config.xmlFile:delete()
            else
                delete(trigger.config.xmlFile)
            end
            trigger.config.xmlFile = nil
        end
    end

    for _, xmlFile in ipairs(self.tempSpawnXmlFiles) do
        if xmlFile ~= nil and xmlFile.delete ~= nil then
            xmlFile:delete()
        end
    end

    self.tempSpawnXmlFiles = {}
    self.triggers = {}
    self.triggerByNode = {}
    self.playerTrigger = nil
end

function UpgradeTriggerManager:scanUpgradeNodesRecursive(nodeId, result)
    if nodeId == nil or nodeId == 0 then
        return
    end

    local rawConfigPath = getUserAttribute ~= nil and getUserAttribute(nodeId, "upgradeConfig") or nil
    if rawConfigPath ~= nil and rawConfigPath ~= "" then
        local actionText = getUserAttribute(nodeId, "actionText") or "$l10n_action_orderUpgrade"
        table.insert(result, {
            rootNode = nodeId,
            nodeId = utFindTriggerNode(nodeId),
            upgradeConfig = rawConfigPath,
            actionText = actionText
        })
    end

    if getNumOfChildren == nil or getChildAt == nil then
        return
    end

    local childCount = getNumOfChildren(nodeId)
    for i = 0, childCount - 1 do
        self:scanUpgradeNodesRecursive(getChildAt(nodeId, i), result)
    end
end

function UpgradeTriggerManager:discoverTriggersFromScene()
    local found = {}
    local rootNode = getRootNode ~= nil and getRootNode() or nil
    if rootNode ~= nil then
        self:scanUpgradeNodesRecursive(rootNode, found)
    end

    for _, data in ipairs(found) do
        if data.rootNode ~= nil and self.triggerByNode[data.nodeId] == nil then
            self:addTrigger(data.rootNode, data.nodeId, data.upgradeConfig, data.actionText)
        end
    end
end

function UpgradeTriggerManager:loadMap(mapNode, missionInfo, baseDirectory)
    for _, data in ipairs(g_upgradeTriggerOnCreateData) do
        if data.nodeId ~= nil and self.triggerByNode[data.nodeId] == nil then
            self:addTrigger(data.rootNode, data.nodeId, data.upgradeConfig, data.actionText)
        end
    end

    self:discoverTriggersFromScene()
end

function UpgradeTriggerManager:loadMapFinished()
    self:loadGUI()
end

function UpgradeTriggerManager:loadGUI()
    if self.guiLoaded then
        return true
    end

    if UpgradeGUI == nil or UpgradeGUI.register == nil then
        utError("UpgradeGUI.register is not available")
        return false
    end

    local ok, err = pcall(function()
        self.guiInstance = UpgradeGUI.register(UT_GUI_XML, self)
    end)

    if ok and UpgradeGUI ~= nil and UpgradeGUI.instance ~= nil then
        self.guiLoaded = true
        return true
    end

    if not ok then
        utError("UpgradeGUI.register failed: " .. tostring(err))
    else
        utError("UpgradeGUI.register returned without instance")
    end

    return false
end

function UpgradeTriggerManager:addTrigger(rootNode, triggerNode, rawConfigPath, actionText)
    if triggerNode == nil or triggerNode == 0 then
        utError("Cannot add trigger: invalid trigger node from root " .. tostring(rootNode))
        return nil
    end

    local configPath = utResolveConfigPath(rawConfigPath)
    local trigger = UpgradeTrigger.new(self, rootNode, triggerNode, configPath, actionText)
    table.insert(self.triggers, trigger)
    self.triggerByNode[triggerNode] = trigger

    local ok, err = pcall(function()
        addTrigger(triggerNode, "upgradeTriggerCallback", trigger)
    end)

    if not ok then
        utError("addTrigger FAILED for node=" .. tostring(triggerNode) .. ": " .. tostring(err))
    end

    return trigger
end

function UpgradeTriggerManager:openGUI(trigger)
    if trigger == nil then
        return
    end

    if trigger.ensureConfigLoaded ~= nil and not trigger:ensureConfigLoaded() then
        utWarn("Skipping GUI open because upgrade config failed to load for '" .. tostring(trigger.configPath) .. "'")
        return
    end

    if not self:loadGUI() then
        return
    end

    if UpgradeGUI == nil or UpgradeGUI.show == nil then
        utError("UpgradeGUI.show is not available")
        return
    end

    local ok, err = pcall(function()
        UpgradeGUI.show(trigger)
        self.guiInstance = UpgradeGUI.instance
    end)

    if not ok then
        utError("UpgradeGUI.show failed: " .. tostring(err))
    end
end

function UpgradeTriggerManager:collectFarmPlaceables(trigger, farmId)
    local result = {}

    if trigger ~= nil and trigger.ensureConfigLoaded ~= nil and not trigger:ensureConfigLoaded() then
        utWarn("collectFarmPlaceables aborted because config failed to load for '" .. tostring(trigger.configPath) .. "'")
        return result
    end

    local mission = g_currentMission
    if mission == nil or mission.placeableSystem == nil then
        return result
    end

    local placeables = mission.placeableSystem.placeables or {}

    for _, placeable in ipairs(placeables) do
        local ownerFarmId = utGetPlaceableOwnerFarmId(placeable)
        local uniqueId = utGetPlaceableUniqueId(placeable)
        local configFilename = utGetPlaceableConfigFilename(placeable)

        utLog(string.format(
            "collectFarmPlaceables candidate: placeable='%s' ownerFarmId=%s wantedFarmId=%s uniqueId='%s' configFilename='%s'",
            tostring(placeable ~= nil and (placeable.getName ~= nil and placeable:getName() or placeable.name) or ""),
            tostring(ownerFarmId),
            tostring(farmId),
            tostring(uniqueId),
            tostring(configFilename)
        ))

        if ownerFarmId == farmId and uniqueId ~= nil and configFilename ~= nil and configFilename ~= "" then
            local rowData = self:createPlaceableRow(trigger, placeable)
            if rowData ~= nil and rowData.canUpgrade == true and rowData.config ~= nil then
                utLog(string.format(
                    "collectFarmPlaceables accepted: uniqueId='%s' title='%s' enterpriseDescription='%s' image='%s' canUpgrade=%s",
                    tostring(rowData.uniqueId),
                    tostring(rowData.title),
                    tostring(rowData.enterpriseDescription),
                    tostring(rowData.imageFilename),
                    tostring(rowData.canUpgrade)
                ))
                table.insert(result, rowData)
            elseif rowData ~= nil then
                utLog(string.format(
                    "collectFarmPlaceables skipped (no upgrade config): uniqueId='%s' title='%s' canUpgrade=%s",
                    tostring(rowData.uniqueId),
                    tostring(rowData.title),
                    tostring(rowData.canUpgrade)
                ))
            end
        end
    end

    table.sort(result, function(a, b)
        return tostring(a.sortTitle or ""):lower() < tostring(b.sortTitle or ""):lower()
    end)

    return result
end

function UpgradeTriggerManager:createPlaceableRow(trigger, placeable)
    if placeable == nil then
        return nil
    end

    local uniqueId = utGetPlaceableUniqueId(placeable)
    local configFilename = utGetPlaceableConfigFilename(placeable)
    local placeableInfo = utLoadPlaceableInfo(configFilename) or {}
    local fallbackInfo = utBuildPlaceableFallbackInfo(placeable)
    local rowStoreItem = utResolveStoreItemByXmlFilename(configFilename)
    local config = self:findUpgradeConfigForPlaceable(trigger, placeable)

    utLog(string.format(
        "createPlaceableRow source: placeable='%s' uniqueId='%s' configFilename='%s' fallbackName='%s' fallbackDescription='%s' fallbackImage='%s' upgradeFound=%s",
        tostring(placeable ~= nil and (placeable.getName ~= nil and placeable:getName() or placeable.name) or ""),
        tostring(uniqueId),
        tostring(configFilename),
        tostring(fallbackInfo.name),
        tostring(fallbackInfo.enterpriseDescription),
        tostring(fallbackInfo.imageFilename),
        tostring(config ~= nil)
    ))

    local title = placeableInfo.name
    if title == nil or title == "" then
        title = fallbackInfo.name
    end
    if title == nil or title == "" then
        title = utGetPlaceableUniqueId(placeable) or "Предприятие"
    end

    local enterpriseDescription = placeableInfo.enterpriseDescription
    if enterpriseDescription == nil or enterpriseDescription == "" then
        enterpriseDescription = fallbackInfo.enterpriseDescription or ""
    end

    local sourceImageFilename = rowStoreItem ~= nil and rowStoreItem.imageFilename or nil
    local imageBaseDir = nil
    if rowStoreItem ~= nil then
        local storeItemXmlFilename = rowStoreItem.xmlFilename or rowStoreItem.filename or rowStoreItem.configFileName
        if storeItemXmlFilename ~= nil and storeItemXmlFilename ~= "" and Utils ~= nil and Utils.getDirectory ~= nil then
            imageBaseDir = Utils.getDirectory(storeItemXmlFilename)
        end
    end
    if (imageBaseDir == nil or imageBaseDir == "") and configFilename ~= nil and configFilename ~= "" and Utils ~= nil and Utils.getDirectory ~= nil then
        imageBaseDir = Utils.getDirectory(configFilename)
    end

    local imageFilename = utResolveImagePath(sourceImageFilename, imageBaseDir)
    local sourceIsAbsolute = utIsImageAbsolutePath(sourceImageFilename)

    utLog(string.format(
        "createPlaceableRow icon source: uniqueId='%s' configFile='%s' storeItemFound=%s storeItemXml='%s' sourceImage='%s' baseDir='%s' resolvedImage='%s' isAbsolute=%s",
        tostring(uniqueId),
        tostring(configFilename),
        tostring(rowStoreItem ~= nil),
        tostring(rowStoreItem ~= nil and (rowStoreItem.xmlFilename or rowStoreItem.filename or rowStoreItem.configFileName) or ""),
        tostring(sourceImageFilename),
        tostring(imageBaseDir),
        tostring(imageFilename),
        tostring(sourceIsAbsolute)
    ))

    local rowData = {
        placeable = placeable,
        storeItem = rowStoreItem,
        config = config,
        uniqueId = uniqueId,
        title = title,
        name = title,
        sortTitle = title,
        description = enterpriseDescription,
        enterpriseDescription = enterpriseDescription,
        imageFilename = imageFilename,
        price = config ~= nil and (tonumber(config.price) or 0) or 0,
        canUpgrade = config ~= nil,
        buttonText = utTryGetText("button_upgrade") or "Улучшить"
    }

    utLog(string.format(
        "createPlaceableRow result: uniqueId='%s' title='%s' enterpriseDescription='%s' image='%s' price=%s canUpgrade=%s",
        tostring(rowData.uniqueId),
        tostring(rowData.title),
        tostring(rowData.enterpriseDescription),
        tostring(rowData.imageFilename),
        tostring(rowData.price),
        tostring(rowData.canUpgrade)
    ))

    return rowData
end

function UpgradeTriggerManager:findUpgradeConfigForPlaceable(trigger, placeable)
    if trigger == nil or trigger.config == nil or trigger.config.upgrades == nil or placeable == nil then
        return nil
    end

    local uniqueId = utGetPlaceableUniqueId(placeable)
    if uniqueId == nil then
        return nil
    end

    for _, upgrade in ipairs(trigger.config.upgrades) do
        if upgrade.sourceUniqueId ~= nil and tostring(upgrade.sourceUniqueId) == tostring(uniqueId) then
            utLog("findUpgradeConfigForPlaceable: matched uniqueId='" .. tostring(uniqueId) .. "' title='" .. tostring(upgrade.title) .. "'")
            return upgrade
        end
    end

    utLog("findUpgradeConfigForPlaceable: no upgrade config for uniqueId='" .. tostring(uniqueId) .. "'")
    return nil
end

function UpgradeTriggerManager:onUpgradeButtonPressed(rowData)
    if rowData == nil or rowData.placeable == nil or rowData.config == nil then
        utWarn("onUpgradeButtonPressed called with incomplete rowData")
        return
    end

    local priceValue = tonumber(rowData.price) or 0
    local displayPriceText = utFormatDisplayMoney(priceValue)
    local titleText = tostring(rowData.title or "")
    local pattern = utTryGetText("ui_upgradeConfirm") or "Заплатить %s за улучшение %s?"

    local ok, text = pcall(string.format, pattern, displayPriceText, titleText)
    if not ok then
        ok, text = pcall(string.format, pattern, titleText, displayPriceText)
    end
    if not ok then
        text = string.format("Заплатить %s за улучшение %s?", displayPriceText, titleText)
    end

    utLog(string.format(
        "onUpgradeButtonPressed confirm: pattern='%s' rawPrice=%s displayPrice='%s' title='%s' finalText='%s'",
        tostring(pattern),
        tostring(priceValue),
        tostring(displayPriceText),
        tostring(titleText),
        tostring(text)
    ))

    utShowYesNo(text, self.onUpgradeDialogCallback, self, rowData)
end

function UpgradeTriggerManager:onUpgradeDialogCallback(rawA, rawB, rawC)
    local resolvedYes = nil
    local rowData = nil

    local values = {rawA, rawB, rawC}
    for _, value in ipairs(values) do
        if resolvedYes == nil and type(value) == "boolean" then
            resolvedYes = value
        elseif rowData == nil and type(value) == "table" and (value.placeable ~= nil or value.config ~= nil or value.title ~= nil) then
            rowData = value
        end
    end

    if resolvedYes == nil then
        resolvedYes = false
    end

    utLog(string.format(
        "onUpgradeDialogCallback: rawA=%s rawB=%s rawC=%s resolvedYes=%s rowDataTitle='%s'",
        tostring(rawA),
        tostring(rawB),
        tostring(rawC),
        tostring(resolvedYes),
        tostring(rowData ~= nil and rowData.title or "")
    ))

    if resolvedYes ~= true or rowData == nil then
        utWarn("onUpgradeDialogCallback aborted: confirmation not accepted or rowData missing")
        return
    end

    local function runUpgradeTask()
        utLog("onUpgradeDialogCallback: queued upgrade task started")
        local started = self:performUpgrade(rowData.placeable, rowData.config, function(success)
            utLog("onUpgradeDialogCallback: upgrade chain finished success=" .. tostring(success))
            if success and self.guiInstance ~= nil and self.guiInstance.close ~= nil then
                self.guiInstance:close()
            end
        end)
        utLog("onUpgradeDialogCallback: queued upgrade task startedFlow=" .. tostring(started))
    end

    if g_asyncTaskManager ~= nil and g_asyncTaskManager.addTask ~= nil then
        g_asyncTaskManager:addTask(runUpgradeTask)
    else
        runUpgradeTask()
    end
end

function UpgradeTriggerManager:precheckUpgradeSpawnConfigs(config)
    local spawnConfigs = config ~= nil and (config.spawns or config.spawn) or nil
    if type(spawnConfigs) ~= "table" or #spawnConfigs == 0 then
        return false, "precheck_no_spawn_entries", nil
    end

    if BuyPlaceableData == nil or BuyPlaceableData.new == nil then
        return false, "precheck_no_buy_api", nil
    end

    for index, spawnData in ipairs(spawnConfigs) do
        if spawnData == nil or spawnData.xmlFilename == nil or spawnData.xmlFilename == "" then
            return false, "precheck_missing_xml", tostring(index)
        end

        local xmlFilename = utResolveConfigPath(spawnData.xmlFilename, utGetMapDir())
        if xmlFilename == nil or xmlFilename == "" then
            return false, "precheck_unresolved_xml", tostring(index)
        end

        if fileExists ~= nil and not fileExists(xmlFilename) then
            return false, "precheck_missing_file", tostring(xmlFilename)
        end

        local storeItem = utResolveStoreItemByXmlFilename(xmlFilename)
        if storeItem == nil then
            return false, "precheck_store_item_not_found", tostring(xmlFilename)
        end

        local imageFilename = storeItem.imageFilename or storeItem.image or storeItem.iconFilename
        if imageFilename == nil or imageFilename == "" then
            return false, "precheck_missing_icon", tostring(xmlFilename)
        end
    end

    return true, nil, nil
end

function UpgradeTriggerManager:performUpgrade(sourcePlaceable, config, onFinished)
    utLog(string.format(
        "performUpgrade start: sourceUniqueId='%s' targetTitle='%s' price=%s",
        tostring(sourcePlaceable ~= nil and utGetPlaceableUniqueId(sourcePlaceable) or ""),
        tostring(config ~= nil and config.title or ""),
        tostring(config ~= nil and config.price or "")
    ))

    if sourcePlaceable == nil or config == nil then
        utError("performUpgrade missing sourcePlaceable or config")
        return false
    end

    local farm, farmId = utGetFarm()
    local price = math.max(0, tonumber(config.price) or 0)
    local money = farm ~= nil and farm.money or 0
    local placeableSystem = g_currentMission ~= nil and g_currentMission.placeableSystem or nil

    if placeableSystem == nil then
        utError("performUpgrade aborted: placeableSystem unavailable")
        return false
    end

    if money < price then
        utWarn(string.format("performUpgrade aborted: not enough money money=%s price=%s", tostring(money), tostring(price)))
        utShowInfo(g_i18n ~= nil and g_i18n:getText("shop_messageNotEnoughMoney") or "Недостаточно денег")
        return false
    end

    local rootNode = sourcePlaceable.rootNode or sourcePlaceable.nodeId
    if rootNode == nil then
        utError("performUpgrade aborted: source placeable has no root node")
        return false
    end

    local worldX, worldY, worldZ = getWorldTranslation(rootNode)
    local rotX, rotY, rotZ = getWorldRotation(rootNode)
    local sourceXmlFilename = utGetPlaceableConfigFilename(sourcePlaceable)

    local spawnConfigs = config.spawns or config.spawn or {}
    if type(spawnConfigs) ~= "table" or #spawnConfigs == 0 then
        utError("performUpgrade aborted: no spawn entries for sourceUniqueId='" .. tostring(config.sourceUniqueId) .. "'")
        return false
    end

    local precheckOk, precheckReasonCode, precheckDetail = self:precheckUpgradeSpawnConfigs(config)
    if precheckOk ~= true then
        utWarn("performUpgrade aborted by precheck: code=" .. tostring(precheckReasonCode) .. " detail=" .. tostring(precheckDetail))
        utShowInfo(utBuildUpgradeFailMessage(precheckReasonCode, precheckDetail))
        return false
    end

    if price > 0 then
        local balanceBefore = farm ~= nil and (farm.getBalance ~= nil and farm:getBalance() or farm.money) or 0
        utLog(string.format("performUpgrade deductMoney start: farmId=%s amount=%s balanceBefore=%s", tostring(farmId), tostring(price), tostring(balanceBefore)))

        if g_currentMission ~= nil and g_currentMission.addMoney ~= nil then
            g_currentMission:addMoney(-price, farmId, MoneyType.OTHER, true)
        elseif farm ~= nil and farm.changeBalance ~= nil then
            farm:changeBalance(-price, MoneyType.OTHER)
        else
            utWarn("performUpgrade deductMoney fallback missing: no supported FS25 money API found")
        end

        local farmAfterMoney = g_farmManager ~= nil and farmId ~= nil and g_farmManager:getFarmById(farmId) or farm
        local balanceAfter = farmAfterMoney ~= nil and (farmAfterMoney.getBalance ~= nil and farmAfterMoney:getBalance() or farmAfterMoney.money) or nil
        utLog(string.format("performUpgrade deductMoney done: farmId=%s balanceAfter=%s", tostring(farmId), tostring(balanceAfter)))
    end

    local rollbackData = {
        xmlFilename = sourceXmlFilename,
        x = worldX,
        y = worldY,
        z = worldZ,
        rx = rotX,
        ry = rotY,
        rz = rotZ,
        farmId = farmId,
        price = price
    }
    local rollbackExecuted = false

    utLog("performUpgrade deleting source placeable uniqueId='" .. tostring(utGetPlaceableUniqueId(sourcePlaceable)) .. "'")
    sourcePlaceable:delete(true)

    self:startSpawnChain(spawnConfigs, farmId, worldX, worldY, worldZ, rotX, rotY, rotZ, function(success, reason)
        if success then
            utLog("performUpgrade finished successfully: spawn chain completed")
            utShowInfo(g_i18n ~= nil and g_i18n:getText("ui_upgradeDone") or "Улучшение выполнено")
        else
            utWarn("performUpgrade aborted: spawn chain failed reason=" .. tostring(reason))
            if not rollbackExecuted then
                rollbackExecuted = true
                self:rollbackUpgrade(rollbackData)
            end
            utShowInfo(utBuildUpgradeFailMessage(reason, nil))
        end

        if onFinished ~= nil then
            onFinished(success)
        end
    end)

    return true
end

function UpgradeTriggerManager:rollbackUpgrade(rollbackData)
    utLog("ROLLBACK START")

    if rollbackData == nil then
        utError("rollback failed: rollbackData is nil")
        return
    end

    local farmId = rollbackData.farmId
    local price = math.max(0, tonumber(rollbackData.price) or 0)
    local xmlFilename = rollbackData.xmlFilename

    if price > 0 then
        utLog(string.format("ROLLBACK MONEY REFUND farmId=%s amount=%s", tostring(farmId), tostring(price)))
        if g_currentMission ~= nil and g_currentMission.addMoney ~= nil then
            g_currentMission:addMoney(price, farmId, MoneyType.OTHER, true)
        else
            utError("rollback failed: mission.addMoney unavailable")
        end
    else
        utLog("ROLLBACK MONEY REFUND skipped: price <= 0")
    end

    utLog(string.format("ROLLBACK RESTORE PLACEABLE xmlFilename='%s'", tostring(xmlFilename)))

    local function normalizeComparablePath(path)
        if path == nil or path == "" then
            return nil
        end
        return tostring(path):gsub("\\", "/"):lower()
    end

    local function resolveStoreItemByXmlFilename(targetFilename)
        if g_storeManager == nil or targetFilename == nil or targetFilename == "" then
            return nil
        end

        local directLookups = {
            g_storeManager.getItemByXMLFilename,
            g_storeManager.getItemByXmlFilename,
            g_storeManager.getItemByFilename
        }

        for _, lookupFn in ipairs(directLookups) do
            if type(lookupFn) == "function" then
                local ok, item = pcall(lookupFn, g_storeManager, targetFilename)
                if ok and item ~= nil then
                    return item
                end
            end
        end

        local targetNormalized = normalizeComparablePath(targetFilename)
        if targetNormalized == nil then
            return nil
        end

        local targetBasename = targetNormalized:match("([^/]+)$")
        for _, storeItem in pairs(g_storeManager.items or {}) do
            local candidatePaths = {
                storeItem ~= nil and storeItem.xmlFilename or nil,
                storeItem ~= nil and storeItem.filename or nil,
                storeItem ~= nil and storeItem.configFileName or nil
            }

            for _, candidate in ipairs(candidatePaths) do
                local candidateNormalized = normalizeComparablePath(candidate)
                if candidateNormalized ~= nil and (candidateNormalized == targetNormalized or candidateNormalized:match("([^/]+)$") == targetBasename) then
                    return storeItem
                end
            end
        end

        return nil
    end

    if xmlFilename == nil or xmlFilename == "" then
        utError("rollback failed: source xmlFilename is missing")
        utLog("ROLLBACK FINISHED")
        return
    end

    local resolvedXmlFilename = utResolveConfigPath(xmlFilename, utGetMapDir()) or xmlFilename
    local storeItem = resolveStoreItemByXmlFilename(resolvedXmlFilename)
    if storeItem == nil then
        utError("rollback failed: store item not found for xml '" .. tostring(resolvedXmlFilename) .. "'")
        utLog("ROLLBACK FINISHED")
        return
    end

    if BuyPlaceableData == nil or BuyPlaceableData.new == nil then
        utError("rollback failed: BuyPlaceableData API unavailable")
        utLog("ROLLBACK FINISHED")
        return
    end

    local buyData = BuyPlaceableData.new()
    if buyData == nil then
        utError("rollback failed: BuyPlaceableData.new returned nil")
        utLog("ROLLBACK FINISHED")
        return
    end

    if buyData.setStoreItem ~= nil then
        buyData:setStoreItem(storeItem)
    end
    if buyData.setOwnerFarmId ~= nil then
        buyData:setOwnerFarmId(farmId)
    elseif buyData.setFarmId ~= nil then
        buyData:setFarmId(farmId)
    end
    if buyData.setPosition ~= nil then
        buyData:setPosition(rollbackData.x, rollbackData.y, rollbackData.z)
    end
    if buyData.setRotation ~= nil then
        buyData:setRotation(rollbackData.rx, rollbackData.ry, rollbackData.rz)
    end
    if buyData.setModifyTerrain ~= nil then
        buyData:setModifyTerrain(true)
    end
    if buyData.setRealignToTerrainAfterLeveling ~= nil then
        buyData:setRealignToTerrainAfterLeveling(true)
    end

    local callbackHandled = false
    local function rollbackBuyCallback(...)
        if callbackHandled then
            return
        end
        callbackHandled = true

        local callbackArgs = {...}
        local callbackSuccess = nil
        local callbackPlaceable = nil

        for _, value in ipairs(callbackArgs) do
            if callbackSuccess == nil and type(value) == "boolean" then
                callbackSuccess = value
            end
            if callbackPlaceable == nil and type(value) == "table" and value.rootNode ~= nil then
                callbackPlaceable = value
            end
        end

        local resolvedSuccess = callbackSuccess
        if resolvedSuccess == nil then
            resolvedSuccess = callbackPlaceable ~= nil
        end

        if resolvedSuccess == true then
            utLog("ROLLBACK SUCCESS")
        else
            utError("rollback failed: restore buy callback reported failure")
        end
        utLog("ROLLBACK FINISHED")
    end

    local buyOk, buyResultOrErr = pcall(function()
        if buyData.buy ~= nil then
            return buyData:buy(rollbackBuyCallback, self)
        end
        return nil
    end)

    if not buyOk then
        utError("rollback failed: BuyPlaceableData:buy exception: " .. tostring(buyResultOrErr))
        utLog("ROLLBACK FINISHED")
        return
    end

    if buyResultOrErr == false then
        utError("rollback failed: BuyPlaceableData:buy returned false")
        utLog("ROLLBACK FINISHED")
        return
    end

    utLog("ROLLBACK RESTORE PLACEABLE queued")
end

function UpgradeTriggerManager:startSpawnChain(spawnConfigs, farmId, baseX, baseY, baseZ, baseRotX, baseRotY, baseRotZ, onFinished)
    local total = type(spawnConfigs) == "table" and #spawnConfigs or 0
    utLog(string.format("spawnChain start: total=%d farmId=%s", total, tostring(farmId)))

    if total == 0 then
        utWarn("spawnChain aborted: empty spawn config list")
        if onFinished ~= nil then
            onFinished(false, "precheck_no_spawn_entries")
        end
        return
    end

    local function finishChain(success, reason)
        if onFinished ~= nil then
            onFinished(success == true, reason)
        end
    end

    self:spawnNextInChain(spawnConfigs, 1, farmId, baseX, baseY, baseZ, baseRotX, baseRotY, baseRotZ, finishChain)
end

function UpgradeTriggerManager:spawnNextInChain(spawnConfigs, index, farmId, baseX, baseY, baseZ, baseRotX, baseRotY, baseRotZ, onFinished)
    local total = #spawnConfigs
    if index > total then
        utLog(string.format("spawnChain success finished: total=%d", total))
        if onFinished ~= nil then
            onFinished(true, nil)
        end
        return
    end

    local spawnData = spawnConfigs[index]
    utLog(string.format(
        "spawnChain step start: index=%d/%d xmlFilename='%s' uniqueId='%s'",
        index,
        total,
        tostring(spawnData ~= nil and spawnData.xmlFilename or ""),
        tostring(spawnData ~= nil and spawnData.uniqueId or "")
    ))

    self:spawnUpgradePlaceable(spawnData, farmId, baseX, baseY, baseZ, baseRotX, baseRotY, baseRotZ, function(success, reason)
        utLog(string.format(
            "spawnChain step callback: index=%d/%d success=%s xmlFilename='%s' uniqueId='%s' reason='%s'",
            index,
            total,
            tostring(success),
            tostring(spawnData ~= nil and spawnData.xmlFilename or ""),
            tostring(spawnData ~= nil and spawnData.uniqueId or ""),
            tostring(reason or "")
        ))

        if success ~= true then
            utError(string.format(
                "spawnChain aborted: step=%d/%d xmlFilename='%s' uniqueId='%s' reason='%s'",
                index,
                total,
                tostring(spawnData ~= nil and spawnData.xmlFilename or ""),
                tostring(spawnData ~= nil and spawnData.uniqueId or ""),
                tostring(reason or "unknown")
            ))
            if onFinished ~= nil then
                onFinished(false, reason or "unknown")
            end
            return
        end

        utLog(string.format("spawnChain advance: nextStep=%d/%d", index + 1, total))
        self:spawnNextInChain(spawnConfigs, index + 1, farmId, baseX, baseY, baseZ, baseRotX, baseRotY, baseRotZ, onFinished)
    end, index, total)
end

function UpgradeTriggerManager:spawnUpgradePlaceable(spawnData, farmId, baseX, baseY, baseZ, baseRotX, baseRotY, baseRotZ, onCompleted, chainIndex, chainTotal)
    local completed = false
    local function finishSpawn(success, reason)
        if completed then
            return
        end
        completed = true
        if onCompleted ~= nil then
            onCompleted(success == true, reason)
        end
    end

    utLog(string.format(
        "spawnUpgradePlaceable start: step=%s/%s xmlFilename='%s' uniqueId='%s' farmId=%s",
        tostring(chainIndex or "?"),
        tostring(chainTotal or "?"),
        tostring(spawnData ~= nil and spawnData.xmlFilename or ""),
        tostring(spawnData ~= nil and spawnData.uniqueId or ""),
        tostring(farmId)
    ))

    if spawnData == nil or spawnData.xmlFilename == nil or spawnData.xmlFilename == "" then
        utError("Missing xmlFilename in upgrade spawn data")
        finishSpawn(false, "missing xmlFilename")
        return
    end

    local xmlFilename = utResolveConfigPath(spawnData.xmlFilename, utGetMapDir())
    local placeableSystem = g_currentMission ~= nil and g_currentMission.placeableSystem or nil
    if placeableSystem == nil then
        utError("No placeableSystem available for spawning")
        finishSpawn(false, "no placeableSystem")
        return
    end

    local offsetX = tonumber(spawnData.offsetX) or 0
    local offsetY = tonumber(spawnData.offsetY) or 0
    local offsetZ = tonumber(spawnData.offsetZ) or 0
    local worldOffsetX, worldOffsetZ = utRotateOffset(offsetX, offsetZ, baseRotY or 0)

    local x = (baseX or 0) + worldOffsetX
    local y = (baseY or 0) + offsetY
    local z = (baseZ or 0) + worldOffsetZ
    local rx = (baseRotX or 0) + math.rad(tonumber(spawnData.rotOffsetX) or 0)
    local ry = (baseRotY or 0) + math.rad(tonumber(spawnData.rotOffsetY) or 0)
    local rz = (baseRotZ or 0) + math.rad(tonumber(spawnData.rotOffsetZ) or 0)

    local function normalizeComparablePath(path)
        if path == nil or path == "" then
            return nil
        end
        return tostring(path):gsub("\\", "/"):lower()
    end

    local function resolveStoreItemByXmlFilename(targetFilename)
        if g_storeManager == nil or targetFilename == nil or targetFilename == "" then
            return nil
        end

        local directLookups = {
            g_storeManager.getItemByXMLFilename,
            g_storeManager.getItemByXmlFilename,
            g_storeManager.getItemByFilename
        }

        for _, lookupFn in ipairs(directLookups) do
            if type(lookupFn) == "function" then
                local ok, item = pcall(lookupFn, g_storeManager, targetFilename)
                if ok and item ~= nil then
                    return item
                end
            end
        end

        local targetNormalized = normalizeComparablePath(targetFilename)
        if targetNormalized == nil then
            return nil
        end

        local targetBasename = targetNormalized:match("([^/]+)$")
        for _, storeItem in pairs(g_storeManager.items or {}) do
            local candidatePaths = {
                storeItem ~= nil and storeItem.xmlFilename or nil,
                storeItem ~= nil and storeItem.filename or nil,
                storeItem ~= nil and storeItem.configFileName or nil
            }

            for _, candidate in ipairs(candidatePaths) do
                local candidateNormalized = normalizeComparablePath(candidate)
                if candidateNormalized ~= nil and (candidateNormalized == targetNormalized or candidateNormalized:match("([^/]+)$") == targetBasename) then
                    return storeItem
                end
            end
        end

        return nil
    end

    local storeItem = resolveStoreItemByXmlFilename(xmlFilename)
    if storeItem == nil then
        utError("spawnUpgradePlaceable: no store item for xml '" .. tostring(xmlFilename) .. "'")
        finishSpawn(false, "store item not found")
        return
    end

    if BuyPlaceableData == nil or BuyPlaceableData.new == nil then
        utError("spawnUpgradePlaceable: BuyPlaceableData API unavailable for xml '" .. tostring(xmlFilename) .. "'")
        finishSpawn(false, "BuyPlaceableData API unavailable")
        return
    end

    local buyData = BuyPlaceableData.new()
    if buyData == nil then
        utError("spawnUpgradePlaceable: BuyPlaceableData.new failed for xml '" .. tostring(xmlFilename) .. "'")
        finishSpawn(false, "BuyPlaceableData.new failed")
        return
    end

    if buyData.setStoreItem ~= nil then
        buyData:setStoreItem(storeItem)
    end
    if buyData.setOwnerFarmId ~= nil then
        buyData:setOwnerFarmId(farmId)
    elseif buyData.setFarmId ~= nil then
        buyData:setFarmId(farmId)
    end
    if buyData.setPosition ~= nil then
        buyData:setPosition(x, y, z)
    end
    if buyData.setRotation ~= nil then
        buyData:setRotation(rx, ry, rz)
    end
    if spawnData.uniqueId ~= nil and spawnData.uniqueId ~= "" and buyData.setUniqueId ~= nil then
        buyData:setUniqueId(tostring(spawnData.uniqueId))
    end
    if buyData.setModifyTerrain ~= nil then
        buyData:setModifyTerrain(true)
    end
    if buyData.setRealignToTerrainAfterLeveling ~= nil then
        buyData:setRealignToTerrainAfterLeveling(true)
    end

    local function logBuyCallback(...)
        local callbackArgs = {...}
        local callbackSuccess = nil
        local callbackPlaceable = nil

        for _, value in ipairs(callbackArgs) do
            if callbackSuccess == nil and type(value) == "boolean" then
                callbackSuccess = value
            end
            if callbackPlaceable == nil and type(value) == "table" and value.rootNode ~= nil then
                callbackPlaceable = value
            end
        end

        utLog(string.format(
            "spawnUpgradePlaceable buy callback: xml='%s' success=%s uniqueId='%s'",
            tostring(xmlFilename),
            tostring(callbackSuccess),
            tostring(callbackPlaceable ~= nil and utGetPlaceableUniqueId(callbackPlaceable) or "")
        ))

        local resolvedSuccess = callbackSuccess
        if resolvedSuccess == nil then
            resolvedSuccess = callbackPlaceable ~= nil
        end

        if resolvedSuccess == true then
            finishSpawn(true, "buy callback success")
        else
            finishSpawn(false, "buy callback reported failure")
        end
    end

    local buyCallOk, buyResultOrErr = pcall(function()
        if buyData.buy ~= nil then
            return buyData:buy(logBuyCallback, self)
        end
        return nil
    end)

    if not buyCallOk then
        utError("spawnUpgradePlaceable: BuyPlaceableData:buy failed for '" .. tostring(xmlFilename) .. "': " .. tostring(buyResultOrErr))
        finishSpawn(false, "buy call failed")
        return
    end

    utLog(string.format(
        "spawnUpgradePlaceable buy queued: xml='%s' uniqueId='%s' buyResult=%s",
        tostring(xmlFilename),
        tostring(spawnData.uniqueId or ""),
        tostring(buyResultOrErr)
    ))

    if buyResultOrErr == false then
        finishSpawn(false, "buy returned false")
    end
end

UpgradeTriggerActivatable = {}
local UpgradeTriggerActivatable_mt = Class(UpgradeTriggerActivatable)

function UpgradeTriggerActivatable.new(trigger)
    local self = setmetatable({}, UpgradeTriggerActivatable_mt)
    self.trigger = trigger
    self.activateText = trigger ~= nil and trigger:getActionText() or ""
    return self
end

function UpgradeTriggerActivatable:getIsActivatable()
    return self.trigger ~= nil and self.trigger:getIsActivatable()
end

function UpgradeTriggerActivatable:run()
    if self.trigger ~= nil then
        return self.trigger:onActivateObject()
    end
    return true
end

function UpgradeTriggerActivatable:getDistance(x, y, z)
    if self.trigger ~= nil and self.trigger.getDistance ~= nil then
        return self.trigger:getDistance(x, y, z)
    end
    return 0
end

function UpgradeTriggerActivatable:getText()
    return self.trigger ~= nil and self.trigger:getActionText() or ""
end

function UpgradeTriggerActivatable:getActivateText()
    return self.trigger ~= nil and self.trigger:getActionText() or self.activateText or ""
end

function UpgradeTriggerActivatable:updateActivateText()
    self.activateText = self.trigger ~= nil and self.trigger:getActionText() or ""
end

local UpgradeTrigger_mt = Class(UpgradeTrigger)

function UpgradeTrigger.new(manager, rootNode, triggerNode, configPath, actionText)
    local self = setmetatable({}, UpgradeTrigger_mt)

    self.manager = manager
    self.rootNode = rootNode
    self.nodeId = rootNode
    self.triggerNode = triggerNode
    self.actionText = utResolveActionText(actionText)
    self.playerInside = false
    self.isRegistered = false
    self.activateText = self.actionText
    self.activatable = UpgradeTriggerActivatable.new(self)
    self.configPath = configPath
    self.config = nil

    return self
end

function UpgradeTrigger:loadConfig()
    if self.config ~= nil then
        return true
    end

    if self.configPath == nil then
        utError("upgradeConfig attribute is missing for trigger root node " .. tostring(self.nodeId))
        return false
    end

    local xmlFile = loadXMLFile("upgradeConfigXML", self.configPath)
    if xmlFile == nil or xmlFile == 0 then
        utError("Could not load upgrade config '" .. tostring(self.configPath) .. "'")
        return false
    end

    local config = {
        xmlFile = xmlFile,
        upgrades = {}
    }

    local rootKeys = {
        "upgrades.upgrade",
        "upgrades.upgrades.upgrade"
    }

    local loadedCount = 0

    for _, rootKey in ipairs(rootKeys) do
        local xmlIndex = 0
        while true do
            local key = string.format("%s(%d)", rootKey, xmlIndex)
            if hasXMLProperty == nil or not hasXMLProperty(xmlFile, key) then
                break
            end

            local sourceUniqueId = getXMLString(xmlFile, key .. "#sourceUniqueId")
            local upgrade = {
                sourceUniqueId = sourceUniqueId ~= nil and tostring(sourceUniqueId) or nil,
                title = getXMLString(xmlFile, key .. "#title"),
                description = getXMLString(xmlFile, key .. "#description"),
                price = getXMLFloat(xmlFile, key .. "#price") or 0,
                spawns = {}
            }

            local spawnIndex = 0
            while true do
                local spawnKey = string.format("%s.spawn(%d)", key, spawnIndex)
                if not hasXMLProperty(xmlFile, spawnKey) then
                    break
                end

                local spawnData = {
                    xmlFilename = getXMLString(xmlFile, spawnKey .. "#xmlFilename"),
                    uniqueId = getXMLString(xmlFile, spawnKey .. "#uniqueId"),
                    offsetX = getXMLFloat(xmlFile, spawnKey .. "#offsetX") or 0,
                    offsetY = getXMLFloat(xmlFile, spawnKey .. "#offsetY") or 0,
                    offsetZ = getXMLFloat(xmlFile, spawnKey .. "#offsetZ") or 0,
                    rotOffsetX = getXMLFloat(xmlFile, spawnKey .. "#rotOffsetX") or 0,
                    rotOffsetY = getXMLFloat(xmlFile, spawnKey .. "#rotOffsetY") or 0,
                    rotOffsetZ = getXMLFloat(xmlFile, spawnKey .. "#rotOffsetZ") or 0
                }

                table.insert(upgrade.spawns, spawnData)
                spawnIndex = spawnIndex + 1
            end

            loadedCount = loadedCount + 1
            table.insert(config.upgrades, upgrade)

            utLog(string.format(
                "loadConfig: root='%s' index=%d sourceUniqueId='%s' title='%s' price=%s spawnCount=%d",
                tostring(rootKey),
                xmlIndex,
                tostring(upgrade.sourceUniqueId),
                tostring(upgrade.title),
                tostring(upgrade.price),
                #upgrade.spawns
            ))

            for loggedSpawnIndex, spawnData in ipairs(upgrade.spawns) do
                local resolvedSpawnFilename = utResolveConfigPath(spawnData.xmlFilename, utGetMapDir())
                utLog(string.format(
                    "loadConfig spawn: upgradeSource='%s' spawnIndex=%d xmlFilename='%s' resolved='%s' uniqueId='%s'",
                    tostring(upgrade.sourceUniqueId),
                    loggedSpawnIndex,
                    tostring(spawnData.xmlFilename),
                    tostring(resolvedSpawnFilename),
                    tostring(spawnData.uniqueId)
                ))
            end

            xmlIndex = xmlIndex + 1
        end

        if loadedCount > 0 then
            break
        end
    end

    utLog(string.format("loadConfig summary: configPath='%s' loadedUpgrades=%d", tostring(self.configPath), loadedCount))
    self.config = config
    return true
end

function UpgradeTrigger:ensureConfigLoaded()
    if self.config ~= nil then
        return true
    end

    local ok, result = pcall(function()
        return self:loadConfig()
    end)

    if not ok then
        utError("ensureConfigLoaded failed for '" .. tostring(self.configPath) .. "': " .. tostring(result))
        return false
    end

    if result ~= true or self.config == nil then
        utError("ensureConfigLoaded could not prepare config for '" .. tostring(self.configPath) .. "'")
        return false
    end

    return true
end

function UpgradeTrigger:getIsActivatable()
    return self.playerInside == true
end

function UpgradeTrigger:getDistance(x, y, z)
    return 0
end

function UpgradeTrigger:getActionText()
    return utResolveActionText(self.actionText or self.activateText)
end

function UpgradeTrigger:onActivateObject()
    if self.manager ~= nil then
        self.manager:openGUI(self)
    end
    return true
end

function UpgradeTrigger:registerActivatable()
    if not self.isRegistered and g_currentMission ~= nil and g_currentMission.activatableObjectsSystem ~= nil then
        self.activateText = self:getActionText()

        if self.activatable ~= nil then
            self.activatable.activateText = self.activateText
            if self.activatable.updateActivateText ~= nil then
                self.activatable:updateActivateText()
            end
        end

        g_currentMission.activatableObjectsSystem:addActivatable(self.activatable)
        self.isRegistered = true
    end
end

function UpgradeTrigger:unregisterActivatable()
    if self.isRegistered and g_currentMission ~= nil and g_currentMission.activatableObjectsSystem ~= nil then
        g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)
        self.isRegistered = false
    end
end

function UpgradeTrigger:upgradeTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    if not utIsPlayerActor(otherActorId, otherShapeId) then
        return
    end

    if onEnter then
        self.playerInside = true
        self:registerActivatable()
        if self.manager ~= nil then
            self.manager.playerTrigger = self
        end
    elseif onLeave then
        self.playerInside = false
        self:unregisterActivatable()
        if self.manager ~= nil and self.manager.playerTrigger == self then
            self.manager.playerTrigger = nil
        end
    end
end

local function utEnsureOnCreateAliases(reason)
    local hasGlobal = type(_G["UpgradeTrigger_onCreate"]) == "function"
    local hasModOnCreate = _G["modOnCreate"] ~= nil and type(_G["modOnCreate"].UpgradeTrigger_onCreate) == "function"

    if not hasGlobal or not hasModOnCreate then
        utWarn("Missing UpgradeTrigger onCreate alias before " .. tostring(reason) .. ", re-registering")
    end

    utRegisterOnCreateAliases()
end

local function utLoadMission(mission)
    utEnsureOnCreateAliases("Mission00.load")

    if mission.upgradeTriggerManager == nil then
        mission.upgradeTriggerManager = UpgradeTriggerManager.new(mission)
        addModEventListener(mission.upgradeTriggerManager)
    end
end

local function utDeleteMission(mission)
    if mission ~= nil and mission.upgradeTriggerManager ~= nil then
        removeModEventListener(mission.upgradeTriggerManager)
        mission.upgradeTriggerManager:delete()
        mission.upgradeTriggerManager = nil
    end
end

local function utInstallMissionHooks()
    if UpgradeTrigger._hooksInstalled then
        return
    end
    UpgradeTrigger._hooksInstalled = true

    Mission00.load = Utils.prependedFunction(Mission00.load, utLoadMission)
    FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, utDeleteMission)
end

utInstallMissionHooks()
