local config = require 'config.server'
local sharedConfig = require 'config.shared'
local startedRegister = {}
local startedSafe = {}
local safeCodes = {}

local function getClosestRegister(coords)
    local closestRegisterIndex
    for i = 1, #sharedConfig.registers do
        if #(coords - sharedConfig.registers[i].coords) <= 2 then
            if closestRegisterIndex then
                if #(coords - sharedConfig.registers[i].coords) < #(coords - sharedConfig.registers[closestRegisterIndex].coords) then
                    closestRegisterIndex = i
                end
            else
                closestRegisterIndex = i
            end
        end
    end
    return closestRegisterIndex
end

local function getClosestSafe(coords)
    local closestSafeIndex
    for i = 1, #sharedConfig.safes do
        if #(coords - sharedConfig.safes[i].coords) <= 2 then
            closestSafeIndex = i
        end
    end
    return closestSafeIndex
end

local function broadcastState()
    TriggerClientEvent('qbx_storerobbery:client:updatedRobbables', -1, sharedConfig.registers, sharedConfig.safes)
end

local function resetRegister(index)
    if not index or not sharedConfig.registers[index] then return end
    sharedConfig.registers[index].robbed = false
    broadcastState()
end

local function resetSafe(index)
    if not index or not sharedConfig.safes[index] then return end
    sharedConfig.safes[index].robbed = false
    broadcastState()
end

RegisterNetEvent('qbx_storerobbery:server:checkStatus', function()
    local src = source
    local ped = GetPlayerPed(src)
    if ped <= 0 then return end

    local coords = GetEntityCoords(ped)
    local closestRegisterIndex = getClosestRegister(coords)
    if not closestRegisterIndex then return end
    if sharedConfig.registers[closestRegisterIndex].robbed then return end
    if startedRegister[src] then return end

    local leoCount = exports.qbx_core:GetDutyCountType('leo')
    if leoCount < sharedConfig.minimumCops then
        if sharedConfig.notEnoughCopsNotify then
            exports.qbx_core:Notify(src, locale('error.no_police', {Required = sharedConfig.minimumCops}), 'error')
        end
        return
    end

    local hasLockpick = exports.ox_inventory:Search(src, 'count', 'lockpick') > 0
    local hasAdvanced = exports.ox_inventory:Search(src, 'count', 'advancedlockpick') > 0

    if not hasLockpick and not hasAdvanced then
        exports.qbx_core:Notify(src, 'You don\'t have the appropriate items', 'error')
        return
    end

    local isAdvanced = hasAdvanced and not hasLockpick
    startedRegister[src] = closestRegisterIndex
    sharedConfig.registers[closestRegisterIndex].robbed = true
    broadcastState()

    TriggerClientEvent('qbx_storerobbery:client:initRegisterAttempt', src, isAdvanced)
end)

RegisterNetEvent('qbx_storerobbery:server:registerFailed', function(isUsingAdvanced)
    local src = source
    local ped = GetPlayerPed(src)
    local registerIndex = startedRegister[src]
    if ped <= 0 or not registerIndex then return end

    local coords = GetEntityCoords(ped)
    if not sharedConfig.registers[registerIndex] or #(coords - sharedConfig.registers[registerIndex].coords) > 2.5 then
        startedRegister[src] = nil
        resetRegister(registerIndex)
        return
    end

    startedRegister[src] = nil
    sharedConfig.registers[registerIndex].robbed = false

    local removalChance = isUsingAdvanced and math.random(0, 30) or math.random(0, 60)
    if removalChance > math.random(0, 100) then
        exports.qbx_core:Notify(src, locale('error.lockpick_broken'), 'error')
        if isUsingAdvanced then
            exports.ox_inventory:RemoveItem(src, 'advancedlockpick', 1)
        else
            exports.ox_inventory:RemoveItem(src, 'lockpick', 1)
        end
    end

    broadcastState()
end)

RegisterNetEvent('qbx_storerobbery:server:registerExited', function()
    local src = source
    local registerIndex = startedRegister[src]
    if not registerIndex then return end

    startedRegister[src] = nil
    resetRegister(registerIndex)
end)

RegisterNetEvent('qbx_storerobbery:server:registerCanceled', function()
    local src = source
    local registerIndex = startedRegister[src]
    startedRegister[src] = nil
    if registerIndex then resetRegister(registerIndex) end
end)

