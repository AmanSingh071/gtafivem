local config = require 'config.server'
local sharedConfig = require 'config.shared'
local startedRegister = {}
local startedSafe = {}
local safeCodes = {}
local safeCodeUsed = {}
local playerProgress = {}
local activeChain = {}

-- The Davis/Strawberry LTD store has two physical safes:
-- Safe 2 = jewelry safe, Safe 3 = final safe.
-- Safe 3 can only be started after the same player has completed Safe 2.
local safeRequires = {
    [3] = 2,
}

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

local function clearSafeCode(index)
    local oldCode = safeCodes[index]
    if oldCode then
        if type(oldCode) == 'table' then
            safeCodeUsed[table.concat(oldCode, ':')] = nil
        else
            safeCodeUsed[oldCode] = nil
        end
    end
    safeCodes[index] = nil
end

local function resetRegister(index)
    if not index or not sharedConfig.registers[index] then return end
    sharedConfig.registers[index].robbed = false
    broadcastState()
end

local function resetSafe(index)
    if not index or not sharedConfig.safes[index] then return end
    sharedConfig.safes[index].robbed = false
    clearSafeCode(index)
    broadcastState()
end

local function resetSafeChain(rootIndex)
    local child
    for safeIndex, requiredIndex in pairs(safeRequires) do
        if requiredIndex == rootIndex then
            child = safeIndex
            break
        end
    end
    resetSafe(rootIndex)
    if child then resetSafe(child) end
end

local function generateUniqueKeypadCode()
    local code
    repeat
        code = math.random(1000, 9999)
    until not safeCodeUsed[code]
    safeCodeUsed[code] = true
    return code
end

local function generateSafeCode(index)
    local safe = sharedConfig.safes[index]
    if not safe then return nil end
    if safe.type == 'keypad' then return generateUniqueKeypadCode() end

    local code
    repeat
        code = {
            math.random(150, 450), math.random(1, 100), math.random(360, 450),
            math.random(300, 340), math.random(350, 400), math.random(320, 340), math.random(350, 600)
        }
        local key = table.concat(code, ':')
        if not safeCodeUsed[key] then
            safeCodeUsed[key] = true
            return code
        end
    until false
end

local function ensureSafeCode(index)
    if not sharedConfig.safes[index] then return nil end
    if not safeCodes[index] then safeCodes[index] = generateSafeCode(index) end
    return safeCodes[index]
end

local function getReadableCode(index)
    local safe = sharedConfig.safes[index]
    local code = ensureSafeCode(index)
    if safe.type == 'keypad' then return string.format('%04d', code) end
    return table.concat({
        tostring(math.floor((code[1] % 360) / 3.60)),
        tostring(math.floor((code[2] % 360) / 3.60)),
        tostring(math.floor((code[3] % 360) / 3.60)),
        tostring(math.floor((code[4] % 360) / 3.60)),
        tostring(math.floor((code[5] % 360) / 3.60))
    }, '-')
end

local function findSafeNote(src, safeIndex)
    local slots = exports.ox_inventory:Search(src, 'slots', 'stickynote')
    if not slots then return nil end
    local expected = safeCodes[safeIndex] and getReadableCode(safeIndex) or nil
    if not expected then return nil end
    for _, slot in pairs(slots) do
        local metadata = slot.metadata or {}
        if tonumber(metadata.safeIndex) == safeIndex and tostring(metadata.safeCode or '') == expected then
            return slot
        end
    end
    return nil
end

local function playerHasSafeNote(src, safeIndex)
    return findSafeNote(src, safeIndex) ~= nil
end

local function consumeSafeNote(src, safeIndex)
    local slot = findSafeNote(src, safeIndex)
    if not slot then return false end
    return exports.ox_inventory:RemoveItem(src, 'stickynote', 1, nil, slot.slot)
end

local function giveSafeNote(src, safeIndex, stageName)
    local readableCode = getReadableCode(safeIndex)
    local info = {
        label = ('%s • %s'):format(stageName, readableCode),
        description = ('Combination for %s: %s'):format(stageName, readableCode),
        safeIndex = safeIndex,
        safeCode = readableCode,
        robberyStage = safeRequires[safeIndex] and 2 or 1,
    }
    local added = exports.ox_inventory:AddItem(src, 'stickynote', 1, info)
    if added then
        exports.qbx_core:Notify(src, ('%s code found. Check your sticky note.'):format(stageName), 'success', 8000)
    else
        exports.qbx_core:Notify(src, ('%s combination: %s'):format(stageName, readableCode), 'success', 12000)
    end
    return added
