local isPaused, isDead, pickups = false, false, {}

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if NetworkIsPlayerActive(PlayerId()) then
			TriggerServerEvent('rdx:onPlayerJoined')
			break
		end
	end
end)

RegisterNetEvent('rdx:playerLoaded')
AddEventHandler('rdx:playerLoaded', function(playerData)
	RDX.PlayerLoaded = true
	RDX.PlayerData = playerData

	-- check if player is coming from loading screen
	if GetEntityModel(PlayerPedId()) == 0x0D7114C9 or GetEntityModel(PlayerPedId) == 0x00B69710 then
		local defaultModel = 0xF5C1611E -- mp_male

		if (IsModelInCdimage(defaultModel)) then
			RequestModel(defaultModel)

			while not HasModelLoaded(defaultModel) do
				Citizen.Wait(0)
			end

			SetPlayerModel(PlayerId(), defaultModel, 0)
			SetPedOutfitPreset(PlayerPedId(), 0, 0)
			SetModelAsNoLongerNeeded(defaultModel)
		end
	end

	-- enable PVP
	NetworkSetFriendlyFireOption(true)

	-- disable wanted level
	ClearPlayerWantedLevel(PlayerId())
	SetMaxWantedLevel(0)

	if Config.EnableHud then
		for k,v in ipairs(playerData.accounts) do
			local accountTpl = '<div><img class="money" src="img/accounts/' .. v.name .. '.png"/>&nbsp;{{money}}</div>'
			RDX.UI.HUD.RegisterElement('account_' .. v.name, k, 0, accountTpl, {money = RDX.Math.GroupDigits(v.money)})
		end

		local jobTpl = '<div>{{job_label}} - {{grade_label}}</div>'

		if playerData.job.grade_label == '' or playerData.job.grade_label == playerData.job.label then
			jobTpl = '<div>{{job_label}}</div>'
		end

		RDX.UI.HUD.RegisterElement('job', #playerData.accounts, 0, jobTpl, {
			job_label = playerData.job.label,
			grade_label = playerData.job.grade_label
		})
	end

	RDX.Game.Teleport(PlayerPedId(), {
		x = playerData.coords.x,
		y = playerData.coords.y,
		z = playerData.coords.z + 0.25,
		heading = playerData.coords.heading
	}, function()
		TriggerServerEvent('rdx:onPlayerSpawn')
		TriggerEvent('rdx:onPlayerSpawn')
		TriggerEvent('playerSpawned') -- compatibility with old scripts, will be removed soon
		TriggerEvent('rdx:restoreLoadout')

		Citizen.Wait(3000)
		ShutdownLoadingScreen()
		FreezeEntityPosition(PlayerPedId(), false)
		DoScreenFadeIn(10000)
		StartServerSyncLoops()
	end)
end)

RegisterNetEvent('rdx:setMaxWeight')
AddEventHandler('rdx:setMaxWeight', function(newMaxWeight) RDX.PlayerData.maxWeight = newMaxWeight end)

AddEventHandler('rdx:onPlayerSpawn', function() isDead = false end)
AddEventHandler('rdx:onPlayerDeath', function() isDead = true end)

AddEventHandler('skinchanger:modelLoaded', function()
	while not RDX.PlayerLoaded do
		Citizen.Wait(100)
	end

	TriggerEvent('rdx:restoreLoadout')
end)

AddEventHandler('rdx:restoreLoadout', function()
	local playerPed = PlayerPedId()
	local ammoTypes = {}
	RemoveAllPedWeapons(playerPed, true)

	for k,v in ipairs(RDX.PlayerData.loadout) do
		local weaponName = v.name
		local weaponHash = GetHashKey(weaponName)

		GiveWeaponToPed(playerPed, weaponHash, 0, false, false)
		SetPedWeaponTintIndex(playerPed, weaponHash, v.tintIndex)

		local ammoType = GetPedAmmoTypeFromWeapon(playerPed, weaponHash)

		for k2,v2 in ipairs(v.components) do
			local componentHash = RDX.GetWeaponComponent(weaponName, v2).hash
			GiveWeaponComponentToPed(playerPed, weaponHash, componentHash)
		end

		if not ammoTypes[ammoType] then
			AddAmmoToPed(playerPed, weaponHash, v.ammo)
			ammoTypes[ammoType] = true
		end
	end
end)

