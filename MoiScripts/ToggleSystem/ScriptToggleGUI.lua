SvapaScriptToggleGUI = {}
local SvapaScriptToggleGUI_mt = Class(SvapaScriptToggleGUI, ScreenElement)

local SVAPA_TOGGLE_DEBUG = true

local function debugConcat(...)
    local values = {...}
    local parts = {}

    for i = 1, #values do
        parts[i] = tostring(values[i])
    end

    return table.concat(parts, " ")
end

local function debugPrint(...)
    if SVAPA_TOGGLE_DEBUG then
        print("[SVAPA_TOGGLE] " .. debugConcat(...))
    end
end

local function debugWarning(...)
    if SVAPA_TOGGLE_DEBUG then
        print("[SVAPA_TOGGLE][WARN] " .. debugConcat(...))
    end
end

SvapaScriptToggleGUI.CONTROLS = {
    "titleElement",
    "listContainer",
    "rowTemplate",
    "applyButton",
    "exitButton"
}

function SvapaScriptToggleGUI.new(target, customMt)
    local self = ScreenElement.new(target, customMt or SvapaScriptToggleGUI_mt)
    self:registerControls(SvapaScriptToggleGUI.CONTROLS)

    self.openReason = "manual"
    self.rows = {}

    return self
end

function SvapaScriptToggleGUI:onCreate()
    SvapaScriptToggleGUI:superClass().onCreate(self)
    self.rowTemplate:unlinkElement()
    debugPrint("GUI onCreate completed")
end

function SvapaScriptToggleGUI:setOpenReason(reason)
    self.openReason = reason or "manual"
end

function SvapaScriptToggleGUI:onOpen()
    SvapaScriptToggleGUI:superClass().onOpen(self)

    self:rebuildRows()

    if self.openReason == "firstCareerStart" then
        self.titleElement:setText(g_i18n:getText("ui_svapa_toggle_title_firstStart"))
        debugPrint("GUI opened for firstCareerStart")
    else
        self.titleElement:setText(g_i18n:getText("ui_svapa_toggle_title"))
        debugPrint("GUI opened. reason=", self.openReason)
    end
end

function SvapaScriptToggleGUI:onClickApply()
    local manager = g_currentMission ~= nil and g_currentMission.svapaScriptToggleManager or nil
    if manager == nil then
        debugWarning("onClickApply ignored: manager missing")
        return
    end

    local states = {}

    for featureName, rowData in pairs(self.rows) do
        states[featureName] = rowData.option:getIsChecked()
    end

    debugPrint("GUI submit. reason=", self.openReason)
    manager:onPlayerSubmitSettings(states, manager.currentPreset)
    g_gui:changeScreen(nil)
    debugPrint("GUI closed after Apply")
end

function SvapaScriptToggleGUI:onClickExit()
    if self.openReason == "firstCareerStart" then
        debugWarning("Exit blocked on firstCareerStart")
        return
    end

    debugPrint("GUI exit clicked. reason=", self.openReason)
    g_gui:changeScreen(nil)
    debugPrint("GUI closed after Exit")
end

function SvapaScriptToggleGUI:onClickBack(forceBack, usedMenuButton)
    debugPrint("GUI onClickBack. reason=", self.openReason, "forceBack=", forceBack, "usedMenuButton=", usedMenuButton)
    self:onClickExit()
end

function SvapaScriptToggleGUI:rebuildRows()
    local manager = g_currentMission ~= nil and g_currentMission.svapaScriptToggleManager or nil
    if manager == nil then
        debugWarning("rebuildRows aborted: manager missing")
        return
    end

    for _, data in pairs(self.rows) do
        data.element:delete()
    end

    self.rows = {}

    local features = manager:getFeaturesForUI()
    for _, feature in ipairs(features) do
        local row = self.rowTemplate:clone(self.listContainer)
        row:setVisible(true)

        local optionElement = row:getDescendantByName("toggleOption")
        local textElement = row:getDescendantByName("toggleDescription")

        optionElement:setIsChecked(feature.enabled)
        optionElement:setTexts({ g_i18n:getText("ui_off"), g_i18n:getText("ui_on") })
        textElement:setText(g_i18n:getText(feature.descriptionTextKey))

        self.rows[feature.name] = {
            element = row,
            option = optionElement
        }
    end

    self.listContainer:invalidateLayout()
    debugPrint("GUI rows rebuilt. count=", #features)
end