end

RegisterNetEvent('qbx_storerobbery:server:checkStatus', function()
    local src = source
    local ped = GetPlayerPed(src)
    if ped <= 0 then return end
    local index = getClosestRegister(GetEntityCoords(ped))
    if not index or sharedConfig.registers[index].robbed or startedRegister[src] then return end

    local safeIndex = sharedConfig.registers[index].safeKey
    if safeIndex and sharedConfig.safes[safeIndex] and sharedConfig.safes[safeIndex].robbed then
        exports.qbx_core:Notify(src, 'The linked safe has already been looted. Wait for the store to reset.', 'error')
        return
    end

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
    if ped <= 0 or #(GetEntityCoords(ped) - sharedConfig.registers[index].coords) > 2.5 then
        startedRegister[src] = nil
        resetRegister(index)
        return
    end
    startedRegister[src] = nil
    resetRegister(index)
    local removalChance = isUsingAdvanced and math.random(0, 30) or math.random(0, 60)
    if removalChance > math.random(0, 100) then
        exports.qbx_core:Notify(src, locale('error.lockpick_broken'), 'error')
        exports.ox_inventory:RemoveItem(src, isUsingAdvanced and 'advancedlockpick' or 'lockpick', 1)
    end
end)

RegisterNetEvent('qbx_storerobbery:server:registerExited', function()
    local src = source
    local index = startedRegister[src]
    startedRegister[src] = nil
    if index then resetRegister(index) end
end)

RegisterNetEvent('qbx_storerobbery:server:registerCanceled', function()
    local src = source
    local index = startedRegister[src]
    startedRegister[src] = nil
    if index then resetRegister(index) end
end)

RegisterNetEvent('qbx_storerobbery:server:registerOpened', function(isDone)
    if not isDone then return end
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local ped = GetPlayerPed(src)
    local index = startedRegister[src]
    if not player or ped <= 0 or not index or not sharedConfig.registers[index] then return end
    if #(GetEntityCoords(ped) - sharedConfig.registers[index].coords) > 2.5 or not sharedConfig.registers[index].robbed then
        startedRegister[src] = nil
        resetRegister(index)
        return
    end

    player.Functions.AddMoney('cash', math.random(config.registerReward.min, config.registerReward.max))

    local safeIndex = sharedConfig.registers[index].safeKey
    if safeIndex and sharedConfig.safes[safeIndex] then
        local stageName = safeRequires[safeIndex] and 'Second Safe' or (safeIndex == 2 and 'Jewelry Safe' or ('Safe ' .. tostring(safeIndex)))
        giveSafeNote(src, safeIndex, stageName)
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

    local required = safeRequires[index]
    if required then
        if not playerProgress[src] or not playerProgress[src][required] then
            exports.qbx_core:Notify(src, 'Complete the Jewelry Safe first.', 'error')
            return
        end
    end

    if not playerHasSafeNote(src, index) then
        local stageName = safeRequires[index] and 'the second safe' or (index == 2 and 'the Jewelry Safe' or ('Safe ' .. index))
        exports.qbx_core:Notify(src, ('You need the sticky note for %s.'):format(stageName), 'error')
        return
    end

    local leoCount = exports.qbx_core:GetDutyCountType('leo')
    if leoCount < sharedConfig.minimumCops then
        if sharedConfig.notEnoughCopsNotify then exports.qbx_core:Notify(src, locale('error.no_police', { Required = sharedConfig.minimumCops }), 'error') end
        return
    end

    local code = ensureSafeCode(index)
    startedSafe[src] = index
    TriggerClientEvent('qbx_storerobbery:client:initSafeAttempt', src, index, code)
end)

RegisterNetEvent('qbx_storerobbery:server:failedSafeCracking', function()
    startedSafe[source] = nil
end)

