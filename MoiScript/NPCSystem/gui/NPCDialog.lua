NPCDialog = {}
local NPCDialog_mt = Class(NPCDialog)

function NPCDialog.new(npcSystem)
    local self = setmetatable({}, NPCDialog_mt)

    self.npcSystem = npcSystem
    self.currentPayload = nil

    self.dialogs = {
        main = nil,
        confirm = nil,
        info = nil
    }

    return self
end

function NPCDialog:load(guiDirectory)
    local baseDirectory = guiDirectory
    if baseDirectory == nil or baseDirectory == "" then
        baseDirectory = "scripts/NPCSystem/gui/"
    end

    self.dialogs.main = g_gui:loadGui(baseDirectory .. "NPCDialog.xml", "NPCDialogScreen", self)
    self.dialogs.confirm = g_gui:loadGui(baseDirectory .. "NPCConfirmDialog.xml", "NPCConfirmDialogScreen", self)
    self.dialogs.info = g_gui:loadGui(baseDirectory .. "NPCInfoDialog.xml", "NPCInfoDialogScreen", self)
end

function NPCDialog:showDialog(payload)
    self.currentPayload = payload
    if payload == nil then
        return false
    end

    if payload.mode == "confirm" then
        return self:openDialog(self.dialogs.confirm)
    elseif payload.mode == "info" then
        return self:openDialog(self.dialogs.info)
    end

    return self:openDialog(self.dialogs.main)
end

function NPCDialog:openDialog(dialog)
    if dialog == nil then
        return false
    end

    g_gui:showDialog(dialog)
    return true
end

function NPCDialog:onClickAction(actionId)
    if self.currentPayload == nil or self.npcSystem == nil then
        return
    end

    if actionId == nil or actionId == "" then
        actionId = "close"
    end

    self.npcSystem:onDialogAction(self.currentPayload.npcId, actionId, self.currentPayload.context)
end

function NPCDialog:onClickConfirmYes()
    if self.currentPayload == nil then
        return
    end

    local actionId = self.currentPayload.nextAction or "confirmExternalAction"
    self:onClickAction(actionId)
end

function NPCDialog:onClickConfirmNo()
    self:onClickAction("close")
end

function NPCDialog:onClickClose()
    self:onClickAction("close")
end

function NPCDialog:delete()
    self.currentPayload = nil
    self.dialogs = {
        main = nil,
        confirm = nil,
        info = nil
    }
end
