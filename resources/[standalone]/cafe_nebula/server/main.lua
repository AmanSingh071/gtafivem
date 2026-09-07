local function notify(src, description, ntype)
    TriggerClientEvent('ox_lib:notify', src, { title = 'Cafe Nebula', description = description, type = ntype or 'inform' })
end

RegisterNetEvent('cafe_nebula:server:purchase', function(key)
    local src = source
    local product = Config.Products[key]
    if not product then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local price = tonumber(product.price) or 0
    if price <= 0 then return end
    if not player.Functions.RemoveMoney('cash', price, 'cafe-nebula-purchase') then
        notify(src, ('You need $%s cash.'):format(price), 'error')
        return
    end

    local added = exports.ox_inventory:AddItem(src, product.item, product.amount or 1)
    if not added then
        player.Functions.AddMoney('cash', price, 'cafe-nebula-refund')
        notify(src, 'Your inventory cannot carry that item. Payment refunded.', 'error')
        return
    end

    notify(src, ('Purchased %s for $%s.'):format(product.label, price), 'success')
end)
