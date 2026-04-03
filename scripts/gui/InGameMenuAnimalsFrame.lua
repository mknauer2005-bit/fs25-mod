-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---In-game menu animals statistics frame.
-- 
-- Displays information for all owned animal pens and horses.
-- 
-- @category GUI
InGameMenuAnimalsFrame = {}
local InGameMenuAnimalsFrame_mt = Class(InGameMenuAnimalsFrame, TabbedMenuFrameElement)






















































---
function InGameMenuAnimalsFrame:delete()
    for k, clone in pairs(self.subCategoryDotBox.elements) do
        clone:delete()
        self.subCategoryDotBox.elements[k] = nil
    end

    self.subCategoryDotTemplate:delete()

    InGameMenuAnimalsFrame:superClass().delete(self)
end
