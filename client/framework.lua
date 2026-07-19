Framework = {}

local ESX, QBCore, Qbox
local activeFramework = Shared.ActiveFramework()

local function bridgeReady()
    if GetResourceState("peak-bridge") ~= "started" then
        return false
    end

    local ok, ready = pcall(function()
        return exports["peak-bridge"]:IsReady()
    end)

    return ok and ready == true
end

local function bridgeCall(exportName, ...)
    if not bridgeReady() then
        return false, nil
    end

    local args = { ... }
    local ok, result = pcall(function()
        return exports["peak-bridge"][exportName](table.unpack(args))
    end)

    return ok, result
end

if activeFramework == "ESX" or (activeFramework == "PeakBridge" and GetResourceState("es_extended") == "started") then
    ESX = exports["es_extended"]:getSharedObject()
elseif activeFramework == "QBCore" or (activeFramework == "PeakBridge" and GetResourceState("qb-core") == "started") then
    QBCore = exports["qb-core"]:GetCoreObject()
elseif activeFramework == "Qbox" or (activeFramework == "PeakBridge" and GetResourceState("qbx_core") == "started") then
    Qbox = exports.qbx_core
end

function Framework.Notify(msg, kind)
    local ok = bridgeCall("Notify", msg, kind or "info", 5000, "Peak Chess")
    if ok then
        return
    end

    if ESX then
        ESX.ShowNotification(msg)
    elseif QBCore then
        QBCore.Functions.Notify(msg, kind or "primary")
    elseif Qbox then
        Qbox:Notify(msg, kind or "inform", 5000)
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentSubstringPlayerName(msg)
        DrawNotification(false, true)
    end
end

function Framework.HasMoneyProvider()
    local ok, bridgeFramework = bridgeCall("GetFrameworkName")
    if ok and bridgeFramework then
        return bridgeFramework ~= "standalone"
    end

    return ESX ~= nil or QBCore ~= nil or Qbox ~= nil
end

RegisterNetEvent("peak-chess:notify", function(msg, kind)
    Framework.Notify(msg, kind)
end)

Framework.Target = {}

local specs = {}
local registered = {}
local suspended = false

local function varInteractResource()
    if GetResourceState("Var-Interact") == "started" then return "Var-Interact" end
    if GetResourceState("var-interact") == "started" then return "var-interact" end
    return nil
end

function Framework.Target._System()
    local configured = (Config.Target and Config.Target.system) or "drawtext"
    if configured == "qb_target" then configured = "qb-target" end
    if configured == "var_interact" or configured == "Var-Interact" then configured = "var-interact" end

    if configured ~= "auto" then
        return configured
    end

    if GetResourceState("ox_target") == "started" then return "ox_target" end
    if GetResourceState("qb-target") == "started" then return "qb-target" end
    if varInteractResource() then return "var-interact" end

    return "drawtext"
end

function Framework.Target.IsNative()
    return Framework.Target._System() == "drawtext"
end

function Framework.Target._CreatePoint(id)
    local spec = specs[id]
    if not spec or registered[id] ~= nil then return end

    local target = Config.Target
    local position = vec3(spec.coords.x, spec.coords.y, spec.coords.z + (target.heightOffset or 0.0))
    local system = Framework.Target._System()

    if system == "var-interact" then
        local resourceName = varInteractResource()
        if not resourceName then return end

        local ok, handle = pcall(function()
            return exports[resourceName]:interactCreate({
                coords      = position,
                message     = Shared.L("target_label"),
                key         = target.key or 38,
                showIcon    = target.showDistance or 12.0,
                canInteract = target.interactDistance or 2.0,
                hintIcon    = target.icon or "game",
                hintColor   = target.color or "#60d796",
                onInteract  = function() spec.onSelect() end,
            })
        end)

        if ok then registered[id] = handle end
    elseif system == "ox_target" then
        if GetResourceState("ox_target") ~= "started" then return end

        local ok, handle = pcall(function()
            return exports.ox_target:addSphereZone({
                coords  = position,
                radius  = target.radius or 1.2,
                debug   = Config.Debug or false,
                options = { {
                    name     = ("peak-chess_%s"):format(id),
                    icon     = target.oxIcon or "fa-solid fa-chess",
                    label    = Shared.L("target_label"),
                    distance = target.interactDistance or 2.0,
                    onSelect = function() spec.onSelect() end,
                } },
            })
        end)

        if ok then registered[id] = handle end
    elseif system == "qb-target" then
        if GetResourceState("qb-target") ~= "started" then return end

        local zoneName = ("peak-chess_%s"):format(id)
        local ok = pcall(function()
            exports["qb-target"]:AddCircleZone(zoneName, position, target.radius or 1.2, {
                name = zoneName,
                debugPoly = Config.Debug or false,
                useZ = true,
            }, {
                options = { {
                    icon = target.oxIcon or "fa-solid fa-chess",
                    label = Shared.L("target_label"),
                    action = function() spec.onSelect() end,
                } },
                distance = target.interactDistance or 2.0,
            })
        end)

        if ok then registered[id] = zoneName end
    end
end

function Framework.Target._DestroyPoint(id)
    local handle = registered[id]
    if handle == nil then return end

    local system = Framework.Target._System()

    if system == "var-interact" then
        local resourceName = varInteractResource()
        if resourceName then
            pcall(function() exports[resourceName]:interactRemove(handle) end)
        end
    elseif system == "ox_target" and GetResourceState("ox_target") == "started" then
        pcall(function() exports.ox_target:removeZone(handle) end)
    elseif system == "qb-target" and GetResourceState("qb-target") == "started" then
        pcall(function() exports["qb-target"]:RemoveZone(handle) end)
    end

    registered[id] = nil
end

function Framework.Target.Register(id, coords, onSelect)
    specs[id] = { coords = coords, onSelect = onSelect }
    if not suspended then Framework.Target._CreatePoint(id) end
end

function Framework.Target.Suspend()
    if suspended then return end
    suspended = true
    for id in pairs(specs) do Framework.Target._DestroyPoint(id) end
end

function Framework.Target.Resume()
    if not suspended then return end
    suspended = false
    for id in pairs(specs) do Framework.Target._CreatePoint(id) end
end

function Framework.Target.Remove(id)
    Framework.Target._DestroyPoint(id)
    specs[id] = nil
end

function Framework.Target.RemoveAll()
    for id in pairs(specs) do Framework.Target._DestroyPoint(id) end
    specs = {}
end