RegisterNetEvent('rdx:setAccountMoney')
AddEventHandler('rdx:setAccountMoney', function(account)
	for k,v in ipairs(RDX.PlayerData.accounts) do
		if v.name == account.name then
			RDX.PlayerData.accounts[k] = account
			break
		end
	end

	if Config.EnableHud then
		RDX.UI.HUD.UpdateElement('account_' .. account.name, {
			money = RDX.Math.GroupDigits(account.money)
		})
	end
end)

RegisterNetEvent('rdx:addInventoryItem')
AddEventHandler('rdx:addInventoryItem', function(item, count, showNotification)
	for k,v in ipairs(RDX.PlayerData.inventory) do
		if v.name == item then
			RDX.UI.ShowInventoryItemNotification(true, v.label, count - v.count)
			RDX.PlayerData.inventory[k].count = count
			break
		end
	end

	if showNotification then
		RDX.UI.ShowInventoryItemNotification(true, item, count)
	end

	if RDX.UI.Menu.IsOpen('default', 'redm_extended', 'inventory') then
		RDX.ShowInventory()
	end
end)

RegisterNetEvent('rdx:removeInventoryItem')
AddEventHandler('rdx:removeInventoryItem', function(item, count, showNotification)
	for k,v in ipairs(RDX.PlayerData.inventory) do
		if v.name == item then
			RDX.UI.ShowInventoryItemNotification(false, v.label, v.count - count)
			RDX.PlayerData.inventory[k].count = count
			break
		end
	end

	if showNotification then
		RDX.UI.ShowInventoryItemNotification(false, item, count)
	end

	if RDX.UI.Menu.IsOpen('default', 'redm_extended', 'inventory') then
		RDX.ShowInventory()
	end
end)

RegisterNetEvent('rdx:setJob')
AddEventHandler('rdx:setJob', function(job)
	RDX.PlayerData.job = job
end)

RegisterNetEvent('rdx:addWeapon')
AddEventHandler('rdx:addWeapon', function(weaponName, ammo)
	local playerPed = PlayerPedId()
	local weaponHash = GetHashKey(weaponName)

	GiveWeaponToPed(playerPed, weaponHash, ammo, false, false)
end)

RegisterNetEvent('rdx:addWeaponComponent')
AddEventHandler('rdx:addWeaponComponent', function(weaponName, weaponComponent)
	local playerPed = PlayerPedId()
	local weaponHash = GetHashKey(weaponName)
	local componentHash = RDX.GetWeaponComponent(weaponName, weaponComponent).hash

	GiveWeaponComponentToPed(playerPed, weaponHash, componentHash)
end)

RegisterNetEvent('rdx:setWeaponAmmo')
AddEventHandler('rdx:setWeaponAmmo', function(weaponName, weaponAmmo)
	local playerPed = PlayerPedId()
	local weaponHash = GetHashKey(weaponName)

	SetPedAmmo(playerPed, weaponHash, weaponAmmo)
end)

RegisterNetEvent('rdx:setWeaponTint')
AddEventHandler('rdx:setWeaponTint', function(weaponName, weaponTintIndex)
	local playerPed = PlayerPedId()
	local weaponHash = GetHashKey(weaponName)

	SetPedWeaponTintIndex(playerPed, weaponHash, weaponTintIndex)
end)

RegisterNetEvent('rdx:removeWeapon')
AddEventHandler('rdx:removeWeapon', function(weaponName)
	local playerPed = PlayerPedId()
	local weaponHash = GetHashKey(weaponName)

	RemoveWeaponFromPed(playerPed, weaponHash)
	SetPedAmmo(playerPed, weaponHash, 0) -- remove leftover ammo
end)

RegisterNetEvent('rdx:removeWeaponComponent')
AddEventHandler('rdx:removeWeaponComponent', function(weaponName, weaponComponent)
	local playerPed = PlayerPedId()
	local weaponHash = GetHashKey(weaponName)
	local componentHash = RDX.GetWeaponComponent(weaponName, weaponComponent).hash

	RemoveWeaponComponentFromPed(playerPed, weaponHash, componentHash)
end)

