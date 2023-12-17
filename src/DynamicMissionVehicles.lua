DynamicMissionVehicles = {
    variants = {},
    modName = g_currentModName,
    fallback_missionVehicles = g_currentModName .. "/xml/missionVehicles.xml",
	modsToIgnoreMissionVehicles = {
		"FS22_precisionFarming"
	}
}

addModEventListener(DynamicMissionVehicles)

function DynamicMissionVehicles:loadMapData(xmlFile)
	local path = getXMLString(xmlFile, "map.missionVehicles#filename")

	if path ~= nil then
		path = Utils.getFilename(path, g_currentMission.missionInfo.baseDirectory)

		if path ~= nil then
			DynamicMissionVehicles:loadVariants(path)
        else
            DynamicMissionVehicles:loadVariants(DynamicMissionVehicles.fallback_missionVehicles)
		end
	end
end

function DynamicMissionVehicles:loadVariants(xmlFilename)
	local xmlFile = XMLFile.load("MissionVehicles", xmlFilename)

    if not xmlFile then
		Logging.xmlError(xmlFilename, "File could not be opened")

		return false
	end

    local key = "missionVehicles.variants"

    if not xmlFile:hasProperty(key) then
        xmlFile = XMLFile.load("MissionVehicles", g_modsDirectory .. self.fallback_missionVehicles)
    end

    local i = 0

    while true do
        local newKey = string.format(key .. ".mission(%d)", i)

        if not xmlFile:hasProperty(newKey) then
            break
        end

        local type = xmlFile:getString(newKey .. "#type")

        if type ~= nil then
            DynamicMissionVehicles.variants[type] = {}
        end

        local j = 0

        while true do
            local combinedKey = string.format(newKey .. ".variant(%d)", j)

            if not xmlFile:hasProperty(combinedKey) then
                break
            end

            local name = xmlFile:getString(combinedKey .. "#name")
            local fruitTypeCategories = xmlFile:getString(combinedKey .. "#fruitTypeCategories")
            local fruitTypeNames = xmlFile:getString(combinedKey .. "#fruitTypes")
            local fruitTypes = nil

            if fruitTypeCategories == nil and fruitTypeNames ~= nil then
                fruitTypes = g_fruitTypeManager:getFruitTypesByNames(fruitTypeNames, "Warning: '" .. tostring(combinedKey) .. "' has invalid fruitType '%s'.")
            elseif fruitTypeCategories ~= nil and fruitTypeNames == nil then
                fruitTypes = g_fruitTypeManager:getFruitTypesByCategoryNames(fruitTypeCategories, "Warning: '" .. tostring(combinedKey) .. "' has invalid fruitTypeCategory '%s'.")
            elseif fruitTypeCategories ~= nil and fruitTypeNames ~= nil then
                local t1 = g_fruitTypeManager:getFruitTypesByNames(fruitTypeNames, "Warning: '" .. tostring(combinedKey) .. "' has invalid fruitType '%s'.")
                local t2 = g_fruitTypeManager:getFruitTypesByCategoryNames(fruitTypeCategories, "Warning: '" .. tostring(combinedKey) .. "' has invalid fruitTypeCategory '%s'.")
                fruitTypes = table.combine(t1, t2)
            end

            for _, fruitType in pairs(fruitTypes) do
				DynamicMissionVehicles.variants[type][fruitType] = name
            end

            j = j + 1
        end

        i = i + 1
    end

	self:activateMissions()
end

function DynamicMissionVehicles:activateMissions()
	local fruitTypes = g_fruitTypeManager:getFruitTypes()

	for _, fruitType in ipairs(fruitTypes) do
		local activateMission = true

		for type, _ in pairs(DynamicMissionVehicles.variants) do
			if DynamicMissionVehicles.variants[type][fruitType.index] == nil then
				activateMission = false
				break
			end
		end

		if activateMission then
			Logging.info("Activate mission for %s", fruitType.name)
			fruitType.useForFieldJob = true
		else
			Logging.info("Deactivate mission for %s", fruitType.name)
			fruitType.useForFieldJob = false
		end
	end
end

function DynamicMissionVehicles:loadMissionVehicles(superFunc, xmlFilename, ...)
    local xmlFile = XMLFile.load("MissionVehicles", xmlFilename)

    if not xmlFile then
		Logging.xmlError(xmlFilename, "File could not be opened")

		return false
	end

	local _, _, isDLC, _ = Utils.removeModDirectory(xmlFilename)
	local modName, _ = Utils.getModNameAndBaseDirectory(xmlFilename)
	if isDLC then
		Logging.info("Load mission vehicles from DLC")
		return superFunc(self, xmlFilename, ...)
	end

    if xmlFile:hasProperty("missionVehicles.variants") or DynamicMissionVehicles.shouldModBeIgnored(modName) then
		return DynamicMissionVehicles.loadVehicles(self, xmlFilename)
    else
		Logging.info("%s has no variants defined. Loading Backup instead.", xmlFilename)
		local path = Utils.getFilename(DynamicMissionVehicles.fallback_missionVehicles, g_modsDirectory)
        return DynamicMissionVehicles.loadVehicles(self, path, g_modsDirectory)
    end
