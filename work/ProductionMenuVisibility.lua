ProductionMenuVisibility = {}

ProductionMenuVisibility.XML_ATTRIBUTE = "#showInProductionMenu"
ProductionMenuVisibility.DEFAULT_VISIBLE = true
ProductionMenuVisibility.DEBUG = false

function ProductionMenuVisibility.log(message, ...)
    if not ProductionMenuVisibility.DEBUG then
        return
    end

    print(string.format("[ProductionMenuVisibility] " .. tostring(message), ...))
end

function ProductionMenuVisibility.getPlaceableDebugName(placeable)
    if placeable == nil then
        return "nil"
    end

    if placeable.getName ~= nil then
        local ok, name = pcall(function()
            return placeable:getName()
        end)

        if ok and name ~= nil and name ~= "" then
            return tostring(name)
        end
    end

    if placeable.configFileName ~= nil and placeable.configFileName ~= "" then
        return tostring(placeable.configFileName)
    end

    if placeable.xmlFilename ~= nil and placeable.xmlFilename ~= "" then
        return tostring(placeable.xmlFilename)
    end

    return tostring(placeable)
end

function ProductionMenuVisibility.getProductionPointDebugName(productionPoint)
    if productionPoint == nil then
        return "nil"
    end

    if productionPoint.owningPlaceable ~= nil then
        return ProductionMenuVisibility.getPlaceableDebugName(productionPoint.owningPlaceable)
    end

    return tostring(productionPoint)
end

function ProductionMenuVisibility.getConfiguredProductionPointKey(placeable)
    if placeable == nil then
        return nil
    end

    if placeable.spec_productionPoint ~= nil and placeable.configurations ~= nil then
        local productionPointConfigurationId = Utils.getNoNil(placeable.configurations["productionPoint"], 1)
        if productionPointConfigurationId > 1 then
            return string.format("placeable.productionPoint.productionPointConfigurations.productionPointConfiguration(%d).productionPoint", productionPointConfigurationId - 1)
        end
    end

    return "placeable.productionPoint"
end

function ProductionMenuVisibility.readShowInProductionMenuFlag(productionPoint)
    if productionPoint == nil or productionPoint.owningPlaceable == nil then
        return ProductionMenuVisibility.DEFAULT_VISIBLE
    end

    local placeable = productionPoint.owningPlaceable
    local xmlFile = placeable.xmlFile
    if xmlFile == nil then
        return ProductionMenuVisibility.DEFAULT_VISIBLE
    end

    local key = ProductionMenuVisibility.getConfiguredProductionPointKey(placeable)
    if key ~= nil and xmlFile:hasProperty(key) then
        return xmlFile:getValue(key .. ProductionMenuVisibility.XML_ATTRIBUTE, ProductionMenuVisibility.DEFAULT_VISIBLE)
    end

    return ProductionMenuVisibility.DEFAULT_VISIBLE
end

function ProductionMenuVisibility.applyFlag(productionPoint)
    if productionPoint ~= nil then
        productionPoint.showInProductionMenu = ProductionMenuVisibility.readShowInProductionMenuFlag(productionPoint)

        ProductionMenuVisibility.log(
            "applyFlag placeable='%s' visible=%s",
            tostring(ProductionMenuVisibility.getProductionPointDebugName(productionPoint)),
            tostring(productionPoint.showInProductionMenu)
        )
    else
        ProductionMenuVisibility.log("applyFlag called with nil productionPoint")
    end
end

function ProductionMenuVisibility.registerXMLPaths(xmlSchema, basePath)
    xmlSchema:register(
        XMLValueType.BOOL,
        basePath .. ".productionPoint" .. ProductionMenuVisibility.XML_ATTRIBUTE,
        "Show production point in vanilla production menu",
        ProductionMenuVisibility.DEFAULT_VISIBLE
    )

    xmlSchema:register(
        XMLValueType.BOOL,
        basePath .. ".productionPoint.productionPointConfigurations.productionPointConfiguration(?).productionPoint" .. ProductionMenuVisibility.XML_ATTRIBUTE,
        "Show production point in vanilla production menu",
        ProductionMenuVisibility.DEFAULT_VISIBLE
    )