RegisterNetEvent('rdx:teleport')
AddEventHandler('rdx:teleport', function(coords)
	local playerPed = PlayerPedId()

	-- ensure decmial number
	coords.x = coords.x + 0.0
	coords.y = coords.y + 0.0
	coords.z = coords.z + 0.0

	RDX.Game.Teleport(playerPed, coords)
end)

RegisterNetEvent('rdx:setJob')
AddEventHandler('rdx:setJob', function(job)
	if Config.EnableHud then
		RDX.UI.HUD.UpdateElement('job', {
			job_label = job.label,
			grade_label = job.grade_label
		})
	end
end)

RegisterNetEvent('rdx:spawnVehicle')
AddEventHandler('rdx:spawnVehicle', function(vehicleName)
	local model = (type(vehicleName) == 'number' and vehicleName or GetHashKey(vehicleName))

	if IsModelInCdimage(model) then
		local playerPed = PlayerPedId()
		local playerCoords, playerHeading = GetEntityCoords(playerPed), GetEntityHeading(playerPed)

		RDX.Game.SpawnVehicle(model, playerCoords, playerHeading, function(vehicle)
			TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
		end)
	else
		TriggerEvent('chat:addMessage', {args = {'^1SYSTEM', 'Invalid vehicle model.'}})
	end
end)

RegisterNetEvent('rdx:createPickup')
AddEventHandler('rdx:createPickup', function(pickupId, label, coords, type, name, components, tintIndex)
	local function setObjectProperties(object)
		SetEntityAsMissionEntity(object, true, false)
		PlaceObjectOnGroundProperly(object)
		FreezeEntityPosition(object, true)
		SetEntityCollision(object, false, true)

		pickups[pickupId] = {
			obj = object,
			label = label,
			inRange = false,
			coords = vector3(coords.x, coords.y, coords.z)
		}
	end

	if type == 'item_weapon' then
		local weaponHash = GetHashKey(name)
		RDX.Streaming.RequestWeaponAsset(weaponHash)
		local pickupObject = CreateWeaponObject(weaponHash, 50, coords.x, coords.y, coords.z, true, 1.0, 0)
		SetWeaponObjectTintIndex(pickupObject, tintIndex)

		for k,v in ipairs(components) do
			local component = RDX.GetWeaponComponent(name, v)
			GiveWeaponComponentToWeaponObject(pickupObject, component.hash)
		end

		setObjectProperties(pickupObject)
	else
		RDX.Game.SpawnLocalObject('prop_money_bag_01', coords, setObjectProperties)
	end
end)

RegisterNetEvent('rdx:createMissingPickups')
AddEventHandler('rdx:createMissingPickups', function(missingPickups)
	for pickupId,pickup in pairs(missingPickups) do
		TriggerEvent('rdx:createPickup', pickupId, pickup.label, pickup.coords, pickup.type, pickup.name, pickup.components, pickup.tintIndex)
	end
end)

RegisterNetEvent('rdx:registerSuggestions')
AddEventHandler('rdx:registerSuggestions', function(registeredCommands)
	for name,command in pairs(registeredCommands) do
		if command.suggestion then
			TriggerEvent('chat:addSuggestion', ('/%s'):format(name), command.suggestion.help, command.suggestion.arguments)
		end
	end
end)

RegisterNetEvent('rdx:removePickup')
AddEventHandler('rdx:removePickup', function(pickupId)
	if pickups[pickupId] and pickups[pickupId].obj then
		RDX.Game.DeleteObject(pickups[pickupId].obj)
		pickups[pickupId] = nil
	end
end)

