-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.












---
ManureSensorLinkageData = {}
local ManureSensorLinkageData_mt = Class(ManureSensorLinkageData)



















---
function ManureSensorLinkageData:delete()
    for i=1, #self.sensorData do
        delete(self.sensorData[i].node)
    end

    self.sensorData = {}
    self.linkageData = {}
end



---
function ManureSensorLinkageData:loadFromXML(_, _, baseDirectory, configFileName, mapFilename)
    if not self.dataLoaded then
        self:loadLinkageData()
    end
end


---
function ManureSensorLinkageData:loadLinkageData(loadVehicleData, loadSensorData)
    local filename = Utils.getFilename("ManureSensorLinkageData.xml", ManureSensorLinkageData.BASE_DIRECTORY)

    local xmlFile = XMLFile.load("ManureSensorLinkageData", filename, ManureSensorLinkageData.xmlSchema)
    if xmlFile ~= nil then
        self.configurationPrice = xmlFile:getValue("manureSensorLinkageData.configuration#price", 0)

        if loadVehicleData ~= false then
            self.linkageData = {}
            xmlFile:iterate("manureSensorLinkageData.vehicles.vehicle", function(index, key)
                local vehicleData = {}
                vehicleData.filename = xmlFile:getValue(key .. "#filename")
                if vehicleData.filename ~= nil then
                    vehicleData.linkNodes = {}

                    xmlFile:iterate(key .. ".linkNode", function(_, linkNodeKey)
                        local linkNode = {}
                        linkNode.nodeName = xmlFile:getValue(linkNodeKey .. "#node")
                        linkNode.typeName = string.upper(xmlFile:getValue(linkNodeKey .. "#type", "DEFAULT"))
                        linkNode.translation = xmlFile:getValue(linkNodeKey .. "#translation", "0 0 0", true)
                        linkNode.rotation = xmlFile:getValue(linkNodeKey .. "#rotation", "0 0 0", true)
                        linkNode.scale = xmlFile:getValue(linkNodeKey .. "#scale", nil, true)

                        table.insert(vehicleData.linkNodes, linkNode)
                    end)
                end

                table.insert(self.linkageData, vehicleData)
            end)
        end

        if loadSensorData ~= false then
            local sensorsFilename = xmlFile:getValue("manureSensorLinkageData.sensors#filename")
            if sensorsFilename ~= nil then
                sensorsFilename = Utils.getFilename(sensorsFilename, ManureSensorLinkageData.BASE_DIRECTORY)
                g_i3DManager:loadI3DFileAsync(sensorsFilename, true, true, ManureSensorLinkageData.onSensorDataLoaded, self, {xmlFile})
            else
                xmlFile:delete()
            end
        else
            xmlFile:delete()
        end
    end

    self.dataLoaded = true

    return true
end


---
function ManureSensorLinkageData:onSensorDataLoaded(i3dNode, failedReason, args)
    local xmlFile = unpack(args)
    if i3dNode ~= 0 then
        xmlFile:iterate("manureSensorLinkageData.sensors.sensor", function(index, key)
            local sensorData = {}
            sensorData.node = xmlFile:getValue(key .. "#node", nil, i3dNode)
            if sensorData.node ~= nil then
                sensorData.type = xmlFile:getValue(key .. "#type", "DEFAULT")

                table.insert(self.sensorData, sensorData)
            end
        end)

        for i=1, #self.sensorData do
            unlink(self.sensorData[i].node)
        end

        delete(i3dNode)
    end

    xmlFile:delete()
end


---
function ManureSensorLinkageData:getManureSensorLinkageData(configFileName)
    if configFileName ~= nil then
        for i=1, #self.linkageData do
            local vehicleData = self.linkageData[i]
            if string.endsWith(configFileName, vehicleData.filename) then
                return vehicleData
            end
        end
    end

    return nil
end


