SvapaToggleGUI = {}
local SvapaToggleGUI_mt = Class(SvapaToggleGUI, MessageDialog)

local STG_MOD_DIR = g_currentModDirectory or ""
local STG_TEXTURE_DIR = STG_MOD_DIR .. "scripts/upgrade_mod/gui/textures/"
local STG_LOG_PREFIX = "[SvapaToggleGUI]"

local function stgWarn(message)
    print(string.format("%s [WARN] %s", STG_LOG_PREFIX, tostring(message or "")))
end

local function stgSetText(element, text)
    if element ~= nil and element.setText ~= nil then
        element:setText(tostring(text or ""))
    end
end

local function stgSetVisible(element, state)
    if element ~= nil and element.setVisible ~= nil then
        element:setVisible(state == true)
    end
end

local function stgResolveTextureFilename(baseName)
    if baseName == nil or baseName == "" then
        return nil
    end

    local ddsFilename = STG_TEXTURE_DIR .. tostring(baseName) .. ".dds"
    if fileExists == nil or fileExists(ddsFilename) then
        return ddsFilename
    end

    local pngFilename = STG_TEXTURE_DIR .. tostring(baseName) .. ".png"
    if fileExists(pngFilename) then
        return pngFilename
    end

    return ddsFilename
end

local function stgApplyBitmapTexture(element, textureName)
    if element ~= nil and element.setImageFilename ~= nil then
        local filename = stgResolveTextureFilename(textureName)
        if filename ~= nil and filename ~= "" then
            element:setImageFilename(filename)
        end
    end
end

local function stgGetChildren(element)
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

local function stgGetChild(element, index)
    local children = stgGetChildren(element)
    if children == nil then
        return nil
    end
    return children[index]
end

local function stgFindDescendantByIdRecursive(element, wantedId)
    if element == nil or wantedId == nil then
        return nil
    end
    if element.id == wantedId or element.name == wantedId then
        return element
    end

    local children = stgGetChildren(element) or {}
    for _, child in ipairs(children) do
        local found = stgFindDescendantByIdRecursive(child, wantedId)
        if found ~= nil then
            return found
        end
    end
    return nil
end

local function stgBuildToggleRowRefs(row)
    return {
        toggleRowBackground = stgFindDescendantByIdRecursive(row, "toggleRowBackground") or stgGetChild(row, 1),
        toggleRowInner = stgFindDescendantByIdRecursive(row, "toggleRowInner") or stgGetChild(row, 2),
        toggleCheckFrame = stgFindDescendantByIdRecursive(row, "toggleCheckFrame") or stgGetChild(row, 3),
        toggleCheckButton = stgFindDescendantByIdRecursive(row, "toggleCheckButton") or stgGetChild(row, 4),
        toggleDescriptionFrame = stgFindDescendantByIdRecursive(row, "toggleDescriptionFrame") or stgGetChild(row, 5),
        toggleDescriptionText = stgFindDescendantByIdRecursive(row, "toggleDescriptionText") or stgGetChild(row, 6)
    }
end

function SvapaToggleGUI.new(target, customMt)
    local self = MessageDialog.new(target, customMt or SvapaToggleGUI_mt)
    self.trigger = nil
    self.toggleEntries = {}
    self.toggleRowClones = {}
    return self
end

function SvapaToggleGUI.register(xmlFilename)
    if SvapaToggleGUI.instance ~= nil then
        return SvapaToggleGUI.instance
    end

    if g_gui == nil then
        Logging.error("[SvapaToggleGUI] g_gui is nil")
        return nil
    end

    local self = SvapaToggleGUI.new()
    SvapaToggleGUI.instance = self

    local ok, err = pcall(function()
        g_gui:loadGui(xmlFilename, "SvapaToggleGUI", self)
    end)

    if not ok then
        Logging.error("[SvapaToggleGUI] loadGui failed: %s", tostring(err))
        SvapaToggleGUI.instance = nil
        return nil
    end

    return self
end

function SvapaToggleGUI.show(trigger)
    if SvapaToggleGUI.instance == nil then
        Logging.error("[SvapaToggleGUI] GUI is not registered")
        return nil
    end

    SvapaToggleGUI.instance.trigger = trigger
    if g_gui ~= nil then
        g_gui:showDialog("SvapaToggleGUI")
        return true
    end
    return nil
end

function SvapaToggleGUI:onCreate()
    SvapaToggleGUI:superClass().onCreate(self)
end

