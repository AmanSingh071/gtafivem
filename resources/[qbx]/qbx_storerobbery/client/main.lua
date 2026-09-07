local config = require 'config.client'
local sharedConfig = require 'config.shared'
local isUsingAdvanced
local openingRegister
local currentCombination
local safeUiOpen = false

local function releaseNuiFocus()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

local function forceCloseSafeUi(notifyServer)
    safeUiOpen = false
    currentCombination = nil
    releaseNuiFocus()
    SendNUIMessage({ action = 'closeKeypad' })
    if notifyServer then
        TriggerServerEvent('qbx_storerobbery:server:failedSafeCracking')
    end
end

local function startLockpick(bool)
    if bool then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ action = 'ui', toggle = true, advanced = isUsingAdvanced or false })
        SetCursorLocation(0.5, 0.5)
    else
        releaseNuiFocus()
        SendNUIMessage({ action = 'ui', toggle = false })
    end
end

local function openingRegisterHandler(lockpickTime)
    openingRegister = true
    lib.requestAnimDict('veh@break_in@0h@p_m_one@')
    CreateThread(function()
        while openingRegister do
            TaskPlayAnim(cache.ped, 'veh@break_in@0h@p_m_one@', 'low_force_entry_ds', 3.0, 3.0, -1, 16, 0, false, false, false)
            Wait(2000)
            lockpickTime = lockpickTime - 2000
            TriggerServerEvent('qbx_storerobbery:server:registerOpened', false)
            TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
            if lockpickTime <= 0 then
                openingRegister = false
                StopAnimTask(cache.ped, 'veh@break_in@0h@p_m_one@', 'low_force_entry_ds', 1.0)
                RemoveAnimDict('veh@break_in@0h@p_m_one@')
            end
        end
    end)
end

local function safeAnim()
    releaseNuiFocus()
    lib.requestAnimDict('amb@prop_human_bum_bin@idle_b')
    TaskPlayAnim(cache.ped, 'amb@prop_human_bum_bin@idle_b', 'idle_d', 8.0, 8.0, -1, 50, 0, false, false, false)
    Wait(2500)
    TaskPlayAnim(cache.ped, 'amb@prop_human_bum_bin@idle_b', 'exit', 8.0, 8.0, -1, 50, 0, false, false, false)
    RemoveAnimDict('amb@prop_human_bum_bin@idle_b')
    releaseNuiFocus()
end

local function checkInteractStatus(register)
    if sharedConfig.registers[register].robbed then return false end
    local leoCount = lib.callback.await('qbx_storerobbery:server:leoCount', false)
    return leoCount >= sharedConfig.minimumCops
end

local function alertPolice()
    local hours = GetClockHours()
    local chance = config.policeAlertChance
    if qbx.isWearingGloves() or (hours >= 1 and hours <= 6) then chance = config.policeNightAlertChance end
    if math.random() <= chance then TriggerServerEvent('police:server:policeAlert') end
end

local function dropFingerprint()
    if qbx.isWearingGloves() then return end
    if config.fingerprintChance > math.random(0, 100) then TriggerServerEvent('evidence:server:CreateFingerDrop', GetEntityCoords(cache.ped)) end
end

RegisterNetEvent('qbx_storerobbery:client:initRegisterAttempt', function(isAdvanced)
    isUsingAdvanced = isAdvanced
    startLockpick(true)
end)

RegisterNetEvent('qbx_storerobbery:client:initSafeAttempt', function(closestSafeIndex, combination)
    local safe = sharedConfig.safes[closestSafeIndex]
    if not safe or not combination then return end

    currentCombination = combination
    safeUiOpen = true

    if safe.type == 'keypad' then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ action = 'openKeypad' })
        SetCursorLocation(0.5, 0.5)
    else
        releaseNuiFocus()
        TriggerEvent('SafeCracker:StartMinigame', currentCombination)
    end
end)

RegisterNetEvent('qbx_storerobbery:client:safeResult', function(correct)
    if not safeUiOpen then return end

    if correct then
        -- Hide the UI first, then release focus. This prevents the player being trapped
        -- by a stale NUI focus after the success animation.
        safeUiOpen = false
        SendNUIMessage({ action = 'safeResult', correct = true })
        CreateThread(function()
            Wait(900)
            releaseNuiFocus()
            SendNUIMessage({ action = 'closeKeypad' })
            currentCombination = nil
        end)
    else
        -- Wrong code: remain in the keypad and keep focus for another attempt.
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ action = 'safeResult', correct = false })
    end
end)

RegisterNetEvent('SafeCracker:EndMinigame', function(hasWon)
    safeUiOpen = false
    currentCombination = nil
    releaseNuiFocus()
    if hasWon then
        TriggerServerEvent('qbx_storerobbery:server:safeCracked')
        safeAnim()
    else
        TriggerServerEvent('qbx_storerobbery:server:failedSafeCracking')
    end
end)

RegisterNetEvent('qbx_storerobbery:client:updatedRobbables', function(registers, safes)
    sharedConfig.registers = registers
    sharedConfig.safes = safes
end)

