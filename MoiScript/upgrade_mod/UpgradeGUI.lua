UpgradeGUI = {}
local UpgradeGUI_mt = Class(UpgradeGUI, MessageDialog)

local UG_MOD_DIR = g_currentModDirectory or ""
local UG_TEXTURE_DIR = UG_MOD_DIR .. "scripts/upgrade_mod/gui/textures/"
local UG_LOG_PREFIX = "[UpgradeGUI]"

local function ugWarn(message)
    print(string.format("%s [WARN] %s", UG_LOG_PREFIX, tostring(message or "")))
end

function UpgradeGUI.new(target, customMt)
    local self = MessageDialog.new(target, customMt or UpgradeGUI_mt)

    self.trigger = nil
    self.entries = {}
    self.rowClones = {}

    return self
end

local function ugSetText(element, text)
    if element ~= nil and element.setText ~= nil then
        element:setText(tostring(text or ""))
    end
end

local function ugSetVisible(element, state)
    if element ~= nil and element.setVisible ~= nil then
        element:setVisible(state == true)
    end
end

local function ugSetDisabled(element, state)
    if element ~= nil and element.setDisabled ~= nil then
        element:setDisabled(state == true)
    end
end

local function ugFormatMoney(value)
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
                return tostring(result)
            end
        end
    end

    if g_i18n ~= nil and g_i18n.formatMoney ~= nil then
        return g_i18n:formatMoney(amount, 0, true, true)
    end

    return tostring(amount)
end

local function ugResolveTextureFilename(baseName)
    if baseName == nil or baseName == "" then
        return nil
    end

    local ddsFilename = UG_TEXTURE_DIR .. tostring(baseName) .. ".dds"
    if fileExists == nil or fileExists(ddsFilename) then
        return ddsFilename
    end

    local pngFilename = UG_TEXTURE_DIR .. tostring(baseName) .. ".png"
    if fileExists(pngFilename) then
        return pngFilename
    end

    return ddsFilename
end

local function ugApplyBitmapTexture(element, textureName)
    if element ~= nil and element.setImageFilename ~= nil then
        local filename = ugResolveTextureFilename(textureName)
        if filename ~= nil and filename ~= "" then
            element:setImageFilename(filename)
        end
    end
end

local function ugNormalizePath(path)
    if path == nil or path == "" then
        return nil
    end

    return tostring(path):gsub("\\", "/")
end

local function ugNormalizeDir(dir)
    local normalized = ugNormalizePath(dir)
    if normalized == nil or normalized == "" then
        return ""
    end

    if normalized:sub(-1) ~= "/" then
        normalized = normalized .. "/"
    end

    return normalized
end

local function ugIsAbsolutePath(path)
    local normalized = ugNormalizePath(path)
    if normalized == nil or normalized == "" then
        return false
    end

    if normalized:match("^[A-Za-z]:/") ~= nil then
        return true
    end

    if normalized:sub(1, 1) == "/" or normalized:sub(1, 2) == "//" then
        return true
    end

    return false
end

local function ugResolveRowIconFallback()
    return ugResolveTextureFilename("svapa_block_white")
end

local function ugResolveTitle(entry)
    if entry == nil then
        return "Предприятие"
    end

    if entry.title ~= nil and entry.title ~= "" then
        return tostring(entry.title)
    end

    if entry.name ~= nil and entry.name ~= "" then
        return tostring(entry.name)
    end

    if entry.placeable ~= nil then
        if entry.placeable.title ~= nil and entry.placeable.title ~= "" then
            return tostring(entry.placeable.title)
        end

        if entry.placeable.name ~= nil and entry.placeable.name ~= "" then
            return tostring(entry.placeable.name)
        end
    end

    return "Предприятие"
end

local function ugResolveEnterpriseDescription(entry)
    if entry == nil then
        return ""
    end

    if entry.enterpriseDescription ~= nil and entry.enterpriseDescription ~= "" then
        return tostring(entry.enterpriseDescription)
    end

    if entry.description ~= nil and entry.description ~= "" then
        return tostring(entry.description)
    end

    if entry.placeable ~= nil then
        if entry.placeable.description ~= nil and entry.placeable.description ~= "" then
            return tostring(entry.placeable.description)
        end

        if entry.placeable.storeItem ~= nil and entry.placeable.storeItem.description ~= nil and entry.placeable.storeItem.description ~= "" then
            return tostring(entry.placeable.storeItem.description)
        end

        if entry.placeable.configFileName ~= nil and entry.placeable.configFileName ~= "" then
            return tostring(entry.placeable.configFileName)
        end
    end

    return ""
