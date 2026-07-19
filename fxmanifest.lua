fx_version "cerulean"
game "gta5"
lua54 "yes"

name "Peak Chess"
author "Peak Studios"
description "Standalone playable chess (PvP + AI) with optional framework, target, bridge, and wagering integrations"
version "1.1.0"

escrow_ignore {
    "shared/sh.lua",
    "shared/locale.lua",
    "client/framework.lua",
    "server/framework.lua"
}

shared_scripts {
    "shared/sh.lua",
    "shared/locale.lua",
    "shared/engine.lua"
}

client_scripts {
    "client/framework.lua",
    "client/sound.lua",
    "client/main.lua",
    "client/raycast.lua",
    "client/sync.lua",
    "client/nui.lua",
    "client/exports.lua"
}

server_scripts {
    "server/framework.lua",
    "server/main.lua",
    "server/game.lua",
    "server/ai.lua",
    "server/betting.lua",
    "server/exports.lua"
}

ui_page "web/build/index.html"

files {
    "web/build/index.html",
    "web/build/**/*"
}
