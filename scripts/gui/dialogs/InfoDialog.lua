-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.









---Basic information dialog with text and confirmation.
-- @category GUI
InfoDialog = {}
local InfoDialog_mt = Class(InfoDialog, MessageDialog)









---
-- @param string text
-- @param function? callback
-- @param table? target
-- @param integer? dialogType one of DialogElement.TYPE_, default DialogElement.TYPE_INFO
-- @param string? okText
-- @param string? buttonAction
-- @param any callbackArgs
-- @param boolean? disableOpenSound
function InfoDialog.show(text, callback, target, dialogType, okText, buttonAction, callbackArgs, disableOpenSound)
    if InfoDialog.INSTANCE ~= nil then
        local dialog = InfoDialog.INSTANCE

        dialog:setCallback(callback, target, callbackArgs)
        dialog:setDialogType(Utils.getNoNil(dialogType, DialogElement.TYPE_INFO))
        dialog:setButtonTexts(okText)
        dialog:setButtonAction(buttonAction)
        dialog:setText(text)
        dialog:setDisableOpenSound(disableOpenSound)

        g_gui:showDialog("InfoDialog")
    end
end



































































































































---
function InfoDialog:inputEvent(action, value, eventUsed)
    eventUsed = InfoDialog:superClass().inputEvent(self, action, value, eventUsed)

    if Platform.isAndroid and self.inputDisableTime <= 0 then
        if action == InputAction.MENU_BACK then
            self:onClickOk()

            -- always consume event to avoid triggering any other focused elements
            eventUsed = true
        end
    end

    return eventUsed
end
