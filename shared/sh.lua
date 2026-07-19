Shared = Shared or {}

Shared.Framework = {
    autoDetect = true,
    PeakBridge = false,
    ESX        = false,
    QBCore     = false,
    Qbox       = false,
    Standalone = false,
}

function Shared.ActiveFramework()
    if Shared.Framework.autoDetect then
        if GetResourceState('peak-bridge') == 'started' then return 'PeakBridge' end
        if GetResourceState('es_extended') == 'started' then return 'ESX' end
        if GetResourceState('qbx_core') == 'started' then return 'Qbox' end
        if GetResourceState('qb-core') == 'started' then return 'QBCore' end
        return 'Standalone'
    end
    if Shared.Framework.PeakBridge then return 'PeakBridge' end
    if Shared.Framework.ESX then return 'ESX' end
    if Shared.Framework.QBCore then return 'QBCore' end
    if Shared.Framework.Qbox then return 'Qbox' end
    return 'Standalone'
end

Config = {}

Config.Debug  = false
Config.Locale = 'en'

Config.Models = {
    table = 'bzzz_chess_table_a',
    board = 'bzzz_chess_board_a',
    chair = 'bzzz_chess_chair_a',
    pieces = {
        w = { p = 'bzzz_chess_color_a1', r = 'bzzz_chess_color_a2', n = 'bzzz_chess_color_a3',
              b = 'bzzz_chess_color_a4', q = 'bzzz_chess_color_a5', k = 'bzzz_chess_color_a6' },
        b = { p = 'bzzz_chess_color_b1', r = 'bzzz_chess_color_b2', n = 'bzzz_chess_color_b3',
              b = 'bzzz_chess_color_b4', q = 'bzzz_chess_color_b5', k = 'bzzz_chess_color_b6' },
    },
    captureTray = {
        w = vec3(-0.32, -0.21, 0.002),
        b = vec3( 0.32,  0.21, 0.002),
    },
    captureRowGap = 0.055,
    capturePerRow = 5,
}

Config.Board = {
    a1Offset = vec3(-0.21, -0.21, 0.002),
    step     = 0.06,
    onTable  = vec3(0.0, 0.0, 0.40),
    captureGap = 0.055,
}

Config.Anim = {
    dict = 'bzzz_chess_animations',
    idle = 'bzzz_chess_sit_a',
    move = 'bzzz_chess_sit_b',
    getUp = nil,
}

Config.Seats = {
    white = { offset = vec3(0.0, -0.595, -0.400), heading = 0.0 },
    black = { offset = vec3(0.0,  0.595, -0.400), heading = 180.0 },
}

Config.Sit = {
    pedOffset  = vec3(0.0, 0.0, 0.425),
    pedHeading = 0.0,
    hideSelf   = true,
}

Config.Camera = {
    height      = 0.90,
    distance    = 0.60,
    fov         = 32.0,
    dragLift    = 0.03,
    sceneEnabled = true,
    scene = { radius = 1.9, height = 1.0, fov = 45.0, speed = 10.0 },
}

Config.Spotlight = {
    enabled    = true,
    nightOnly  = true,
    nightStart = 20,
    nightEnd   = 7,
    height     = 3,
    color      = { 255, 240, 210 },
    distance   = 7.0,
    brightness = 30.0,
    hardness   = 0.0,
    radius     = 25.0,
    falloff    = 18.0,
}

Config.Sound = {
    enabled = true,
    open    = { 'Hint_Activate', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    select  = { 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    confirm = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    grab    = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    move    = { 'Place_Prop_Down', 'DLC_Dmod_Prop_Editor_Sounds' },
    capture = { 'Pickup_Weapon_Pistol', 'HUD_FRONTEND_WEAPONS_PICKUPS_SOUNDSET' },
    check   = { 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET' },
    win     = { 'CHALLENGE_UNLOCKED', 'HUD_AWARDS' },
    lose    = { 'ScreenFlash', 'WastedSounds' },
}

Config.Spawn = {
    streamDistance = 60.0,
    despawnDistance = 90.0,
    snapToGround = false,
    zOffset      = 0.0,
    groundProbe  = 8.0,
    placeChairsOnGround = true,
}

Config.Locations = {
    { coords = vec3(-1319.881348, -925.411011, 11.19995 -1.0), heading = 104.881889, blip = true },
}

Config.Blip = { sprite = 89, color = 2, scale = 0.8, name = 'Chess Table' }

Config.Interact = {
    sitDistance   = 2.0,
    spectateDistance = 6.0,
    maxAimDistance = 3.5,
    selectKey     = 24,
    cancelKey     = 25,
    leaveKey      = 73,
    colors = {
        hover    = { 255, 255, 255, 90 },
        selected = { 96, 215, 150, 160 },
        legal    = { 96, 215, 150, 90 },
        capture  = { 235, 90, 90, 120 },
        check     = { 235, 160, 60, 140 },
        lastMove  = { 96, 215, 150, 50 },
    },
    markerZ = 0.012,
}

Config.Target = {
    -- 'drawtext' has no dependency. Use 'auto', 'ox_target', 'qb-target', or 'var-interact' for optional target integrations.
    system           = 'drawtext',
    key              = 38,
    showDistance     = 12.0,
    interactDistance = 2.0,
    radius           = 1.2,
    heightOffset     = 0.9,
    icon             = 'game',
    color            = '#60d796',
    oxIcon           = 'fa-solid fa-chess',
}

Config.Betting = {
    enabled  = true,
    account  = 'cash',
    min      = 0,
    max      = 50000,
    presets  = { 0, 100, 500, 1000, 5000 },
    houseCut = 0.0,
    drawRefund = true,
}

Config.AI = {
    enabled = true,
    peds = { 'a_m_y_business_01', 'a_m_m_business_01', 's_m_m_highsec_01', 'a_m_y_genstreet_01' },
    levels = {
        { id = 'easy',   depth = 2, randomness = 0.35, moveDelay = { 1800, 3500 } },
        { id = 'medium', depth = 3, randomness = 0.12, moveDelay = { 2200, 4500 } },
        { id = 'hard',   depth = 4, randomness = 0.0,  moveDelay = { 2800, 6000 } },
    },
    maxThinkMs = 1500,
}