lib.callback.register('qbx_storerobbery:client:getAlertChance', function()
    local chance = config.policeAlertChance
    if GetClockHours() >= 1 and GetClockHours() <= 6 then chance = config.policeNightAlertChance end
    return chance
end)

RegisterNUICallback('success', function(_, cb)
    releaseNuiFocus()
    openingRegisterHandler(config.openRegisterTime)
    alertPolice()
    if lib.progressBar({
        duration = config.openRegisterTime,
        label = locale('text.emptying_the_register'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, mouse = false, combat = true }
    }) then
        openingRegister = false
        TriggerServerEvent('qbx_storerobbery:server:registerOpened', true)
    else
        openingRegister = false
        TriggerServerEvent('qbx_storerobbery:server:registerCanceled')
        exports.qbx_core:Notify(locale('error.process_canceled'), 'error')
    end
    releaseNuiFocus()
    cb('ok')
end)

RegisterNUICallback('fail', function(_, cb)
    releaseNuiFocus()
    dropFingerprint()
    alertPolice()
    TriggerServerEvent('qbx_storerobbery:server:registerFailed', isUsingAdvanced)
    cb('ok')
end)

RegisterNUICallback('exit', function(_, cb)
    releaseNuiFocus()
    TriggerServerEvent('qbx_storerobbery:server:registerExited')
    cb('ok')
end)

RegisterNUICallback('padLockClose', function(_, cb)
    forceCloseSafeUi(true)
    cb('ok')
end)

RegisterNUICallback('combinationFail', function(_, cb)
    local soundId = GetSoundId()
    PlaySound(soundId, 'Place_Prop_Fail', 'DLC_Dmod_Prop_Editor_Sounds', false, 0, true)
    ReleaseSoundId(soundId)
    cb('ok')
end)

RegisterNUICallback('tryCombination', function(data, cb)
    if not safeUiOpen then
        releaseNuiFocus()
        cb('ok')
        return
    end

    local entered = tonumber(data and data.combination)
    if not entered or not currentCombination then
        cb('ok')
        return
    end

    TriggerServerEvent('qbx_storerobbery:server:checkSafeCombination', entered)
    cb('ok')
end)

local function createRegisters()
    CreateThread(function()
        for k, v in pairs(sharedConfig.registers) do
            exports.ox_target:addBoxZone({
                coords = v.coords,
                size = vec3(1.5, 1.5, 1.5),
                rotation = 0.0,
                debug = config.debugPoly,
                options = {{
                    name = k .. '_register',
                    icon = 'cash-register',
                    label = 'Open Register',
                    canInteract = function() return checkInteractStatus(k) end,
                    serverEvent = 'qbx_storerobbery:server:checkStatus',
                }}
            })
        end
    end)
end

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= cache.resource then return end
    safeUiOpen = false
    currentCombination = nil
    releaseNuiFocus()
    createRegisters()
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= cache.resource then return end
    openingRegister = false
    safeUiOpen = false
    currentCombination = nil
    releaseNuiFocus()
    SendNUIMessage({ action = 'closeKeypad' })
end)

-- Emergency NUI watchdog. If the UI is unexpectedly left active, ESC/cancel still
-- works, and a dead player can never remain locked in the safe UI.
CreateThread(function()
    while true do
        if safeUiOpen then
            Wait(1000)
            if safeUiOpen and IsEntityDead(cache.ped) then
                forceCloseSafeUi(true)
            end
        else
            Wait(1500)
        end
    end
end)

CreateThread(function()
    local hasShownText
    while true do
        local coords = GetEntityCoords(cache.ped)
        local time, nearby = 800, false
        for i = 1, #sharedConfig.registers do
            if #(coords - sharedConfig.registers[i].coords) <= 1.4 and sharedConfig.registers[i].robbed then
                time, nearby = 0, true
                if config.useDrawText then
                    if not hasShownText then
                        hasShownText = true
                        lib.showTextUI(locale('text.register_empty'), { position = 'left-center' })
                    end
                else
                    qbx.drawText3d({ text = locale('text.register_empty'), coords = sharedConfig.registers[i].coords })
                end
            end
        end
        if not nearby and hasShownText then hasShownText = false lib.hideTextUI() end
        Wait(time)
    end
end)

CreateThread(function()
    local hasShownText
    while true do
        local coords = GetEntityCoords(cache.ped)
        local time, nearby, text = 800, false, nil
        for i = 1, #sharedConfig.safes do
            if #(coords - sharedConfig.safes[i].coords) <= 1.4 then
                time, nearby = 0, true
                if sharedConfig.safes[i].robbed then
                    text = locale('text.safe_opened')
                else
                    text = locale('text.try_combination')
                    if IsControlJustPressed(0, 38) then TriggerServerEvent('qbx_storerobbery:server:trySafe') end
                end
                if config.useDrawText then
                    if not hasShownText then
                        hasShownText = true
                        lib.showTextUI(text, { position = 'left-center' })
                    end
                else
                    qbx.drawText3d({ text = text, coords = sharedConfig.safes[i].coords })
                end
            end
        end
        if not nearby and hasShownText then hasShownText = false lib.hideTextUI() end
        Wait(time)
    end
end)