end

function ProductionMenuVisibility.onLoadPlaceableProductionPoint(placeable, superFunc, savegame)
    superFunc(placeable, savegame)

    local spec = placeable.spec_productionPoint
    if spec ~= nil and spec.productionPoint ~= nil then
        ProductionMenuVisibility.applyFlag(spec.productionPoint)
    else
        ProductionMenuVisibility.log(
            "onLoadPlaceableProductionPoint no productionPoint for placeable='%s'",
            tostring(ProductionMenuVisibility.getPlaceableDebugName(placeable))
        )
    end
end

function ProductionMenuVisibility.addProductionPoint(productionChainManager, superFunc, productionPoint)
    ProductionMenuVisibility.applyFlag(productionPoint)

    ProductionMenuVisibility.log(
        "addProductionPoint placeable='%s' visible=%s",
        tostring(ProductionMenuVisibility.getProductionPointDebugName(productionPoint)),
        tostring(productionPoint ~= nil and productionPoint.showInProductionMenu or "nil")
    )

    return superFunc(productionChainManager, productionPoint)
end

function ProductionMenuVisibility.getProductionPointsForFarmId(productionChainManager, superFunc, farmId)
    local productionPoints = superFunc(productionChainManager, farmId)

    ProductionMenuVisibility.log(
        "getProductionPointsForFarmId called farmId=%s count=%s",
        tostring(farmId),
        tostring(productionPoints ~= nil and #productionPoints or "nil")
    )

    if productionPoints == nil or #productionPoints == 0 then
        return productionPoints
    end

    local filtered = nil

    for i = 1, #productionPoints do
        local productionPoint = productionPoints[i]
        local isVisible = productionPoint == nil or productionPoint.showInProductionMenu ~= false

        ProductionMenuVisibility.log(
            "candidate index=%s placeable='%s' visible=%s",
            tostring(i),
            tostring(ProductionMenuVisibility.getProductionPointDebugName(productionPoint)),
            tostring(productionPoint ~= nil and productionPoint.showInProductionMenu or "nil")
        )

        if isVisible then
            if filtered ~= nil then
                table.insert(filtered, productionPoint)
            end
        elseif filtered == nil then
            filtered = {}

            for n = 1, i - 1 do
                table.insert(filtered, productionPoints[n])
            end
        end
    end

    ProductionMenuVisibility.log(
        "getProductionPointsForFarmId resultCount=%s",
        tostring(filtered ~= nil and #filtered or #productionPoints)
    )

    return filtered or productionPoints
end

function ProductionMenuVisibility.install()
    if PlaceableProductionPoint ~= nil then
        PlaceableProductionPoint.registerXMLPaths = Utils.appendedFunction(
            PlaceableProductionPoint.registerXMLPaths,
            ProductionMenuVisibility.registerXMLPaths
        )

        PlaceableProductionPoint.onLoad = Utils.overwrittenFunction(
            PlaceableProductionPoint.onLoad,
            ProductionMenuVisibility.onLoadPlaceableProductionPoint
        )

        ProductionMenuVisibility.log("hooked PlaceableProductionPoint")
    else
        ProductionMenuVisibility.log("PlaceableProductionPoint is nil")
    end

    if ProductionChainManager ~= nil then
        ProductionChainManager.addProductionPoint = Utils.overwrittenFunction(
            ProductionChainManager.addProductionPoint,
            ProductionMenuVisibility.addProductionPoint
        )

        ProductionChainManager.getProductionPointsForFarmId = Utils.overwrittenFunction(
            ProductionChainManager.getProductionPointsForFarmId,
            ProductionMenuVisibility.getProductionPointsForFarmId
        )

        ProductionMenuVisibility.log("hooked ProductionChainManager")
    else
        ProductionMenuVisibility.log("ProductionChainManager is nil")
    end
end

ProductionMenuVisibility.install()