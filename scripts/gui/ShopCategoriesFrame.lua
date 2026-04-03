-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.







---Shop categories frame for the in-game menu shop.
-- 
-- Displays categories/brands or purchasable items in a tile-layout.
-- 
-- @category GUI
ShopCategoriesFrame = {}
local ShopCategoriesFrame_mt = Class(ShopCategoriesFrame, TabbedMenuFrameElement)


---Creates an instance of this frame, and loads the associated XML file
function ShopCategoriesFrame.register()
    local shopCategoriesFrame = ShopCategoriesFrame.new()
    g_gui:loadGui("dataS/gui/ShopCategoriesFrame.xml", "ShopCategoriesFrame", shopCategoriesFrame, true)
end