---
function ManureSensorLinkageData:getClonedManureSensorNode(typeName)
    for i=1, #self.sensorData do
        local sensorData = self.sensorData[i]
        if string.upper(sensorData.type) == string.upper(typeName) then
            local clonedData = table.clone(sensorData, 10)
            clonedData.node = clone(sensorData.node, false, false, false)
            setTranslation(clonedData.node, 0, 0, 0)
            setRotation(clonedData.node, 0, 0, 0)
            setScale(clonedData.node, 1, 1, 1)

            return clonedData
        end
    end

    return nil
end


---
function ManureSensorLinkageData:overwriteGameFunctions(pfModule)
    -- Reload linkage data while reloading vehicles to get the latest data
    pfModule:overwriteGameFunction(VehicleSystem, "consoleCommandReloadVehicle", function(superFunc, vehicleSystem, resetVehicle, radius)
        self:loadLinkageData(true, false)

        return superFunc(vehicleSystem, resetVehicle, radius)
    end)

    pfModule:overwriteGameFunction(ConfigurationUtil, "getConfigurationsFromXML", function(superFunc, manager, xmlFile, key, baseDir, customEnvironment, isMod, storeItem)
        local configurations, defaultConfigurationIds = superFunc(manager, xmlFile, key, baseDir, customEnvironment, isMod, storeItem)

        if not self.dataLoaded then
            self:loadLinkageData(true)
        end
        local vehicleData = self:getManureSensorLinkageData(xmlFile.filename)
        if vehicleData ~= nil then
            if configurations == nil then
                configurations = {}
            end

            if defaultConfigurationIds == nil then
                defaultConfigurationIds = {}
            end

            local configurationItems = {}

            local configItem1 = VehicleConfigurationItem.new("manureSensor")
            configItem1.isDefault = true
            configItem1.name = g_i18n:getText("configuration_valueNo")
            configItem1.index = 1
            configItem1.saveId = "1"
            configItem1.price = 0
            configItem1.isYesNoOption = true
            table.insert(configurationItems, configItem1)

            local configItem2 = VehicleConfigurationItem.new("manureSensor")
            configItem2.name = g_i18n:getText("configuration_valueYes")
            configItem2.index = 2
            configItem2.saveId = "2"
            configItem2.price = self.configurationPrice
            configItem2.isYesNoOption = true
            table.insert(configurationItems, configItem2)

            defaultConfigurationIds["manureSensor"] = ConfigurationUtil.getDefaultConfigIdFromItems(configurationItems)
            configurations["manureSensor"] = configurationItems
        end

        return configurations, defaultConfigurationIds
    end)
end


---
function ManureSensorLinkageData:registerXMLPaths(schema)
    schema:register(XMLValueType.STRING, "manureSensorLinkageData.sensors#filename", "Link to i3d filename containing the sensors")
    schema:register(XMLValueType.STRING, "manureSensorLinkageData.sensors.sensor(?)#type", "Type of sensor (DEFAULT)")
    schema:register(XMLValueType.NODE_INDEX, "manureSensorLinkageData.sensors.sensor(?)#node", "Path to sensor node")

    schema:register(XMLValueType.STRING, "manureSensorLinkageData.vehicles.vehicle(?)#filename", "Last part of vehicle filename")
    schema:register(XMLValueType.STRING, "manureSensorLinkageData.vehicles.vehicle(?).linkNode(?)#node", "Name of node in i3d mapping")
    schema:register(XMLValueType.STRING, "manureSensorLinkageData.vehicles.vehicle(?).linkNode(?)#type", "Type of node to link (DEFAULT)")
    schema:register(XMLValueType.VECTOR_TRANS, "manureSensorLinkageData.vehicles.vehicle(?).linkNode(?)#translation", "Translation offset from node", "0 0 0")
    schema:register(XMLValueType.VECTOR_ROT, "manureSensorLinkageData.vehicles.vehicle(?).linkNode(?)#rotation", "Rotation offset from node", "0 0 0")
    schema:register(XMLValueType.VECTOR_SCALE, "manureSensorLinkageData.vehicles.vehicle(?).linkNode(?)#scale", "Scale of sensor node", "1 1 1")

    schema:register(XMLValueType.FLOAT, "manureSensorLinkageData.configuration#price", "Price of crop sensor config", 0)
end
