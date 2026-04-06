SvapaToggleGUI = {}
local SvapaToggleGUI_mt = Class(SvapaToggleGUI, MessageDialog)

local STG_MOD_DIR = g_currentModDirectory or ""
local STG_TEXTURE_DIR = STG_MOD_DIR .. "scripts/upgrade_mod/gui/textures/"
local STG_LOG_PREFIX = "[SvapaToggleGUI]"
local STG_ROWS_PER_PAGE = 6

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

local function stgSetDisabled(element, state)
    if element ~= nil and element.setDisabled ~= nil then
        element:setDisabled(state == true)
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
        toggleDescriptionFrame = stgFindDescendantByIdRecursive(row, "toggleDescriptionFrame"),
        toggleDescriptionText = stgFindDescendantByIdRecursive(row, "toggleDescriptionText"),
        toggleOption = stgFindDescendantByIdRecursive(row, "toggleBinaryOption"),
        toggleOptionBackground = stgFindDescendantByIdRecursive(row, "toggleOptionBackground"),
        toggleOptionSlider = stgFindDescendantByIdRecursive(row, "toggleOptionSlider")
    }
end

function SvapaToggleGUI.new(target, customMt)
    local self = MessageDialog.new(target, customMt or SvapaToggleGUI_mt)
    self.trigger = nil
    self.toggleEntries = {}
    self.rowClones = {}
    self.currentPage = 1
    self.rowsPerPage = STG_ROWS_PER_PAGE
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
    self.listViewport = self:getDescendantById("listViewport")
    self.listContainer = self:getDescendantById("listContainer")
    self.rowTemplate = self:getDescendantById("rowTemplate")
    self.toggleEmptyText = self:getDescendantById("toggleEmptyText")
    self.toggleFooterText = self:getDescendantById("toggleFooterText")
    self.toggleCloseButton = self:getDescendantById("toggleCloseButton")
    self.toggleSaveButton = self:getDescendantById("toggleSaveButton")
    self.togglePrevPageButton = self:getDescendantById("togglePrevPageButton")
    self.toggleNextPageButton = self:getDescendantById("toggleNextPageButton")
    self.togglePageIndicatorText = self:getDescendantById("togglePageIndicatorText")

    stgApplyBitmapTexture(self.toggleWindowOuter, "svapa_window_bg")
    stgApplyBitmapTexture(self.toggleWindowInner, "svapa_inner_bg")
    stgApplyBitmapTexture(self.toggleListBackground, "svapa_window_bg")

    stgSetText(self.toggleFooterText, "Измените переключатели и нажмите Сохранить")
    stgSetText(self.toggleEmptyText, "Переключатели не найдены")
    stgSetText(self.toggleCloseButton, "Выйти")
    stgSetText(self.toggleSaveButton, "Сохранить")
    stgSetText(self.togglePrevPageButton, "Назад")
    stgSetText(self.toggleNextPageButton, "Вперёд")

    if self.rowTemplate ~= nil then
        self.rowTemplate:setVisible(false)
    end
end

function SvapaToggleGUI:onOpen()
    SvapaToggleGUI:superClass().onOpen(self)
    self.currentPage = 1
    self:refreshToggleEntries()
    self:rebuildRows()
end

function SvapaToggleGUI:onClose()
    self.trigger = nil
    self.toggleEntries = {}
    self.currentPage = 1
    self:clearRows()
    SvapaToggleGUI:superClass().onClose(self)
end

function SvapaToggleGUI:onClickToggleClose()
    self:close()
end

function SvapaToggleGUI:onClickBack(forceBack, usedMenuButton)
    self:close()
    return true
end