function SvapaToggleGUI:onGuiSetupFinished()
    SvapaToggleGUI:superClass().onGuiSetupFinished(self)

    self.toggleWindowOuter = self:getDescendantById("toggleWindowOuter")
    self.toggleWindowInner = self:getDescendantById("toggleWindowInner")
    self.toggleListBackground = self:getDescendantById("toggleListBackground")
    self.toggleListContainer = self:getDescendantById("toggleListContainer")
    self.toggleEmptyText = self:getDescendantById("toggleEmptyText")
    self.toggleFooterText = self:getDescendantById("toggleFooterText")
    self.toggleRowTemplate = self:getDescendantById("toggleRowTemplate")
    self.toggleCloseButton = self:getDescendantById("toggleCloseButton")
    self.toggleSaveButton = self:getDescendantById("toggleSaveButton")

    stgApplyBitmapTexture(self.toggleWindowOuter, "svapa_window_bg")
    stgApplyBitmapTexture(self.toggleWindowInner, "svapa_inner_bg")
    stgApplyBitmapTexture(self.toggleListBackground, "svapa_window_bg")

    stgSetText(self.toggleFooterText, "Отметьте нужные переключатели и нажмите Сохранить")
    stgSetText(self.toggleEmptyText, "Переключатели не найдены")
    stgSetText(self.toggleCloseButton, "Выйти")
    stgSetText(self.toggleSaveButton, "Сохранить")

    if self.toggleRowTemplate ~= nil then
        self.toggleRowTemplate:setVisible(false)
    end
end

function SvapaToggleGUI:onOpen()
    SvapaToggleGUI:superClass().onOpen(self)
    self:rebuildToggleRows()
end

function SvapaToggleGUI:onClose()
    self.trigger = nil
    self:clearToggleRows()
    SvapaToggleGUI:superClass().onClose(self)
end

function SvapaToggleGUI:onClickToggleClose()
    self:close()
end

function SvapaToggleGUI:onClickBack(forceBack, usedMenuButton)
    self:close()
    return true
end

function SvapaToggleGUI:clearToggleRows()
    for _, row in ipairs(self.toggleRowClones) do
        if row ~= nil then
            pcall(function() row:unlinkElement() end)
            pcall(function() row:delete() end)
        end
    end
    self.toggleRowClones = {}
    self.toggleEntries = {}
end

function SvapaToggleGUI:bindToggleButton(button, index, entry)
    if button == nil then
        return
    end

    button.target = self
    button.toggleIndex = index
    button.toggleEntry = entry
    button.onClick = nil
    button.onClickCallback = function()
        self:onClickToggleState(button)
    end
end

function SvapaToggleGUI:getToggleMark(value)
    return value == true and "[X]" or "[ ]"
end

function SvapaToggleGUI:rebuildToggleRows()
    self:clearToggleRows()

    if self.trigger == nil or self.trigger.manager == nil then
        stgWarn("rebuildToggleRows skipped: trigger or manager is nil")
        stgSetVisible(self.toggleEmptyText, true)
        return
    end

    self.toggleEntries = self.trigger.manager:getFeatureEntriesForTrigger(self.trigger)
    stgSetVisible(self.toggleEmptyText, #self.toggleEntries == 0)

    if self.toggleListContainer == nil or self.toggleRowTemplate == nil then
        stgWarn("rebuildToggleRows aborted: list container or template is nil")
        return
    end

    for index, entry in ipairs(self.toggleEntries) do
        local row = self.toggleRowTemplate:clone(self.toggleListContainer)
        row:setVisible(true)

        local refs = stgBuildToggleRowRefs(row)
        stgApplyBitmapTexture(refs.toggleRowBackground, "svapa_card_bg")
        stgApplyBitmapTexture(refs.toggleCheckFrame, "svapa_window_bg")
        stgApplyBitmapTexture(refs.toggleDescriptionFrame, "svapa_block_white")
        stgApplyBitmapTexture(refs.toggleCheckButton, "svapa_block_white")

        stgSetText(refs.toggleCheckButton, self:getToggleMark(entry.value))
        stgSetText(refs.toggleDescriptionText, entry.description)
        self:bindToggleButton(refs.toggleCheckButton, index, entry)

        table.insert(self.toggleRowClones, row)
    end

    if self.toggleListContainer.invalidateLayout ~= nil then
        self.toggleListContainer:invalidateLayout()
    end
end

function SvapaToggleGUI:onClickToggleState(element)
    local entry = nil
    local index = nil

    if type(element) == "number" then
        index = element
        entry = self.toggleEntries[index]
    elseif element ~= nil then
        index = element.toggleIndex
        entry = element.toggleEntry or (index ~= nil and self.toggleEntries[index] or nil)
    end

    if entry == nil then
        return
    end

    entry.value = not (entry.value == true)

    if self.trigger ~= nil and self.trigger.manager ~= nil then
        self.trigger.manager:setToggleValue(entry.id, entry.value)
    end

    if element ~= nil then
        stgSetText(element, self:getToggleMark(entry.value))
    else
        self:rebuildToggleRows()
    end
end

function SvapaToggleGUI:onClickToggleSave()
    local manager = self.trigger ~= nil and self.trigger.manager or nil
    if manager == nil then
        return
    end

    local saved = manager:saveToggleStateFile()
    if saved and g_currentMission ~= nil and g_currentMission.addIngameNotification ~= nil then
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, "Настройки переключателей сохранены")
    elseif not saved and g_currentMission ~= nil and g_currentMission.addIngameNotification ~= nil then
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_CRITICAL, "Не удалось сохранить переключатели")
    end
end