end

local function ugResolveUpgradeTitle(entry)
    if entry ~= nil and entry.config ~= nil and entry.config.title ~= nil and entry.config.title ~= "" then
        return tostring(entry.config.title)
    end

    return "Улучшение"
end

local function ugResolveUpgradeDescription(entry)
    if entry == nil or entry.config == nil then
        return "Для этого предприятия улучшение не настроено"
    end

    local config = entry.config

    if config.description ~= nil and config.description ~= "" then
        return tostring(config.description)
    end

    if config.upgradeDescription ~= nil and config.upgradeDescription ~= "" then
        return tostring(config.upgradeDescription)
    end

    if config.title ~= nil and config.title ~= "" then
        return string.format("Улучшение: %s", tostring(config.title))
    end

    return "Доступно улучшение по конфигурации"
end

local function ugResolveStoreIconFilename(entry)
    if entry == nil then
        return nil
    end

    if entry.storeItem ~= nil and entry.storeItem.imageFilename ~= nil and entry.storeItem.imageFilename ~= "" then
        return entry.storeItem.imageFilename
    end

    if entry.imageFilename ~= nil and entry.imageFilename ~= "" then
        return entry.imageFilename
    end

    return nil
end

local function ugResolveDisplayIconFilename(entry)
    local rawStoreImage = ugResolveStoreIconFilename(entry)
    if rawStoreImage == nil or rawStoreImage == "" then
        return nil, false
    end

    return rawStoreImage, true
end

local function ugApplyStoreImageToElement(imageElement, entry)
    if imageElement == nil or imageElement.setImageFilename == nil then
        return nil, false
    end

    local storeItem = entry ~= nil and entry.storeItem or nil
    if storeItem ~= nil and storeItem.imageFilename ~= nil and storeItem.imageFilename ~= "" then
        local ok, err = pcall(function()
            imageElement:setImageFilename(storeItem.imageFilename)
        end)

        if ok then
            return storeItem.imageFilename, true
        end

        ugWarn("icon apply failed for storeItem.imageFilename: " .. tostring(err))
    end

    if entry ~= nil and entry.imageFilename ~= nil and entry.imageFilename ~= "" then
        local ok, err = pcall(function()
            imageElement:setImageFilename(entry.imageFilename)
        end)

        if ok then
            return entry.imageFilename, true
        end

        ugWarn("icon apply failed for entry.imageFilename: " .. tostring(err))
    end

    return nil, false
end

local function ugGetChildren(element)
    if element == nil then
        return nil
    end

    if element.elements ~= nil then
        return element.elements
    end

    if element.children ~= nil then
        return element.children
    end

    return nil
end

local function ugGetChild(element, index)
    local children = ugGetChildren(element)
    if children == nil then
        return nil
    end

    return children[index]
end

local function ugGetElementDebugName(element)
    if element == nil then
        return "nil"
    end

    local parts = {}
    if element.id ~= nil then
        table.insert(parts, "id=" .. tostring(element.id))
    end
    if element.name ~= nil then
        table.insert(parts, "name=" .. tostring(element.name))
    end
    if element.profile ~= nil and element.profile.name ~= nil then
        table.insert(parts, "profile=" .. tostring(element.profile.name))
    end

    if #parts == 0 then
        return tostring(element)
    end

    return table.concat(parts, ",")
end

local function ugDumpElementTree(element, depth, lines, maxDepth)
    depth = depth or 0
    maxDepth = maxDepth or 3
    if element == nil or depth > maxDepth then
        return
    end

    table.insert(lines, string.rep("  ", depth) .. "- " .. ugGetElementDebugName(element))

    local children = ugGetChildren(element) or {}
    for _, child in ipairs(children) do
        ugDumpElementTree(child, depth + 1, lines, maxDepth)
    end
end

local function ugFindDescendantByIdRecursive(element, wantedId)
    if element == nil or wantedId == nil then
        return nil
    end

    if element.id == wantedId or element.name == wantedId then
        return element
    end

    local children = ugGetChildren(element) or {}
    for _, child in ipairs(children) do
        local found = ugFindDescendantByIdRecursive(child, wantedId)
        if found ~= nil then
            return found
        end
    end

    return nil
end

