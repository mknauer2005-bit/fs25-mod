-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.








---
AIMessageErrorBlockedByObject = {}
local AIMessageErrorBlockedByObject_mt = Class(AIMessageErrorBlockedByObject, AIMessage)


---
function AIMessageErrorBlockedByObject.new(customMt)
    local self = AIMessage.new(customMt or AIMessageErrorBlockedByObject_mt)
    return self
end
