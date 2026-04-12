-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---
HumanGraphicsComponentState = {}
local HumanGraphicsComponentState_mt = Class(HumanGraphicsComponentState)


---Creating manager
-- @return table instance instance of object
function HumanGraphicsComponentState.new(customMt)
    local self = setmetatable({}, customMt or HumanGraphicsComponentState_mt)

    self:setDefault()

    return self
end
