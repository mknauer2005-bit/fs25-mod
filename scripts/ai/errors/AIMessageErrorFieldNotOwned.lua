-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.








---
AIMessageErrorFieldNotOwned = {}
local AIMessageErrorFieldNotOwned_mt = Class(AIMessageErrorFieldNotOwned, AIMessage)


---
function AIMessageErrorFieldNotOwned.new(customMt)
    local self = AIMessage.new(customMt or AIMessageErrorFieldNotOwned_mt)
    return self
end


---
function AIMessageErrorFieldNotOwned:getI18NText()
    return g_i18n:getText("ai_messageErrorFieldNotOwned")
end
