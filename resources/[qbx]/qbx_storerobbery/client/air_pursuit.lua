local getawayHeli
local policeHeli
local policePilot
local policeGunner
local pursuitActive = false
local pursuitToken = 0

local function deleteEntitySafe(entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    end
end

local function requestVehicleModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    lib.requestModel(hash, 10000)
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function getSpawn(origin, distance, heading, height)
    local radians = math.rad(heading)
    local x = origin.x + math.cos(radians) * distance
    local y = origin.y + math.sin(radians) * distance
    local found, groundZ = GetGroundZFor_3dCoord(x, y, origin.z + 50.0, false)
    local z = found and groundZ + (height or 2.0) or origin.z + (height or 5.0)
    return vec3(x, y, z)
end

local function vehicleBlip(vehicle, colour, name)
    local blip = AddBlipForEntity(vehicle)
    SetBlipSprite(blip, 43)
    SetBlipColour(blip, colour)
    SetBlipScale(blip, 0.85)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(name)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function cleanupPolice()
    pursuitActive = false
    pursuitToken = pursuitToken + 1
    deleteEntitySafe(policePilot)
    deleteEntitySafe(policeGunner)
    deleteEntitySafe(policeHeli)
    policePilot, policeGunner, policeHeli = nil, nil, nil
end

local function spawnGetaway(safeIndex)
    if getawayHeli and DoesEntityExist(getawayHeli) then return end
    local safe = sharedConfig.safes[safeIndex]
    if not safe then return end

    local model = requestVehicleModel('frogger')
    if not model then
        exports.qbx_core:Notify('Getaway helicopter could not be spawned.', 'error')
        return
    end

    local spawn = getSpawn(safe.coords, 12.0, GetEntityHeading(cache.ped) + 90.0, 2.0)
    getawayHeli = CreateVehicle(model, spawn.x, spawn.y, spawn.z, GetEntityHeading(cache.ped), true, true)
    SetModelAsNoLongerNeeded(model)
    if getawayHeli == 0 then
        exports.qbx_core:Notify('Getaway helicopter could not be spawned.', 'error')
        return
    end

    SetEntityAsMissionEntity(getawayHeli, true, true)
    SetVehicleOnGroundProperly(getawayHeli)
    SetVehicleDoorsLocked(getawayHeli, 1)
    SetVehicleEngineOn(getawayHeli, true, true, false)
    SetVehicleFuelLevel(getawayHeli, 100.0)
    SetVehicleNumberPlateText(getawayHeli, 'GETAWAY')
    SetVehicleNeedsToBeHotwired(getawayHeli, false)
    SetVehRadioStation(getawayHeli, 'OFF')

    local netId = NetworkGetNetworkIdFromEntity(getawayHeli)
    if netId and netId > 0 then
        SetNetworkIdCanMigrate(netId, true)
        SetNetworkIdExistsOnAllMachines(netId, true)
    end

    local blip = vehicleBlip(getawayHeli, 2, 'Getaway Helicopter')
    exports.qbx_core:Notify('GETAWAY READY: Your helicopter is outside the store.', 'success', 7000)

    CreateThread(function()
        local vehicle = getawayHeli
        local expires = GetGameTimer() + 600000
        while DoesEntityExist(vehicle) and getawayHeli == vehicle and GetGameTimer() < expires do
            if IsPedInVehicle(cache.ped, vehicle, false) then break end
            Wait(1000)
        end
        if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
        if getawayHeli == vehicle and DoesEntityExist(vehicle) then
            deleteEntitySafe(vehicle)
            getawayHeli = nil
        end
    end)
end

local function spawnPolice(safeIndex, token)
    if token ~= pursuitToken or pursuitActive then return end
    local safe = sharedConfig.safes[safeIndex]
    if not safe then return end

    local heliModel = requestVehicleModel('polmav')
    local copModel = requestVehicleModel('s_m_y_cop_01')
    if not heliModel or not copModel then
        if heliModel then SetModelAsNoLongerNeeded(heliModel) end
        if copModel then SetModelAsNoLongerNeeded(copModel) end
        exports.qbx_core:Notify('Police helicopter could not be spawned.', 'error')
        return
    end

    local spawn = getSpawn(safe.coords, 220.0, GetEntityHeading(cache.ped) + 180.0, 55.0)
    policeHeli = CreateVehicle(heliModel, spawn.x, spawn.y, spawn.z, GetEntityHeading(cache.ped), true, true)
    SetModelAsNoLongerNeeded(heliModel)
    if policeHeli == 0 then
        SetModelAsNoLongerNeeded(copModel)
        return
    end

    SetEntityAsMissionEntity(policeHeli, true, true)
    SetVehicleEngineOn(policeHeli, true, true, false)
    SetVehicleSiren(policeHeli, true)
    SetVehicleHasMutedSirens(policeHeli, false)
    SetVehicleNumberPlateText(policeHeli, 'POLICE')

    policePilot = CreatePedInsideVehicle(policeHeli, 4, copModel, -1, true, true)
    policeGunner = CreatePedInsideVehicle(policeHeli, 4, copModel, 0, true, true)
    SetModelAsNoLongerNeeded(copModel)

    if policePilot == 0 or policeGunner == 0 then
        cleanupPolice()
        return
    end

    SetEntityAsMissionEntity(policePilot, true, true)
    SetEntityAsMissionEntity(policeGunner, true, true)
    AddRelationshipGroup('ROBBERY_COPS')
    SetPedRelationshipGroupHash(policePilot, joaat('ROBBERY_COPS'))
    SetPedRelationshipGroupHash(policeGunner, joaat('ROBBERY_COPS'))
    SetPedKeepTask(policePilot, true)
    SetPedKeepTask(policeGunner, true)
    SetBlockingOfNonTemporaryEvents(policePilot, true)
    SetBlockingOfNonTemporaryEvents(policeGunner, true)
    SetPedCanRagdoll(policePilot, false)
    SetPedCanRagdoll(policeGunner, false)
    GiveWeaponToPed(policeGunner, joaat('WEAPON_CARBINERIFLE'), 300, false, true)
    SetPedAccuracy(policeGunner, 55)
    SetPedCombatAbility(policeGunner, 2)
    SetPedCombatRange(policeGunner, 2)
    SetPedCombatAttributes(policeGunner, 5, true)
    SetPedCombatAttributes(policeGunner, 46, true)

    local netId = NetworkGetNetworkIdFromEntity(policeHeli)
    if netId and netId > 0 then
        SetNetworkIdCanMigrate(netId, true)
        SetNetworkIdExistsOnAllMachines(netId, true)
    end

    pursuitActive = true
    local blip = vehicleBlip(policeHeli, 1, 'Police Helicopter')
    exports.qbx_core:Notify('POLICE AIR UNIT INBOUND! Get airborne and escape!', 'error', 9000)

    CreateThread(function()
        local heli, pilot, gunner = policeHeli, policePilot, policeGunner
        local player = cache.ped
        local expires = GetGameTimer() + 480000
        while pursuitActive and pursuitToken == token and DoesEntityExist(heli) and DoesEntityExist(pilot) and GetGameTimer() < expires do
            if IsEntityDead(player) then break end
            TaskHeliChase(pilot, player)
            if DoesEntityExist(gunner) and not IsEntityDead(gunner) then
                TaskCombatPed(gunner, player, 0, 16)
            end
            Wait(2500)
        end
        if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
        if pursuitToken == token then cleanupPolice() end
    end)
end

RegisterNetEvent('qbx_storerobbery:client:startGetaway', function(safeIndex)
    spawnGetaway(safeIndex)
    pursuitToken = pursuitToken + 1
    local token = pursuitToken
    CreateThread(function()
        Wait(30000)
        if token ~= pursuitToken or IsEntityDead(cache.ped) then return end
        spawnPolice(safeIndex, token)
    end)
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= cache.resource then return end
    cleanupPolice()
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= cache.resource then return end
    cleanupPolice()
    deleteEntitySafe(getawayHeli)
    getawayHeli = nil
end)