local function ugBuildRowRefs(row)
    local refs = {}

    refs.rowBg = ugFindDescendantByIdRecursive(row, "rowBg") or ugGetChild(row, 1)
    refs.rowInnerBg = ugFindDescendantByIdRecursive(row, "rowInnerBg") or ugGetChild(row, 2)
    refs.iconBlock = ugFindDescendantByIdRecursive(row, "iconBlock") or ugGetChild(row, 3)
    refs.enterpriseBlock = ugFindDescendantByIdRecursive(row, "enterpriseBlock") or ugGetChild(row, 4)
    refs.upgradeBlock = ugFindDescendantByIdRecursive(row, "upgradeBlock") or ugGetChild(row, 5)
    refs.actionBlock = ugFindDescendantByIdRecursive(row, "actionBlock") or ugGetChild(row, 6)

    refs.iconBlockBg = ugFindDescendantByIdRecursive(refs.iconBlock, "iconBlockBg") or ugGetChild(refs.iconBlock, 2)
    refs.icon = ugFindDescendantByIdRecursive(refs.iconBlock, "rowIcon") or ugGetChild(refs.iconBlock, 3)

    refs.enterpriseBg = ugFindDescendantByIdRecursive(refs.enterpriseBlock, "enterpriseBg") or ugGetChild(refs.enterpriseBlock, 2)
    refs.nameText = ugFindDescendantByIdRecursive(refs.enterpriseBlock, "rowName") or ugGetChild(refs.enterpriseBlock, 3)
    refs.enterpriseDescriptionText = ugFindDescendantByIdRecursive(refs.enterpriseBlock, "enterpriseDescriptionText") or ugGetChild(refs.enterpriseBlock, 4)

    refs.upgradeBg = ugFindDescendantByIdRecursive(refs.upgradeBlock, "upgradeBg") or ugGetChild(refs.upgradeBlock, 2)
    refs.upgradeTitleText = ugFindDescendantByIdRecursive(refs.upgradeBlock, "upgradeTitleText") or ugGetChild(refs.upgradeBlock, 3)
    refs.upgradeDescriptionText = ugFindDescendantByIdRecursive(refs.upgradeBlock, "upgradeDescriptionText") or ugGetChild(refs.upgradeBlock, 4)

    refs.priceLabel = ugFindDescendantByIdRecursive(refs.actionBlock, "rowPriceLabel") or ugGetChild(refs.actionBlock, 1)
    refs.priceFrame = ugFindDescendantByIdRecursive(refs.actionBlock, "priceFrame") or ugGetChild(refs.actionBlock, 2)
    refs.priceBoxBg = ugFindDescendantByIdRecursive(refs.actionBlock, "priceBoxBg") or ugGetChild(refs.actionBlock, 3)
    refs.priceText = ugFindDescendantByIdRecursive(refs.actionBlock, "rowPrice") or ugGetChild(refs.actionBlock, 4)
    refs.statusText = ugFindDescendantByIdRecursive(refs.actionBlock, "rowStatus") or ugGetChild(refs.actionBlock, 5)
    refs.buttonFrame = ugFindDescendantByIdRecursive(refs.actionBlock, "rowButtonFrame") or ugGetChild(refs.actionBlock, 6)
    refs.upgradeButtonBg = ugFindDescendantByIdRecursive(refs.actionBlock, "rowButtonBg") or ugGetChild(refs.actionBlock, 7)
    refs.upgradeButton = ugFindDescendantByIdRecursive(refs.actionBlock, "rowButton") or ugGetChild(refs.actionBlock, 8)

    return refs
end

function UpgradeGUI.register(xmlFilename)
    if UpgradeGUI.instance ~= nil then
        return UpgradeGUI.instance
    end

    if g_gui == nil then
        Logging.error("[UpgradeGUI] g_gui is nil")
        return nil
    end

    local self = UpgradeGUI.new()
    UpgradeGUI.instance = self

    local ok, err = pcall(function()
        g_gui:loadGui(xmlFilename, "UpgradeGUI", self)
    end)

    if not ok then
        Logging.error("[UpgradeGUI] loadGui failed: %s", tostring(err))
        UpgradeGUI.instance = nil
        return nil
    end

    return self
end

function UpgradeGUI.show(trigger)
    if UpgradeGUI.instance == nil then
        Logging.error("[UpgradeGUI] GUI is not registered")
        return nil
    end

    UpgradeGUI.instance.trigger = trigger

    if g_gui ~= nil then
        g_gui:showDialog("UpgradeGUI")
        return true
    end

    return nil
end

function UpgradeGUI:onCreate()
    UpgradeGUI:superClass().onCreate(self)
end