local function giveFinalSafeReward(player, index)
    local worth = math.random(config.safeReward.markedBillsWorth.min, config.safeReward.markedBillsWorth.max)
    local amount = math.random(config.safeReward.markedBillsAmount.min, config.safeReward.markedBillsAmount.max)
    player.Functions.AddItem('markedbills', amount, false, { worth = worth, description = locale('text.value', { value = worth }) })

    if index == 2 then
        player.Functions.AddItem('rolex', math.random(config.safeReward.rolexAmount.min, config.safeReward.rolexAmount.max))
        player.Functions.AddItem('goldbar', 1)
        return
    end

    if config.safeReward.chanceAtSpecial > math.random(0, 100) then
        player.Functions.AddItem('rolex', math.random(config.safeReward.rolexAmount.min, config.safeReward.rolexAmount.max))
        if config.safeReward.chanceAtSpecial / 2 > math.random(0, 100) then
            player.Functions.AddItem('goldbar', config.safeReward.goldbarAmount)
        end
    end
end

local function completeSafe(src, enteredCode)
    local player = exports.qbx_core:GetPlayer(src)
    local ped = GetPlayerPed(src)
    local index = startedSafe[src]
    if not player or ped <= 0 or not index or not sharedConfig.safes[index] then return end

    if #(GetEntityCoords(ped) - sharedConfig.safes[index].coords) > 2.5 then
        startedSafe[src] = nil
        return
    end

    if sharedConfig.safes[index].robbed then
        startedSafe[src] = nil
        TriggerClientEvent('qbx_storerobbery:client:safeResult', src, false, 'This safe has already been looted.')
        return
    end

    local required = safeRequires[index]
    if required and (not playerProgress[src] or not playerProgress[src][required]) then
        startedSafe[src] = nil
        TriggerClientEvent('qbx_storerobbery:client:safeResult', src, false, 'Complete the first safe before this one.')
        return
    end

    if not playerHasSafeNote(src, index) then
        TriggerClientEvent('qbx_storerobbery:client:safeResult', src, false, 'Matching sticky note required.')
        return
    end

    local expected = ensureSafeCode(index)
    if not enteredCode or tonumber(enteredCode) ~= tonumber(expected) then
        TriggerClientEvent('qbx_storerobbery:client:safeResult', src, false, 'Incorrect code — try again.')
        return
    end

    consumeSafeNote(src, index)
    sharedConfig.safes[index].robbed = true
    startedSafe[src] = nil
    playerProgress[src] = playerProgress[src] or {}
    playerProgress[src][index] = true

    TriggerClientEvent('qbx_storerobbery:client:safeResult', src, true, index == 2 and 'Jewelry safe unlocked!' or 'Safe unlocked!')
    giveFinalSafeReward(player, index)

    local nextSafe = nil
    for child, parent in pairs(safeRequires) do
        if parent == index then
            nextSafe = child
            break
        end
    end

    if nextSafe and sharedConfig.safes[nextSafe] and not sharedConfig.safes[nextSafe].robbed then
        activeChain[src] = index
        giveSafeNote(src, nextSafe, 'Second Safe')
        exports.qbx_core:Notify(src, 'You found another combination. The second safe is now available.', 'success', 10000)
    else
        activeChain[src] = nil
        TriggerClientEvent('qbx_storerobbery:client:startGetaway', src, index)
    end

    broadcastState()

    local chainRoot = required or index
    if safeRequires[chainRoot] then chainRoot = safeRequires[chainRoot] end
    SetTimeout(math.random(config.safeRefresh.min, config.safeRefresh.max), function()
        resetSafeChain(chainRoot)
    end)
end

RegisterNetEvent('qbx_storerobbery:server:checkSafeCombination', function(enteredCode)
    completeSafe(source, enteredCode)
end)

RegisterNetEvent('qbx_storerobbery:server:safeCracked', function()
    completeSafe(source, nil)
end)

AddEventHandler('playerJoining', function()
    TriggerClientEvent('qbx_storerobbery:client:updatedRobbables', source, sharedConfig.registers, sharedConfig.safes)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local register = startedRegister[src]
    local safe = startedSafe[src]
    local chainRoot = activeChain[src]
    startedRegister[src] = nil
    startedSafe[src] = nil
    playerProgress[src] = nil
    activeChain[src] = nil
    if register then resetRegister(register) end
    if safe then startedSafe[src] = nil end
    if chainRoot then resetSafeChain(chainRoot) end
end)

lib.callback.register('qbx_storerobbery:server:leoCount', function()
    return exports.qbx_core:GetDutyCountType('leo')
end)

CreateThread(function()
    math.randomseed(os.time() + GetGameTimer())
end)