end

function DynamicMissionVehicles:loadVehicles(xmlFilename, baseDirectory)
    local xmlFile = loadXMLFile("MissionVehicles", xmlFilename)

	if xmlFile == 0 then
		return false
	end

	local i = 0

	while true do
		local key = string.format("missionVehicles.mission(%d)", i)

		if not hasXMLProperty(xmlFile, key) then
			break
		end

		local type = getXMLString(xmlFile, key .. "#type")

		if type == nil then
			Logging.error("(%s) Property type must exist on each mission", xmlFilename)
			delete(xmlFile)

			return false
		end

		local groups = {}
		local j = 0

		while true do
			local groupKey = string.format("%s.group(%d)", key, j)

			if not hasXMLProperty(xmlFile, groupKey) then
				break
			end

			local fieldSize = Utils.getNoNil(getXMLString(xmlFile, groupKey .. "#fieldSize"), "MEDIUM")
			local rewardScale = Utils.getNoNil(getXMLFloat(xmlFile, groupKey .. "#rewardScale"), 1)
			local vehicles = {}
			local group = {
				rewardScale = rewardScale,
				vehicles = vehicles,
				variant = getXMLString(xmlFile, groupKey .. "#variant")
			}
			local k = 0

			while true do
				::continue::
				local vehicleKey = string.format("%s.vehicle(%d)", groupKey, k)

				if not hasXMLProperty(xmlFile, vehicleKey) then
					break
				end

				local filename = getXMLString(xmlFile, vehicleKey .. "#filename")
				local modName = getXMLString(xmlFile, vehicleKey .. "#modName")

				if modName ~= nil and modName ~= "" then
					filename = modName .. "/" .. filename
				end

				if (modName == nil or modName == "") and not filename:startsWith("$") then
					Logging.Warning("Cannot load missionVehicle that is neither part of the baseGame nor part of a mod.")
					k = k + 1
					goto continue
				end

				filename = Utils.getFilename(filename, baseDirectory or g_modsDirectory)

				if filename == nil then
					Logging.error("(%s) Property filename must exist on each vehicle", xmlFilename)
				else
					if filename:split("/")[1] == "pdlc" then
						filename = getAppBasePath() .. filename
					end
					local storeItem = g_storeManager:getItemByXMLFilename(filename)

					if storeItem == nil then
						Logging.error("%s: Unable to load store item for '%s'", xmlFilename, filename)
					else
						local configurations = {}
						local p = 0

						while true do
							local configKey = string.format("%s.configuration(%d)", vehicleKey, p)

							if not hasXMLProperty(xmlFile, configKey) then
								break
							end

							local name = getXMLString(xmlFile, configKey .. "#name")
							local id = getXMLInt(xmlFile, configKey .. "#id")

							if name ~= nil and id ~= nil then
								configurations[name] = id
							end

							p = p + 1
						end

						table.insert(vehicles, {
							filename = filename,
							configurations = configurations
						})
					end
				end

				k = k + 1
			end

			if groups[fieldSize] == nil then
				groups[fieldSize] = {}
			end

			table.insert(groups[fieldSize], group)

			group.identifier = table.getn(groups[fieldSize])
			j = j + 1
		end

		self.missionVehicles[type] = groups
		i = i + 1
	end

	delete(xmlFile)

	return true
end

function DynamicMissionVehicles:getVehicleVariant(superFunc)
    local fruitType = nil

	if self.type.name == "harvest" then
		fruitType = self.field.fruitType
	elseif self.type.name == "sow"  then
		fruitType = self.fruitType
	else
		Logging.devWarning("MissionType is not supported by DynamicMissionVehicles")
		return superFunc(self)
	end

	if DynamicMissionVehicles.variants[self.type.name][fruitType] ~= nil then
        return DynamicMissionVehicles.variants[self.type.name][fruitType]
    else
        return superFunc(self)
    end
end

MissionManager.loadMapData = Utils.appendedFunction(MissionManager.loadMapData, DynamicMissionVehicles.loadMapData)
MissionManager.loadMissionVehicles = Utils.overwrittenFunction(MissionManager.loadMissionVehicles, DynamicMissionVehicles.loadMissionVehicles)
-- supported missionTypes
HarvestMission.getVehicleVariant = Utils.overwrittenFunction(HarvestMission.getVehicleVariant, DynamicMissionVehicles.getVehicleVariant)
SowMission.getVehicleVariant = Utils.overwrittenFunction(SowMission.getVehicleVariant, DynamicMissionVehicles.getVehicleVariant)

function DynamicMissionVehicles.shouldModBeIgnored(modName)
	for _, modToIgnore in pairs(DynamicMissionVehicles.modsToIgnoreMissionVehicles) do
		if modToIgnore == modName then
			return true
		end
	end

	return false
end

function table.combine(t1, t2)
    local t = {}

    for _, v in pairs(t1) do
        table.insert(t,v)
    end
    for _, v in pairs(t2) do
        table.insert(t,v)
    end

    return t
end