function UpgradeGUI:onGuiSetupFinished()
    UpgradeGUI:superClass().onGuiSetupFinished(self)
    self.outerBlack = self:getDescendantById("outerBlack")
    self.innerGray = self:getDescendantById("innerGray")
    self.listBlack = self:getDescendantById("listBlack")
    self.footerText = self:getDescendantById("footerText")
    self.emptyText = self:getDescendantById("emptyText")
    self.listContainer = self:getDescendantById("listContainer")
    self.rowTemplate = self:getDescendantById("rowTemplate")
    self.closeButton = self:getDescendantById("closeButton")

    ugApplyBitmapTexture(self.outerBlack, "svapa_window_bg")
    ugApplyBitmapTexture(self.innerGray, "svapa_inner_bg")
    ugApplyBitmapTexture(self.listBlack, "svapa_window_bg")

    ugSetText(self.footerText, "Выберите предприятие которое хотите модернизировать. Если кнопки нет - улучшить нельзя")
    ugSetText(self.emptyText, "Подходящие предприятия не найдены")

    if self.closeButton ~= nil then
        ugSetText(self.closeButton, "Выйти")
    end

    if self.rowTemplate ~= nil then
        self.rowTemplate:setVisible(false)
    end
end

function UpgradeGUI:onOpen()
    UpgradeGUI:superClass().onOpen(self)
    self:rebuildRows()
end

function UpgradeGUI:onClose()
    self.trigger = nil
    self:clearRows()
    UpgradeGUI:superClass().onClose(self)
end

function UpgradeGUI:onClickClose()
    self:close()
end

function UpgradeGUI:onClickBack(forceBack, usedMenuButton)
    self:close()
    return true
end

function UpgradeGUI:clearRows()
    for _, row in ipairs(self.rowClones) do
        if row ~= nil then
            pcall(function()
                row:unlinkElement()
            end)
            pcall(function()
                row:delete()
            end)
        end
    end

    self.rowClones = {}
    self.entries = {}
end

function UpgradeGUI:bindUpgradeButton(button, index, entry)
    if button == nil then
        ugWarn("bindUpgradeButton: button is nil for row " .. tostring(index))
        return
    end

    button.target = self
    button.rowIndex = index
    button.entry = entry
    button.onClick = nil
    button.onClickCallback = function()
        self:onClickUpgrade(button)
    end
end