RegisterNetEvent('qbx_storerobbery:server:registerOpened', function(isDone)
    if not isDone then return end

    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local ped = GetPlayerPed(src)
    local registerIndex = startedRegister[src]
    if not player or ped <= 0 or not registerIndex then return end
    if not sharedConfig.registers[registerIndex] then return end

    local coords = GetEntityCoords(ped)
    if #(coords - sharedConfig.registers[registerIndex].coords) > 2.5 then
        startedRegister[src] = nil
        resetRegister(registerIndex)
        return
    end

    if not sharedConfig.registers[registerIndex].robbed then
        startedRegister[src] = nil
        return
    end

    player.Functions.AddMoney('cash', math.random(config.registerReward.min, config.registerReward.max))

    local safeIndex = sharedConfig.registers[registerIndex].safeKey
    if config.registerReward.chanceAtSticky > math.random(0, 100) and safeIndex and safeCodes[safeIndex] then
        local code = safeCodes[safeIndex]
        local info

        if sharedConfig.safes[safeIndex].type == 'keypad' then
            info = {
                label = locale('text.safe_code') .. tostring(code)
            }
        else
            info = {
                label = locale('text.safe_code') .. tostring(math.floor((code[1] % 360) / 3.60)) .. "-" .. tostring(math.floor((code[2] % 360) / 3.60)) .. "-" .. tostring(math.floor((code[3] % 360) / 3.60)) .. "-" .. tostring(math.floor((code[4] % 360) / 3.60)) .. "-" .. tostring(math.floor((code[5] % 360) / 3.60))
            }
        end

        exports.ox_inventory:AddItem(src, 'stickynote', 1, info)
    end

    startedRegister[src] = nil
    broadcastState()

    SetTimeout(math.random(config.registerRefresh.min, config.registerRefresh.max), function()
        resetRegister(registerIndex)
    end)
end)

RegisterNetEvent('qbx_storerobbery:server:trySafe', function()
    local src = source
    local ped = GetPlayerPed(src)
    if ped <= 0 or startedSafe[src] then return end

    local playerCoords = GetEntityCoords(ped)
    local closestSafeIndex = getClosestSafe(playerCoords)
    if not closestSafeIndex then return end
    if sharedConfig.safes[closestSafeIndex].robbed then return end
    if not safeCodes[closestSafeIndex] then return end

    local leoCount = exports.qbx_core:GetDutyCountType('leo')
    if leoCount < sharedConfig.minimumCops then
        if sharedConfig.notEnoughCopsNotify then
            exports.qbx_core:Notify(src, locale('error.no_police', {Required = sharedConfig.minimumCops}), 'error')
        end
        return
    end

    sharedConfig.safes[closestSafeIndex].robbed = true
    startedSafe[src] = closestSafeIndex
    broadcastState()
    TriggerClientEvent('qbx_storerobbery:client:initSafeAttempt', src, closestSafeIndex, safeCodes[closestSafeIndex])
end)

RegisterNetEvent('qbx_storerobbery:server:failedSafeCracking', function()
    local src = source
    local safeIndex = startedSafe[src]
    if not safeIndex then return end

    startedSafe[src] = nil
    resetSafe(safeIndex)
end)

RegisterNetEvent('qbx_storerobbery:server:safeCracked', function()
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local ped = GetPlayerPed(src)
    local safeIndex = startedSafe[src]
    if not player or ped <= 0 or not safeIndex then return end
    if not sharedConfig.safes[safeIndex] then return end

    local playerCoords = GetEntityCoords(ped)
    if #(playerCoords - sharedConfig.safes[safeIndex].coords) > 2.5 then
        startedSafe[src] = nil
        resetSafe(safeIndex)
        return
    end

    if not sharedConfig.safes[safeIndex].robbed then
        startedSafe[src] = nil
        return
    end

    local worthMarkedBills = math.random(config.safeReward.markedBillsWorth.min, config.safeReward.markedBillsWorth.max)
    local numMarkedBills = math.random(config.safeReward.markedBillsAmount.min, config.safeReward.markedBillsAmount.max)
    local billsMeta = {
        worth = worthMarkedBills,
        description = locale('text.value', { value = worthMarkedBills })
    }

    player.Functions.AddItem('markedbills', numMarkedBills, false, billsMeta)

    if config.safeReward.chanceAtSpecial > math.random(0, 100) then
        player.Functions.AddItem('rolex', math.random(config.safeReward.rolexAmount.min, config.safeReward.rolexAmount.max))
        if config.safeReward.chanceAtSpecial / 2 > math.random(0, 100) then
            player.Functions.AddItem('goldbar', config.safeReward.goldbarAmount)
        end
    end

    startedSafe[src] = nil
    broadcastState()

    SetTimeout(math.random(config.safeRefresh.min, config.safeRefresh.max), function()
        resetSafe(safeIndex)
    end)
end)

AddEventHandler('playerJoining', function()
    TriggerClientEvent('qbx_storerobbery:client:updatedRobbables', source, sharedConfig.registers, sharedConfig.safes)
end)

AddEventHandler('playerDropped', function()
    local src = source
    startedRegister[src] = nil
    startedSafe[src] = nil
end)

lib.callback.register('qbx_storerobbery:server:leoCount', function()
    return exports.qbx_core:GetDutyCountType('leo')
end)

CreateThread(function()
    while true do
        safeCodes = {}
        for i = 1, #sharedConfig.safes do
            local Safe = sharedConfig.safes[i]
            if Safe.type == 'padlock' then
                safeCodes[i] = {
                    math.random(150, 450),
                    math.random(1.0, 100.0),
                    math.random(360, 450),
                    math.random(300.0, 340.0),
                    math.random(350, 400),
                    math.random(320.0, 340.0),
                    math.random(350, 600)
                }
            elseif Safe.type == 'keypad' then
                safeCodes[i] = math.random(1000, 9999)
            else
                print(('[qbx_storerobbery] Invalid safe type at index %s'):format(i))
            end
        end
        Wait(config.safeRefresh.min)
    end
end)
