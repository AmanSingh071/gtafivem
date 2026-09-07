# Cafe Nebula

Cafe Nebula is an open-world cafe resource for the Qbox server.

## Important

This version is deliberately **not a shell** and does not teleport the player to an interior. It composes a custom cafe layout directly in the GTA world from streamed vanilla GTA V props, so it can be placed on an open-world lot and interacted with from the normal map.

It is a gameplay-ready foundation, not a binary 3D artist-authored MLO (`.ydr/.ybn/.ymap`). A true bespoke mesh MLO requires custom 3D assets exported through a map pipeline such as Blender/CodeWalker. This resource avoids pretending that prop composition is a custom mesh.

## Install

Add this to the server configuration after the dependencies:

```cfg
ensure cafe_nebula
```

Dependencies:
- ox_lib
- qbx_core
- ox_inventory
- ox_target

## Location

The location is configured in `config.lua` using `Config.Center`. No shell routing or teleportation is used.

## Features

- Original open-world cafe layout
- Service counter
- Coffee machine interaction
- Patio seating
- Kitchen/staff interaction points
- Qbox cash purchases
- ox_inventory item delivery
- ox_target interactions
- Map blip
- Model validation and loading timeouts
- Resource-stop cleanup
- Server-side payment and inventory validation

## Products

The default menu uses `coffee` and `sandwich` inventory items. Change `Config.Products` if your inventory uses different item names.