function SvapaToggleGUI:refreshToggleEntries()
    if self.trigger == nil or self.trigger.manager == nil then
        stgWarn("refreshToggleEntries skipped: trigger or manager is nil")
        self.toggleEntries = {}
        stgSetVisible(self.toggleEmptyText, true)
        return
    end

    self.toggleEntries = self.trigger.manager:getFeatureEntriesForTrigger(self.trigger) or {}
    stgSetVisible(self.toggleEmptyText, #self.toggleEntries == 0)
end

function SvapaToggleGUI:clearRows()
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
end

function SvapaToggleGUI:getPageCount()
    local count = #self.toggleEntries
    if count <= 0 then
        return 1
    end

    return math.max(math.ceil(count / self.rowsPerPage), 1)
end

function SvapaToggleGUI:updatePaginationUi()
    local pageCount = self:getPageCount()

    if self.currentPage < 1 then
        self.currentPage = 1
    elseif self.currentPage > pageCount then
        self.currentPage = pageCount
    end

    stgSetText(self.togglePageIndicatorText, string.format("Страница %d / %d", self.currentPage, pageCount))
    stgSetDisabled(self.togglePrevPageButton, self.currentPage <= 1)
    stgSetDisabled(self.toggleNextPageButton, self.currentPage >= pageCount)

    local showPagination = (#self.toggleEntries > self.rowsPerPage)
    stgSetVisible(self.togglePrevPageButton, showPagination)
    stgSetVisible(self.toggleNextPageButton, showPagination)
    stgSetVisible(self.togglePageIndicatorText, showPagination)
end

function SvapaToggleGUI:bindToggleOption(optionElement, index, entry)
    if optionElement == nil then
        return
    end

    optionElement.target = self
    optionElement.toggleIndex = index
    optionElement.toggleEntry = entry

    if optionElement.setCallback ~= nil then
        optionElement:setCallback("onClickState", "onClickToggleState")
    end

    optionElement.onClickState = function(_, state)
        self:onClickToggleState(optionElement, state)
    end

    optionElement.onClickCallback = function()
        self:onClickToggleState(optionElement)
    end
end

function SvapaToggleGUI:rebuildRows()
    self:clearRows()

    if self.listContainer == nil or self.rowTemplate == nil then
        stgWarn("rebuildRows aborted: listContainer or rowTemplate is nil")
        return
    end

    self:updatePaginationUi()
    stgSetVisible(self.toggleEmptyText, #self.toggleEntries == 0)

    local startIndex = ((self.currentPage - 1) * self.rowsPerPage) + 1
    local endIndex = math.min(startIndex + self.rowsPerPage - 1, #self.toggleEntries)

    for index = startIndex, endIndex do
        local entry = self.toggleEntries[index]
        local row = self.rowTemplate:clone(self.listContainer)
        row:setVisible(true)

        local refs = stgBuildToggleRowRefs(row)

        stgApplyBitmapTexture(refs.toggleRowBackground, "svapa_card_bg")
        stgApplyBitmapTexture(refs.toggleDescriptionFrame, "svapa_block_white")
        stgApplyBitmapTexture(refs.toggleOptionBackground, "svapa_window_bg")
        stgApplyBitmapTexture(refs.toggleOptionSlider, "svapa_block_white")

        stgSetText(refs.toggleDescriptionText, entry.description or entry.id or "")

        if refs.toggleOption ~= nil then
            if refs.toggleOption.setTexts ~= nil then
                refs.toggleOption:setTexts({"ВЫКЛ.", "ВКЛ."})
            end

            if refs.toggleOption.setIsChecked ~= nil then
                refs.toggleOption:setIsChecked(entry.value == true, true, false)
            end

            if refs.toggleOption.setDisabled ~= nil then
                refs.toggleOption:setDisabled(entry.isDisabled == true)
            else
                stgSetDisabled(refs.toggleOption, entry.isDisabled == true)
            end

            self:bindToggleOption(refs.toggleOption, index, entry)
        end

        table.insert(self.rowClones, row)
    end

    if self.listContainer.invalidateLayout ~= nil then
        self.listContainer:invalidateLayout()
    end
end

function SvapaToggleGUI:onClickPrevPage()
    if self.currentPage > 1 then
        self.currentPage = self.currentPage - 1
        self:rebuildRows()
    end
end

function SvapaToggleGUI:onClickNextPage()
    if self.currentPage < self:getPageCount() then
        self.currentPage = self.currentPage + 1
        self:rebuildRows()
    end
end

function SvapaToggleGUI:onClickToggleState(element, state)
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

    if entry.isDisabled == true then
        stgWarn(string.format("onClickToggleState blocked for disabled entry '%s'", tostring(entry.id)))
        return
    end

    local newValue = nil
    if type(state) == "boolean" then
        newValue = state
    else
        local currentValue = entry.value == true
        newValue = not currentValue
    end

    entry.value = newValue

    if self.trigger ~= nil and self.trigger.manager ~= nil then
        self.trigger.manager:setToggleValue(entry.id, newValue)
        self:refreshToggleEntries()
        self:rebuildRows()
    end
end

function SvapaToggleGUI:onClickScrollUp()
end

function SvapaToggleGUI:onClickScrollDown()
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
