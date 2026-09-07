-- Reliable helicopter fallback for qbx_storerobbery.
-- The original helicopter code incorrectly validated ped models with IsModelAVehicle().
-- This handler uses separate vehicle/ped model loaders and retries once if spawning fails.

local fallbackGetaway
local fallbackPilot
local fallbackPolice
local fallbackPolicePilot
local fallbackPoliceGunner
local getawayStarted = false

local function requestVehicleModel(name)
    local hash = joaat(name)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 15000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
    return HasModelLoaded(hash) and hash or nil
end

local function requestPedModel(name)
    local hash = joaat(name)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 15000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
    return HasModelLoaded(hash) and hash or nil
end

local function removeEntity(entity)
    if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
    end
end

local function spawnGetawayFallback()
    if DoesEntityExist(fallbackGetaway) then return true end

    local ped = PlayerPedId()
    local player = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local spawn = GetOffsetFromEntityInWorldCoords(ped, 25.0, -15.0, 18.0)

    local heliHash = requestVehicleModel('frogger')
    local pilotHash = requestPedModel('s_m_m_pilot_02')
    if not heliHash or not pilotHash then
        print('[qbx_storerobbery] HELI FIX: failed to load frogger or pilot model')
        return false
    end

    fallbackGetaway = CreateVehicle(heliHash, spawn.x, spawn.y, spawn.z, heading, true, true)
    if not DoesEntityExist(fallbackGetaway) then
        SetModelAsNoLongerNeeded(heliHash)
        SetModelAsNoLongerNeeded(pilotHash)
        print('[qbx_storerobbery] HELI FIX: CreateVehicle(frogger) failed')
        return false
    end

    SetEntityAsMissionEntity(fallbackGetaway, true, true)
    SetVehicleEngineOn(fallbackGetaway, true, true, false)
    SetHeliBladesFullSpeed(fallbackGetaway)
    SetVehicleDoorsLocked(fallbackGetaway, 2)

    fallbackPilot = CreatePedInsideVehicle(fallbackGetaway, 4, pilotHash, -1, true, true)
    if not DoesEntityExist(fallbackPilot) then
        removeEntity(fallbackGetaway)
        fallbackGetaway = nil
        SetModelAsNoLongerNeeded(heliHash)
        SetModelAsNoLongerNeeded(pilotHash)
        print('[qbx_storerobbery] HELI FIX: pilot CreatePedInsideVehicle failed')
        return false
    end

    SetEntityAsMissionEntity(fallbackPilot, true, true)
    SetBlockingOfNonTemporaryEvents(fallbackPilot, true)
    SetPedKeepTask(fallbackPilot, true)
    SetDriverAbility(fallbackPilot, 1.0)
    SetDriverAggressiveness(fallbackPilot, 1.0)
    TaskHeliMission(fallbackPilot, fallbackGetaway, 0, 0, player.x, player.y, player.z + 20.0, 4, 45.0, -1.0, -1, 100.0, 100.0, -1.0, 0)

    SetModelAsNoLongerNeeded(heliHash)
    SetModelAsNoLongerNeeded(pilotHash)
    print('[qbx_storerobbery] HELI FIX: getaway helicopter spawned successfully')
    exports.qbx_core:Notify('Getaway helicopter is outside the store.', 'success', 7000)
    return true
end

local function spawnPoliceFallback()
    if DoesEntityExist(fallbackPolice) then return true end

    local ped = PlayerPedId()
    local target = GetEntityCoords(ped)
    local spawn = GetOffsetFromEntityInWorldCoords(ped, -45.0, -45.0, 30.0)

    local heliHash = requestVehicleModel('polmav')
    local pilotHash = requestPedModel('s_m_y_pilot_01')
    local gunnerHash = requestPedModel('s_m_y_cop_01')
    if not heliHash or not pilotHash or not gunnerHash then
        print('[qbx_storerobbery] HELI FIX: failed to load police helicopter/ped models')
        return false
    end

    fallbackPolice = CreateVehicle(heliHash, spawn.x, spawn.y, spawn.z, GetEntityHeading(ped), true, true)
    if not DoesEntityExist(fallbackPolice) then
        print('[qbx_storerobbery] HELI FIX: CreateVehicle(polmav) failed')
        return false
    end

    SetEntityAsMissionEntity(fallbackPolice, true, true)
    SetVehicleEngineOn(fallbackPolice, true, true, false)
    SetHeliBladesFullSpeed(fallbackPolice)

    fallbackPolicePilot = CreatePedInsideVehicle(fallbackPolice, 4, pilotHash, -1, true, true)
    fallbackPoliceGunner = CreatePedInsideVehicle(fallbackPolice, 4, gunnerHash, 0, true, true)
    if not DoesEntityExist(fallbackPolicePilot) or not DoesEntityExist(fallbackPoliceGunner) then
        removeEntity(fallbackPolicePilot)
        removeEntity(fallbackPoliceGunner)
        removeEntity(fallbackPolice)
        fallbackPolice, fallbackPolicePilot, fallbackPoliceGunner = nil, nil, nil
        print('[qbx_storerobbery] HELI FIX: police ped spawn failed')
        return false
    end

    GiveWeaponToPed(fallbackPoliceGunner, joaat('WEAPON_CARBINERIFLE'), 500, false, true)
    SetCurrentPedWeapon(fallbackPoliceGunner, joaat('WEAPON_CARBINERIFLE'), true)
    SetPedAccuracy(fallbackPoliceGunner, 70)
    SetPedCombatAbility(fallbackPoliceGunner, 2)
    SetPedCombatAttributes(fallbackPoliceGunner, 46, true)
    SetBlockingOfNonTemporaryEvents(fallbackPolicePilot, true)
    SetBlockingOfNonTemporaryEvents(fallbackPoliceGunner, true)
    SetPedKeepTask(fallbackPolicePilot, true)
    SetPedKeepTask(fallbackPoliceGunner, true)
    SetDriverAbility(fallbackPolicePilot, 1.0)
    SetDriverAggressiveness(fallbackPolicePilot, 1.0)

    TaskHeliMission(fallbackPolicePilot, fallbackPolice, 0, 0, target.x, target.y, target.z + 18.0, 6, 55.0, -1.0, -1, 80.0, 80.0, -1.0, 0)
    TaskCombatPed(fallbackPoliceGunner, ped, 0, 16)

    SetModelAsNoLongerNeeded(heliHash)
    SetModelAsNoLongerNeeded(pilotHash)
    SetModelAsNoLongerNeeded(gunnerHash)
    print('[qbx_storerobbery] HELI FIX: police helicopter spawned successfully')
    exports.qbx_core:Notify('Police helicopter is chasing you!', 'error', 9000)
    return true
end

RegisterNetEvent('qbx_storerobbery:client:startGetaway', function()
    if getawayStarted then return end
    getawayStarted = true

    CreateThread(function()
        -- Let the original handler attempt first, then use the reliable fallback.
        Wait(750)
        if not DoesEntityExist(fallbackGetaway) then
            if not spawnGetawayFallback() then
                Wait(1500)
                spawnGetawayFallback()
            end
        end

        Wait(30000)
        if not DoesEntityExist(fallbackPolice) then
            if not spawnPoliceFallback() then
                Wait(1500)
                spawnPoliceFallback()
            end
        end
    end)
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeEntity(fallbackPilot)
    removeEntity(fallbackGetaway)
    removeEntity(fallbackPoliceGunner)
    removeEntity(fallbackPolicePilot)
    removeEntity(fallbackPolice)
end)
