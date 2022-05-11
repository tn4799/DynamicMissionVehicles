
FruitPreparerMultiFruit = {}
FruitPreparerMultiFruit.modDir = g_currentModDirectory
FruitPreparerMultiFruit.modName = g_currentModName

function FruitPreparerMultiFruit.initSpecialization()
	g_workAreaTypeManager:addWorkAreaType("fruitPreparer", false)
end

function FruitPreparerMultiFruit.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(WorkArea, specializations) and SpecializationUtil.hasSpecialization(TurnOnVehicle, specializations)
end

function FruitPreparerMultiFruit.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "onFieldDataUpdateFinished", FruitPreparerMultiFruit.onFieldDataUpdateFinished)
	SpecializationUtil.registerFunction(vehicleType, "processFruitPreparerArea", FruitPreparerMultiFruit.processFruitPreparerArea)
end

function FruitPreparerMultiFruit.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadWorkAreaFromXML",					FruitPreparerMultiFruit.loadWorkAreaFromXML)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDoGroundManipulation",				FruitPreparerMultiFruit.getDoGroundManipulation)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "doCheckSpeedLimit",					FruitPreparerMultiFruit.doCheckSpeedLimit)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAllowCutterAIFruitRequirements",	FruitPreparerMultiFruit.getAllowCutterAIFruitRequirements)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDirtMultiplier",					FruitPreparerMultiFruit.getDirtMultiplier)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getWearMultiplier",					FruitPreparerMultiFruit.getWearMultiplier)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "loadRandomlyMovingPartFromXML", 		FruitPreparerMultiFruit.loadRandomlyMovingPartFromXML)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsRandomlyMovingPartActive",		FruitPreparerMultiFruit.getIsRandomlyMovingPartActive)
end

function FruitPreparerMultiFruit.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", FruitPreparerMultiFruit)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", FruitPreparerMultiFruit)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", FruitPreparerMultiFruit)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", FruitPreparerMultiFruit)
	SpecializationUtil.registerEventListener(vehicleType, "onTurnedOn", FruitPreparerMultiFruit)
	SpecializationUtil.registerEventListener(vehicleType, "onTurnedOff", FruitPreparerMultiFruit)
	SpecializationUtil.registerEventListener(vehicleType, "onStartWorkAreaProcessing", FruitPreparerMultiFruit)
end

function FruitPreparerMultiFruit:onLoad(savegame)
	local spec = self["spec_" .. FruitPreparerMultiFruit.modName .. ".FruitPreparerMultiFruit"]
	local key = "vehicle.fruitPreparer"

	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, self.configFileName, "vehicle.turnOnAnimation#name", "vehicle.turnOnVehicle.turnedAnimation#name") -- FS15 to FS17
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, self.configFileName, "vehicle.turnOnAnimation#speed", "vehicle.turnOnVehicle.turnedAnimation#turnOnSpeedScale") -- FS15 to FS17
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, self.configFileName, key .. "#useReelStateToTurnOn") -- FS17 to FS19
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, self.configFileName, key .. "#onlyActiveWhenLowered") -- FS17 to FS19
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, self.configFileName, "vehicle.vehicle.fruitPreparerSound", "vehicle.fruitPreparer.sounds.work") -- FS17 to FS19
	XMLUtil.checkDeprecatedXMLElements(self.xmlFile, self.configFileName, "vehicle.turnedOnRotationNodes.turnedOnRotationNode", "vehicle.fruitPreparer.animationNodes.animationNode", "fruitPreparer") -- FS17 to FS19

	if self.isClient then
		spec.samples = {}
		spec.samples.work = g_soundManager:loadSampleFromXML(self.xmlFile, key .. ".sounds", "work", self.baseDirectory, self.components, 0, AudioGroup.VEHICLE, self.i3dMappings, self)
		spec.animationNodes = g_animationManager:loadAnimations(self.xmlFile, key .. ".animationNodes", self.components, self, self.i3dMappings)
	end

	spec.fruitType = FruitType.UNKNOWN
	spec.fruitTypes = {}

	local fruitTypeCategories = self.xmlFile:getString(key .. "#fruitTypeCategories")
	local fruitTypeNames = self.xmlFile:getString(key .. "#fruitTypes")

	if fruitTypeCategories == nil and fruitTypeNames ~= nil then
		spec.fruitTypes = g_fruitTypeManager:getFruitTypesByNames(fruitTypeNames, "Warning: '" .. tostring(key) .. "' has invalid fruitType '%s'.")
	elseif fruitTypeCategories ~= nil and fruitTypeNames == nil then
		spec.fruitTypes = g_fruitTypeManager:getFruitTypesByCategoryNames(fruitTypeCategories, "Warning: '" .. tostring(key) .. "' has invalid fruitTypeCategory '%s'.")
	elseif fruitTypeCategories ~= nil and fruitTypeNames ~= nil then
		local t1 = g_fruitTypeManager:getFruitTypesByNames(fruitTypeNames, "Warning: '" .. tostring(key) .. "' has invalid fruitType '%s'.")
		local t2 = g_fruitTypeManager:getFruitTypesByCategoryNames(fruitTypeCategories, "Warning: '" .. tostring(key) .. "' has invalid fruitTypeCategory '%s'.")
		spec.fruitTypes = table.combine(t1, t2)
	end
	local i = 0

	if #spec.fruitTypes > 0 then
		for _, index in pairs(spec.fruitTypes) do
			local desc = g_fruitTypeManager:getFruitTypeByIndex(index)

			if desc == nil then
				Logging.xmlWarning(self.configFileName, "Unable to find fruitTypeIndex '%d' in fruitPreparer", index)
			end
		end
	else
		Logging.xmlWarning(self.configFileName, "Missing fruitTypes in fruitPreparer")
	end

	spec.isWorking = false
