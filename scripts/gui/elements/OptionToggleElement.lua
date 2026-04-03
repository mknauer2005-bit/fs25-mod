-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.



---
OptionToggleElement = {}
local OptionToggleElement_mt = Class(OptionToggleElement, MultiTextOptionElement)




---
function OptionToggleElement.new(target, custom_mt)
    local self = MultiTextOptionElement.new(target, custom_mt or OptionToggleElement_mt)

    self.dataSouce = nil

    return self
end
