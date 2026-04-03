-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.








---
AIMessageErrorOutOfFuel = {}
local AIMessageErrorOutOfFuel_mt = Class(AIMessageErrorOutOfFuel, AIMessage)


---
function AIMessageErrorOutOfFuel.new(customMt)
    local self = AIMessage.new(customMt or AIMessageErrorOutOfFuel_mt)
    return self
end


---
function AIMessageErrorOutOfFuel:getI18NText()
    return g_i18n:getText("ai_messageErrorOutOfFuel")
end