end

function FruitPreparerMultiFruit:onDelete()
	if self.isClient then
		local spec = self["spec_" .. FruitPreparerMultiFruit.modName .. ".FruitPreparerMultiFruit"]

		g_soundManager:deleteSamples(spec.samples)
		g_animationManager:deleteAnimations(spec.animationNodes)
	end
end

function FruitPreparerMultiFruit:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() then
		local spec = self["spec_" .. FruitPreparerMultiFruit.modName .. ".FruitPreparerMultiFruit"]

		spec.isWorking = streamReadBool(streamId)
	end
end

function FruitPreparerMultiFruit:onWriteUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		local spec = self["spec_" .. FruitPreparerMultiFruit.modName .. ".FruitPreparerMultiFruit"]

		streamWriteBool(streamId, spec.isWorking)
	end
end

function FruitPreparerMultiFruit:onTurnedOn()
	if self.isClient then
		local spec = self["spec_" .. FruitPreparerMultiFruit.modName .. ".FruitPreparerMultiFruit"]

		g_soundManager:playSample(spec.samples.work)
		g_animationManager:startAnimations(spec.animationNodes)
	end
end

function FruitPreparerMultiFruit:onTurnedOff()
	if self.isClient then
		local spec = self["spec_" .. FruitPreparerMultiFruit.modName .. ".FruitPreparerMultiFruit"]

		g_soundManager:stopSamples(spec.samples)
		g_animationManager:stopAnimations(spec.animationNodes)
	end
end

function FruitPreparerMultiFruit:loadWorkAreaFromXML(superFunc, workArea, xmlFile, key)
	local retValue = superFunc(self, workArea, xmlFile, key)

	if workArea.type == WorkAreaType.FRUITPREPARER then
		XMLUtil.checkDeprecatedXMLElements(self.xmlFile, self.configFileName, key.."#dropStartIndex", key..".fruitPreparer#dropWorkAreaIndex") -- FS17 to FS19
		XMLUtil.checkDeprecatedXMLElements(self.xmlFile, self.configFileName, key.."#dropWidthIndex", key..".fruitPreparer#dropWorkAreaIndex") -- FS17 to FS19
		XMLUtil.checkDeprecatedXMLElements(self.xmlFile, self.configFileName, key.."#dropHeightIndex", key..".fruitPreparer#dropWorkAreaIndex") -- FS17 to FS19
		workArea.dropWorkAreaIndex = self.xmlFile:getInt(key..".fruitPreparer#dropWorkAreaIndex")
	end

	return retValue
end

function FruitPreparerMultiFruit:getDoGroundManipulation(superFunc)
	local spec = self["spec_" .. FruitPreparerMultiFruit.modName .. ".FruitPreparerMultiFruit"]

	return superFunc(self) and spec.isWorking
end

function FruitPreparerMultiFruit:doCheckSpeedLimit(superFunc)
	return superFunc(self) or (self:getIsTurnedOn() and (self.getIsImplementChainLowered == nil or self:getIsImplementChainLowered()))
end

function FruitPreparerMultiFruit:getAllowCutterAIFruitRequirements(superFunc)
	return false
end

