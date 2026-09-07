Config = {}

Config.Center = vec3(-1223.80, -907.20, 12.33)
Config.Heading = 35.0
Config.DrawDistance = 80.0
Config.InteractionDistance = 2.0
Config.BuildHeight = 0.0

Config.Blip = {
    enabled = true,
    sprite = 93,
    colour = 27,
    scale = 0.78,
    label = 'Cafe Nebula'
}

Config.Products = {
    espresso = { label = 'Nebula Espresso', item = 'coffee', price = 35, amount = 1 },
    latte = { label = 'Vanilla Latte', item = 'coffee', price = 55, amount = 1 },
    pastry = { label = 'Fresh Pastry', item = 'sandwich', price = 45, amount = 1 },
    breakfast = { label = 'Cafe Breakfast', item = 'sandwich', price = 80, amount = 1 }
}

Config.Interactions = {
    counter = vec3(-1222.35, -907.95, 13.05),
    coffeeMachine = vec3(-1222.75, -908.45, 13.05),
    kitchen = vec3(-1220.65, -910.05, 13.05),
    patio = vec3(-1226.45, -903.80, 12.70),
    staffDoor = vec3(-1219.85, -911.25, 13.00)
}

-- Prop-built open-world composition. Invalid prop_bar_01 removed after live-server model validation.
Config.Props = {
    { model = 'prop_table_03', pos = vec3(-1222.15, -908.10, 12.58), rot = vec3(0.0, 0.0, 35.0), freeze = true },
    { model = 'prop_table_03', pos = vec3(-1223.10, -908.75, 12.58), rot = vec3(0.0, 0.0, 35.0), freeze = true },
    { model = 'prop_table_03', pos = vec3(-1222.65, -907.70, 12.58), rot = vec3(0.0, 0.0, 35.0), freeze = true },
    { model = 'prop_coffee_mac_02', pos = vec3(-1222.45, -908.30, 13.42), rot = vec3(0.0, 0.0, 35.0), freeze = true },
    { model = 'prop_food_bs_tray_01', pos = vec3(-1222.90, -908.55, 13.40), rot = vec3(0.0, 0.0, 35.0), freeze = true },
    { model = 'prop_table_03', pos = vec3(-1225.10, -909.65, 12.58), rot = vec3(0.0, 0.0, 0.0), freeze = true },
    { model = 'prop_table_03', pos = vec3(-1227.10, -908.25, 12.58), rot = vec3(0.0, 0.0, 90.0), freeze = true },
    { model = 'prop_chair_01a', pos = vec3(-1224.55, -909.70, 12.58), rot = vec3(0.0, 0.0, 180.0), freeze = true },
    { model = 'prop_chair_01a', pos = vec3(-1225.65, -909.70, 12.58), rot = vec3(0.0, 0.0, 0.0), freeze = true },
    { model = 'prop_chair_01a', pos = vec3(-1227.10, -907.55, 12.58), rot = vec3(0.0, 0.0, 270.0), freeze = true },
    { model = 'prop_chair_01a', pos = vec3(-1227.10, -908.95, 12.58), rot = vec3(0.0, 0.0, 90.0), freeze = true },
    { model = 'prop_plant_int_01a', pos = vec3(-1226.90, -910.25, 12.58), rot = vec3(0.0, 0.0, 20.0), freeze = true },
    { model = 'prop_plant_int_01a', pos = vec3(-1224.10, -907.10, 12.58), rot = vec3(0.0, 0.0, 160.0), freeze = true },
    { model = 'prop_table_03', pos = vec3(-1227.30, -903.95, 12.40), rot = vec3(0.0, 0.0, 25.0), freeze = true },
    { model = 'prop_chair_01a', pos = vec3(-1226.75, -904.05, 12.40), rot = vec3(0.0, 0.0, 205.0), freeze = true },
    { model = 'prop_chair_01a', pos = vec3(-1227.80, -903.55, 12.40), rot = vec3(0.0, 0.0, 25.0), freeze = true },
    { model = 'prop_plant_int_01a', pos = vec3(-1228.15, -904.85, 12.40), rot = vec3(0.0, 0.0, 330.0), freeze = true },
    { model = 'prop_table_03', pos = vec3(-1220.75, -910.25, 12.58), rot = vec3(0.0, 0.0, 90.0), freeze = true },
    { model = 'prop_cs_kitchen_cab_l', pos = vec3(-1220.10, -910.70, 12.60), rot = vec3(0.0, 0.0, 0.0), freeze = true },
    { model = 'prop_cs_kitchen_cab_l2', pos = vec3(-1220.10, -911.20, 12.60), rot = vec3(0.0, 0.0, 0.0), freeze = true },
    { model = 'prop_plant_int_01a', pos = vec3(-1219.65, -910.00, 12.58), rot = vec3(0.0, 0.0, 60.0), freeze = true }
}
