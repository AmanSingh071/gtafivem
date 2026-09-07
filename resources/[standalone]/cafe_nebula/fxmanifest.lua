fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'AmanSingh071'
description 'Cafe Nebula - open-world custom cafe built from streamed GTA props with Qbox/OX interactions'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'ox_lib',
    'qbx_core',
    'ox_inventory',
    'ox_target'
}