function FruitPreparerMultiFruit:getDirtMultiplier(superFunc)
	local spec = self["spec_" .. FruitPreparerMultiFruit.modName .. ".FruitPreparerMultiFruit"]

	if spec.isWorking then
		return superFunc(self) + self:getWorkDirtMultiplier() * self:getLastSpeed() / self.speedLimit
	end

	return superFunc(self)
end

function FruitPreparerMultiFruit:getWearMultiplier(superFunc)
	local spec = self["spec_" .. FruitPreparerMultiFruit.modName .. ".FruitPreparerMultiFruit"]

	if spec.isWorking then
		return superFunc(self) + self:getWorkWearMultiplier() * self:getLastSpeed() / self.speedLimit
	end

	return superFunc(self)
end

function FruitPreparerMultiFruit:loadRandomlyMovingPartFromXML(superFunc, part, xmlFile, key)
	local retValue = superFunc(self, part, xmlFile, key)
	part.moveOnlyIfPreparerCut = xmlFile:getValue(key .. "#moveOnlyIfPreparerCut", false)

	return retValue
end

function FruitPreparerMultiFruit:getIsRandomlyMovingPartActive(superFunc, part)
	local retValue = superFunc(self, part)

	if part.moveOnlyIfPreparerCut then
		retValue = retValue and self.spec_fruitPreparer.isWorking
	end

	return retValue
end

function FruitPreparerMultiFruit.getDefaultSpeedLimit()
	return 15
end

function FruitPreparerMultiFruit:onStartWorkAreaProcessing(dt)
	local spec = self["spec_" .. FruitPreparerMultiFruit.modName .. ".FruitPreparerMultiFruit"]

	spec.isWorking = false
end

function FruitPreparerMultiFruit:processFruitPreparerArea(workArea)
	local spec = self["spec_" .. FruitPreparerMultiFruit.modName .. ".FruitPreparerMultiFruit"]
	local workAreaSpec = self.spec_workArea

	local xs,_,zs = getWorldTranslation(workArea.start)
	local xw,_,zw = getWorldTranslation(workArea.width)
	local xh,_,zh = getWorldTranslation(workArea.height)

	local dxs, dzs = xs, zs
	local dxw, dzw = xw, zw
	local dxh, dzh = xh, zh

	if workArea.dropWorkAreaIndex ~= nil then
		local dropArea = workAreaSpec.workAreas[workArea.dropWorkAreaIndex]

		if dropArea ~= nil then
			dxs, _, dzs = getWorldTranslation(dropArea.start)
			dxw, _, dzw = getWorldTranslation(dropArea.width)
			dxh, _, dzh = getWorldTranslation(dropArea.height)
		end
	end

	if not self.requestedFieldData then
		self.requestedFieldData = true
		FSDensityMapUtil.getFieldStatusAsync(xs, zs, xw, zw, xh, zh, self.onFieldDataUpdateFinished, self)
	end

	local area = FSDensityMapUtil.updateFruitPreparerArea(spec.fruitType, xs,zs, xw,zw, xh,zh, dxs,dzs, dxw,dzw, dxh,dzh)

	if area > 0 then
		spec.isWorking = true
	end

	return 0, area
end

function FruitPreparerMultiFruit:onFieldDataUpdateFinished(data)
	local spec = self["spec_" .. FruitPreparerMultiFruit.modName .. ".FruitPreparerMultiFruit"]

	if not self.requestedFieldData then
		return
	end

	local hasData = data ~= nil

	if hasData then
		for fruitDescIndex, fruit in pairs(data.fruits) do
			if data.fruitPixels[fruitDescIndex] > 0 then
				for _, allowed in pairs(spec.fruitTypes) do
					if fruitDescIndex == allowed then
						spec.fruitType = fruitDescIndex

						local desc = g_fruitTypeManager:getFruitTypeByIndex(fruitDescIndex)

						if desc ~= nil then
							if self.setAIFruitRequirements ~= nil then
								self:setAIFruitRequirements(desc.index, desc.minPreparingGrowthState, desc.maxPreparingGrowthState)
								local aiUsePreparedState = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.fruitPreparer#aiUsePreparedState"), self.spec_cutter ~= nil or self.spec_CutterMultiFruit ~= nil or self["spec_" .. FruitPreparerMultiFruit.modName .. ".CutterMultiFruit"] ~= nil)
								if aiUsePreparedState then
									self:addAIFruitRequirement(desc.index, desc.preparedGrowthState, desc.preparedGrowthState)
								end
							end
						end
					end
				end
			end
		end
	end

	self.requestedFieldData = false
end