local config = require 'config.server'
local sharedConfig = require 'config.shared'
local startedRegister = {}
local startedSafe = {}
local safeCodes = {}

local function getClosestRegister(coords)
    local closest
    for i = 1, #sharedConfig.registers do
        local distance = #(coords - sharedConfig.registers[i].coords)
        if distance <= 2 and (not closest or distance < #(coords - sharedConfig.registers[closest].coords)) then closest = i end
    end
    return closest
end

local function getClosestSafe(coords)
    local closest
    for i = 1, #sharedConfig.safes do
        local distance = #(coords - sharedConfig.safes[i].coords)
        if distance <= 2 and (not closest or distance < #(coords - sharedConfig.safes[closest].coords)) then closest = i end
    end
    return closest
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
    safeCodes[index] = nil
    broadcastState()
end

local function generateUniqueKeypadCode()
    local used = {}
    for _, code in pairs(safeCodes) do if type(code) == 'number' then used[code] = true end end
    local code
    repeat code = math.random(1000, 9999) until not used[code]
    return code
end

local function generateSafeCode(index)
    local Safe = sharedConfig.safes[index]
    if not Safe then return nil end
    if Safe.type == 'keypad' then return generateUniqueKeypadCode() end
    local code
    repeat
        code = { math.random(150, 450), math.random(1, 100), math.random(360, 450), math.random(300, 340), math.random(350, 400), math.random(320, 340), math.random(350, 600) }
        local duplicate = false
        for _, existing in pairs(safeCodes) do
            if type(existing) == 'table' and #existing == #code then
                duplicate = true
                for i = 1, #code do if code[i] ~= existing[i] then duplicate = false break end end
                if duplicate then break end
            end
        end
        if not duplicate then return code end
    until false
end

local function ensureSafeCode(index)
    if not safeCodes[index] then safeCodes[index] = generateSafeCode(index) end
    return safeCodes[index]
end

local function getReadableCode(index)
    local code = ensureSafeCode(index)
    if sharedConfig.safes[index].type == 'keypad' then return string.format('%04d', code) end
    return table.concat({ tostring(math.floor((code[1] % 360) / 3.60)), tostring(math.floor((code[2] % 360) / 3.60)), tostring(math.floor((code[3] % 360) / 3.60)), tostring(math.floor((code[4] % 360) / 3.60)), tostring(math.floor((code[5] % 360) / 3.60)) }, '-')
end

local function playerHasSafeNote(src, safeIndex)
    local slots = exports.ox_inventory:Search(src, 'slots', 'stickynote')
    if not slots then return false end
    local expected = getReadableCode(safeIndex)
    for _, slot in pairs(slots) do
        local metadata = slot.metadata or {}
        local label = tostring(metadata.label or '')
        local description = tostring(metadata.description or '')
        local noteSafe = tonumber(metadata.safeIndex)
        local noteCode = tostring(metadata.safeCode or '')
        if noteSafe == safeIndex and noteCode == expected then return true end
        if label:find(expected, 1, true) and (not noteSafe or noteSafe == safeIndex) then return true end
        if description:find(expected, 1, true) and (not noteSafe or noteSafe == safeIndex) then return true end
    end
    return false
end

RegisterNetEvent('qbx_storerobbery:server:checkStatus', function()
    local src = source
    local ped = GetPlayerPed(src)
    if ped <= 0 then return end
    local index = getClosestRegister(GetEntityCoords(ped))
    if not index or sharedConfig.registers[index].robbed or startedRegister[src] then return end
    local leoCount = exports.qbx_core:GetDutyCountType('leo')
    if leoCount < sharedConfig.minimumCops then
        if sharedConfig.notEnoughCopsNotify then exports.qbx_core:Notify(src, locale('error.no_police', { Required = sharedConfig.minimumCops }), 'error') end
        return
    end
    local hasLockpick = exports.ox_inventory:Search(src, 'count', 'lockpick') > 0
    local hasAdvanced = exports.ox_inventory:Search(src, 'count', 'advancedlockpick') > 0
    if not hasLockpick and not hasAdvanced then
        exports.qbx_core:Notify(src, 'You don\'t have the appropriate items', 'error')
        return
    end
    startedRegister[src] = index
    sharedConfig.registers[index].robbed = true
    broadcastState()
    TriggerClientEvent('qbx_storerobbery:client:initRegisterAttempt', src, hasAdvanced and not hasLockpick)
end)

RegisterNetEvent('qbx_storerobbery:server:registerFailed', function(isUsingAdvanced)
    local src = source
    local index = startedRegister[src]
    if not index then return end
    local ped = GetPlayerPed(src)
    if ped <= 0 or #(GetEntityCoords(ped) - sharedConfig.registers[index].coords) > 2.5 then startedRegister[src] = nil resetRegister(index) return end
    startedRegister[src] = nil
    sharedConfig.registers[index].robbed = false
    local removalChance = isUsingAdvanced and math.random(0, 30) or math.random(0, 60)
    if removalChance > math.random(0, 100) then
        exports.qbx_core:Notify(src, locale('error.lockpick_broken'), 'error')
        exports.ox_inventory:RemoveItem(src, isUsingAdvanced and 'advancedlockpick' or 'lockpick', 1)
    end
    broadcastState()
end)

RegisterNetEvent('qbx_storerobbery:server:registerExited', function()
    local src = source local index = startedRegister[src] startedRegister[src] = nil if index then resetRegister(index) end
end)

RegisterNetEvent('qbx_storerobbery:server:registerCanceled', function()
    local src = source local index = startedRegister[src] startedRegister[src] = nil if index then resetRegister(index) end
end)

RegisterNetEvent('qbx_storerobbery:server:registerOpened', function(isDone)
    if not isDone then return end
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local ped = GetPlayerPed(src)
    local index = startedRegister[src]
    if not player or ped <= 0 or not index or not sharedConfig.registers[index] then return end
    if #(GetEntityCoords(ped) - sharedConfig.registers[index].coords) > 2.5 or not sharedConfig.registers[index].robbed then startedRegister[src] = nil resetRegister(index) return end
    player.Functions.AddMoney('cash', math.random(config.registerReward.min, config.registerReward.max))
    local safeIndex = sharedConfig.registers[index].safeKey
    if safeIndex and sharedConfig.safes[safeIndex] then
        local readableCode = getReadableCode(safeIndex)
        local info = { label = locale('text.safe_code') .. readableCode, description = ('Safe %s combination: %s'):format(safeIndex, readableCode), safeIndex = safeIndex, safeCode = readableCode }
        local added = exports.ox_inventory:AddItem(src, 'stickynote', 1, info)
        if added then exports.qbx_core:Notify(src, ('Safe %s clue acquired. Check your sticky note.'):format(safeIndex), 'success') else exports.qbx_core:Notify(src, ('SAFE %s COMBINATION: %s'):format(safeIndex, readableCode), 'success', 12000) end
    end
    startedRegister[src] = nil
    broadcastState()
    SetTimeout(math.random(config.registerRefresh.min, config.registerRefresh.max), function() resetRegister(index) end)
end)

RegisterNetEvent('qbx_storerobbery:server:trySafe', function()
    local src = source
    local ped = GetPlayerPed(src)
    if ped <= 0 or startedSafe[src] then return end
    local index = getClosestSafe(GetEntityCoords(ped))
    if not index or sharedConfig.safes[index].robbed then return end
    -- Each safe is independent. The only key required is the clue from its own linked register.
    if not playerHasSafeNote(src, index) then
        exports.qbx_core:Notify(src, ('This safe is locked. Rob its linked register first and find the Safe %s code.'):format(index), 'error')
        return
    end
    local leoCount = exports.qbx_core:GetDutyCountType('leo')
    if leoCount < sharedConfig.minimumCops then
        if sharedConfig.notEnoughCopsNotify then exports.qbx_core:Notify(src, locale('error.no_police', { Required = sharedConfig.minimumCops }), 'error') end
        return
    end
    local code = ensureSafeCode(index)
    startedSafe[src] = index
    sharedConfig.safes[index].robbed = true
    broadcastState()
    TriggerClientEvent('qbx_storerobbery:client:initSafeAttempt', src, index, code)
end)

RegisterNetEvent('qbx_storerobbery:server:failedSafeCracking', function()
    local src = source local index = startedSafe[src] startedSafe[src] = nil if index then resetSafe(index) end
end)

local function completeKeypadSafe(src, enteredCode)
    local player = exports.qbx_core:GetPlayer(src)
    local ped = GetPlayerPed(src)
    local index = startedSafe[src]
    if not player or ped <= 0 or not index or not sharedConfig.safes[index] then return end
    if #(GetEntityCoords(ped) - sharedConfig.safes[index].coords) > 2.5 then startedSafe[src] = nil resetSafe(index) return end
    if not sharedConfig.safes[index].robbed then startedSafe[src] = nil return end
    if not playerHasSafeNote(src, index) then TriggerClientEvent('qbx_storerobbery:client:safeResult', src, false, 'You need the matching safe note.') return end
    local expected = ensureSafeCode(index)
    if sharedConfig.safes[index].type == 'keypad' and tonumber(enteredCode) ~= tonumber(expected) then
        TriggerClientEvent('qbx_storerobbery:client:safeResult', src, false, 'Incorrect code — try again.')
        return
    end
    TriggerClientEvent('qbx_storerobbery:client:safeResult', src, true, 'Safe unlocked!')
    local worth = math.random(config.safeReward.markedBillsWorth.min, config.safeReward.markedBillsWorth.max)
    local amount = math.random(config.safeReward.markedBillsAmount.min, config.safeReward.markedBillsAmount.max)
    player.Functions.AddItem('markedbills', amount, false, { worth = worth, description = locale('text.value', { value = worth }) })
    if config.safeReward.chanceAtSpecial > math.random(0, 100) then
        player.Functions.AddItem('rolex', math.random(config.safeReward.rolexAmount.min, config.safeReward.rolexAmount.max))
        if config.safeReward.chanceAtSpecial / 2 > math.random(0, 100) then player.Functions.AddItem('goldbar', config.safeReward.goldbarAmount) end
    end
    TriggerClientEvent('qbx_storerobbery:client:startGetaway', src, index)
    startedSafe[src] = nil
    broadcastState()
    SetTimeout(math.random(config.safeRefresh.min, config.safeRefresh.max), function() resetSafe(index) end)
end

RegisterNetEvent('qbx_storerobbery:server:checkSafeCombination', function(enteredCode) completeKeypadSafe(source, enteredCode) end)
RegisterNetEvent('qbx_storerobbery:server:safeCracked', function() completeKeypadSafe(source, nil) end)

AddEventHandler('playerJoining', function()
    TriggerClientEvent('qbx_storerobbery:client:updatedRobbables', source, sharedConfig.registers, sharedConfig.safes)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local register = startedRegister[src]
    local safe = startedSafe[src]
    startedRegister[src] = nil
    startedSafe[src] = nil
    if register then resetRegister(register) end
    if safe then resetSafe(safe) end
end)

lib.callback.register('qbx_storerobbery:server:leoCount', function()
    return exports.qbx_core:GetDutyCountType('leo')
end)

CreateThread(function()
    math.randomseed(os.time())
    for i = 1, #sharedConfig.safes do ensureSafeCode(i) end
end)