RegisterNetEvent('rdx:deleteVehicle')
AddEventHandler('rdx:deleteVehicle', function()
	local playerPed = PlayerPedId()
	local vehicle, attempt = RDX.Game.GetVehicleInDirection(), 0

	if IsPedInAnyVehicle(playerPed, true) then
		vehicle = GetVehiclePedIsIn(playerPed, false)
	end

	while not NetworkHasControlOfEntity(vehicle) and attempt < 100 and DoesEntityExist(vehicle) do
		Citizen.Wait(100)
		NetworkRequestControlOfEntity(vehicle)
		attempt = attempt + 1
	end

	if DoesEntityExist(vehicle) and NetworkHasControlOfEntity(vehicle) then
		RDX.Game.DeleteVehicle(vehicle)
	end
end)

-- Pause menu disables HUD display
if Config.EnableHud then
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(300)

			if IsPauseMenuActive() and not isPaused then
				isPaused = true
				RDX.UI.HUD.SetDisplay(0.0)
			elseif not IsPauseMenuActive() and isPaused then
				isPaused = false
				RDX.UI.HUD.SetDisplay(1.0)
			end
		end
	end)
end

function StartServerSyncLoops()
	-- keep track of ammo
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(0)

			if isDead then
				Citizen.Wait(500)
			else
				local playerPed = PlayerPedId()

				if IsPedShooting(playerPed) then
					local _,weaponHash = GetCurrentPedWeapon(playerPed, true)
					local weapon = RDX.GetWeaponFromHash(weaponHash)

					if weapon then
						local ammoCount = GetAmmoInPedWeapon(playerPed, weaponHash)
						TriggerServerEvent('rdx:updateWeaponAmmo', weapon.name, ammoCount)
					end
				end
			end
		end
	end)

	-- sync current player coords with server
	Citizen.CreateThread(function()
		local previousCoords = vector3(RDX.PlayerData.coords.x, RDX.PlayerData.coords.y, RDX.PlayerData.coords.z)

		while true do
			Citizen.Wait(1000)
			local playerPed = PlayerPedId()

			if DoesEntityExist(playerPed) then
				local playerCoords = GetEntityCoords(playerPed)
				local distance = #(playerCoords - previousCoords)

				if distance > 1 then
					previousCoords = playerCoords
					local playerHeading = RDX.Math.Round(GetEntityHeading(playerPed), 1)
					local formattedCoords = {x = RDX.Math.Round(playerCoords.x, 1), y = RDX.Math.Round(playerCoords.y, 1), z = RDX.Math.Round(playerCoords.z, 1), heading = playerHeading}
					TriggerServerEvent('rdx:updateCoords', formattedCoords)
				end
			end
		end
	end)
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if IsControlJustReleased(0, Controls.SelectItemWheel) then -- F4
			if IsInputDisabled(0) and not isDead and not RDX.UI.Menu.IsOpen('default', 'redm_extended', 'inventory') then
				RDX.ShowInventory()
			end
		end
	end
end)

-- Pickups
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		local playerPed = PlayerPedId()
		local playerCoords, letSleep = GetEntityCoords(playerPed), true
		local closestPlayer, closestDistance = RDX.Game.GetClosestPlayer(playerCoords)

		for pickupId,pickup in pairs(pickups) do
			local distance = #(playerCoords - pickup.coords)

			if distance < 5 then
				local label = pickup.label
				letSleep = false

				if distance < 1 then
					if IsControlJustReleased(0, 38) then
						if IsPedOnFoot(playerPed) and (closestDistance == -1 or closestDistance > 3) and not pickup.inRange then
							pickup.inRange = true

							local dict, anim = 'weapons@first_person@aim_rng@generic@projectile@sticky_bomb@', 'plant_floor'
							RDX.Streaming.RequestAnimDict(dict)
							TaskPlayAnim(playerPed, dict, anim, 8.0, 1.0, 1000, 16, 0.0, false, false, false)
							Citizen.Wait(1000)

							TriggerServerEvent('rdx:onPickup', pickupId)
							PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
						end
					end

					label = ('%s~n~%s'):format(label, _U('threw_pickup_prompt'))
				end

				RDX.Game.Utils.DrawText3D({
					x = pickup.coords.x,
					y = pickup.coords.y,
					z = pickup.coords.z + 0.25
				}, label, 1.2, 1)
			elseif pickup.inRange then
				pickup.inRange = false
			end
		end

		if letSleep then
			Citizen.Wait(500)
		end
	end
end)