function UpgradeGUI:rebuildRows()
    self:clearRows()

    if self.trigger == nil or self.trigger.manager == nil then
        ugWarn("rebuildRows skipped: trigger or manager is nil")
        ugSetVisible(self.emptyText, true)
        return
    end

    local farmId = g_currentMission ~= nil and g_currentMission:getFarmId() or FarmManager.SINGLEPLAYER_FARM_ID
    self.entries = self.trigger.manager:collectFarmPlaceables(self.trigger, farmId)

    ugSetVisible(self.emptyText, #self.entries == 0)

    if self.listContainer == nil or self.rowTemplate == nil then
        ugWarn("rebuildRows aborted: listContainer or rowTemplate is nil")
        return
    end

    for index, entry in ipairs(self.entries) do
        local row = self.rowTemplate:clone(self.listContainer)
        row:setVisible(true)

        local refs = ugBuildRowRefs(row)

        if refs.nameText == nil or refs.enterpriseDescriptionText == nil or refs.upgradeDescriptionText == nil or refs.actionBlock == nil or refs.upgradeButton == nil then
            local lines = {}
            ugDumpElementTree(row, 0, lines, 4)
            ugWarn("row " .. tostring(index) .. " missing expected GUI refs; row tree:\n" .. table.concat(lines, "\n"))
        end

        ugApplyBitmapTexture(refs.rowBg, "svapa_card_bg")
        ugApplyBitmapTexture(refs.enterpriseBg, "svapa_block_white")
        ugApplyBitmapTexture(refs.upgradeBg, "svapa_block_white")
        ugApplyBitmapTexture(refs.priceFrame, "svapa_window_bg")
        ugApplyBitmapTexture(refs.priceBoxBg, "svapa_price_box")
        ugApplyBitmapTexture(refs.buttonFrame, "svapa_window_bg")
        ugApplyBitmapTexture(refs.upgradeButtonBg, "svapa_button")

        local title = ugResolveTitle(entry)
        local enterpriseDescription = ugResolveEnterpriseDescription(entry)
        local upgradeTitle = ugResolveUpgradeTitle(entry)
        local upgradeDescription = ugResolveUpgradeDescription(entry)
        local finalImageFilename, finalImageExists = ugResolveDisplayIconFilename(entry)
        local hasUpgradeConfig = entry.config ~= nil
        local canUpgrade = entry.canUpgrade == true

        local enterpriseTitleText = enterpriseDescription ~= nil and enterpriseDescription ~= "" and enterpriseDescription or title
        local enterpriseDescriptionText = title ~= nil and title ~= "" and title or enterpriseDescription

        local upgradeTitleText = upgradeDescription ~= nil and upgradeDescription ~= "" and upgradeDescription or upgradeTitle
        local upgradeDescriptionText = upgradeTitle ~= nil and upgradeTitle ~= "" and upgradeTitle or upgradeDescription

        ugSetText(refs.nameText, enterpriseTitleText)
        ugSetText(refs.enterpriseDescriptionText, enterpriseDescriptionText)
        ugSetText(refs.upgradeTitleText, upgradeTitleText)
        ugSetText(refs.upgradeDescriptionText, upgradeDescriptionText)

        ugSetVisible(refs.actionBlock, hasUpgradeConfig)

        if hasUpgradeConfig then
            ugSetVisible(refs.priceLabel, true)
            ugSetVisible(refs.priceFrame, true)
            ugSetVisible(refs.priceBoxBg, true)
            ugSetVisible(refs.priceText, true)
            ugSetText(refs.priceLabel, "СТОИМОСТЬ")
            ugSetText(refs.priceText, ugFormatMoney(entry.price or 0))
        else
            ugSetVisible(refs.priceLabel, false)
            ugSetVisible(refs.priceFrame, false)
            ugSetVisible(refs.priceBoxBg, false)
            ugSetVisible(refs.priceText, false)
            ugSetText(refs.priceText, "")
        end

        ugSetVisible(refs.statusText, false)
        ugSetText(refs.statusText, "")

        ugSetVisible(refs.iconBlockBg, true)
        ugSetVisible(refs.icon, true)

        if refs.icon ~= nil and refs.icon.setImageFilename ~= nil then
            if finalImageFilename ~= nil and finalImageFilename ~= "" and finalImageExists then
                local ok, err = pcall(function()
                    local _, appliedOk = ugApplyStoreImageToElement(refs.icon, entry)
                    if not appliedOk then
                        error("image not applied")
                    end
                end)
                if not ok then
                    ugWarn("row " .. tostring(index) .. " failed to set image '" .. tostring(finalImageFilename) .. "': " .. tostring(err))
                end
            else
                local fallbackFilename = ugResolveRowIconFallback()
                if fallbackFilename ~= nil and fallbackFilename ~= "" then
                    refs.icon:setImageFilename(fallbackFilename)
                end
            end
        end

        if refs.buttonFrame ~= nil then
            ugSetVisible(refs.buttonFrame, hasUpgradeConfig)
        end

        if refs.upgradeButtonBg ~= nil then
            ugSetVisible(refs.upgradeButtonBg, hasUpgradeConfig)
        end

        if refs.upgradeButton ~= nil then
            ugSetVisible(refs.upgradeButton, hasUpgradeConfig)
            ugSetDisabled(refs.upgradeButton, not canUpgrade)

            if hasUpgradeConfig then
                ugSetText(refs.upgradeButton, "Модернизировать")
                self:bindUpgradeButton(refs.upgradeButton, index, entry)
            else
                refs.upgradeButton.rowIndex = nil
                refs.upgradeButton.entry = nil
                refs.upgradeButton.target = nil
                refs.upgradeButton.onClick = nil
                refs.upgradeButton.onClickCallback = nil
            end
        end

        table.insert(self.rowClones, row)
    end

    if self.listContainer.invalidateLayout ~= nil then
        self.listContainer:invalidateLayout()
    end
end

function UpgradeGUI:onClickUpgrade(element)
    local index = nil
    local entry = nil

    if type(element) == "number" then
        index = element
        entry = self.entries[index]
    elseif element ~= nil then
        index = element.rowIndex
        entry = element.entry or (index ~= nil and self.entries[index] or nil)
    end

    local manager = self.trigger ~= nil and self.trigger.manager or nil

    if entry == nil or not entry.canUpgrade or manager == nil or entry.placeable == nil or entry.config == nil then
        ugWarn(string.format(
            "onClickUpgrade ignored: entryNil=%s canUpgrade=%s managerNil=%s placeableNil=%s configNil=%s",
            tostring(entry == nil),
            tostring(entry ~= nil and entry.canUpgrade == true),
            tostring(manager == nil),
            tostring(entry == nil or entry.placeable == nil),
            tostring(entry == nil or entry.config == nil)
        ))
        return
    end

    manager:onUpgradeButtonPressed(entry)
end