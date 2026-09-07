local spawned = {}
local zones = {}
local insideCafe = false

local function notify(description, ntype)
    lib.notify({ title = 'Cafe Nebula', description = description, type = ntype or 'inform' })
end

local function requestModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(50) end
    return HasModelLoaded(hash)
end

local function createProp(data)
    if not requestModel(data.model) then
        print(('[cafe_nebula] model failed: %s'):format(data.model))
        return nil
    end
    local obj = CreateObject(joaat(data.model), data.pos.x, data.pos.y, data.pos.z, false, false, false)
    if not DoesEntityExist(obj) then
        print(('[cafe_nebula] object failed: %s'):format(data.model))
        SetModelAsNoLongerNeeded(joaat(data.model))
        return nil
    end
    SetEntityHeading(obj, data.rot.z or 0.0)
    SetEntityRotation(obj, data.rot.x or 0.0, data.rot.y or 0.0, data.rot.z or 0.0, 2, true)
    if data.freeze then FreezeEntityPosition(obj, true) end
    SetEntityAsMissionEntity(obj, true, true)
    spawned[#spawned + 1] = obj
    SetModelAsNoLongerNeeded(joaat(data.model))
    return obj
end

local function addZone(name, coords, label, icon, callback)
    local id = exports.ox_target:addSphereZone({
        coords = coords,
        radius = 1.25,
        debug = false,
        options = {{ name = name, icon = icon, label = label, distance = Config.InteractionDistance, onSelect = callback }}
    })
    zones[#zones + 1] = id
end

local function buyProduct(key)
    local product = Config.Products[key]
    if not product then return end
    TriggerServerEvent('cafe_nebula:server:purchase', key)
end

local function openMenu()
    lib.registerContext({
        id = 'cafe_nebula_menu',
        title = '☕ Cafe Nebula',
        options = {
            { title = 'Nebula Espresso — $35', description = 'Short, strong and hot.', icon = 'mug-hot', onSelect = function() buyProduct('espresso') end },
            { title = 'Vanilla Latte — $55', description = 'Smooth coffee with vanilla.', icon = 'mug-hot', onSelect = function() buyProduct('latte') end },
            { title = 'Fresh Pastry — $45', description = 'A quick cafe bite.', icon = 'cookie-bite', onSelect = function() buyProduct('pastry') end },
            { title = 'Cafe Breakfast — $80', description = 'A full breakfast plate.', icon = 'utensils', onSelect = function() buyProduct('breakfast') end }
        }
    })
    lib.showContext('cafe_nebula_menu')
end

local function makeCoffee()
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, 'PROP_HUMAN_BUM_BIN', 0, true)
    lib.progressCircle({ duration = 3500, label = 'Preparing coffee...', position = 'bottom', useWhileDead = false, canCancel = true, disable = { move = true, combat = true } })
    ClearPedTasks(ped)
    notify('The machine hums. Your coffee is ready.', 'success')
end

local function togglePatio()
    insideCafe = not insideCafe
    notify(insideCafe and 'Patio atmosphere enabled.' or 'Patio atmosphere disabled.', 'inform')
end

local function createBlip()
    if not Config.Blip.enabled then return end
    local blip = AddBlipForCoord(Config.Center.x, Config.Center.y, Config.Center.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.colour)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Blip.label)
    EndTextCommandSetBlipName(blip)
end

CreateThread(function()
    Wait(1000)
    for _, prop in ipairs(Config.Props) do createProp(prop) Wait(20) end
    createBlip()

    addZone('cafe_nebula_counter', Config.Interactions.counter, 'Order at Cafe Nebula', 'fa-solid fa-mug-hot', openMenu)
    addZone('cafe_nebula_machine', Config.Interactions.coffeeMachine, 'Prepare Coffee', 'fa-solid fa-mug-saucer', makeCoffee)
    addZone('cafe_nebula_kitchen', Config.Interactions.kitchen, 'Kitchen', 'fa-solid fa-utensils', function()
        notify('Kitchen is staff-only. Ask the manager for access.', 'inform')
    end)
    addZone('cafe_nebula_patio', Config.Interactions.patio, 'Use Patio', 'fa-solid fa-chair', togglePatio)
    addZone('cafe_nebula_staff', Config.Interactions.staffDoor, 'Staff Area', 'fa-solid fa-door-open', function()
        notify('Staff area is locked.', 'error')
    end)
end)

CreateThread(function()
    while true do
        local sleep = 1500
        local coords = GetEntityCoords(PlayerPedId())
        if #(coords - Config.Center) < Config.DrawDistance then
            sleep = 500
            DrawMarker(2, Config.Center.x, Config.Center.y, Config.Center.z + 2.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.16, 0.16, 0.16, 255, 255, 255, 160, false, true, 2, false, nil, nil, false)
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, id in ipairs(zones) do pcall(function() exports.ox_target:removeZone(id) end) end
    for _, obj in ipairs(spawned) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
end)
