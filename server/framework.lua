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

print(("^2[peak-chess] ^7Framework ^5->^7 %s^0"):format(activeFramework))

function Framework.Name(src)
    if src ~= nil then
        return Framework.NameForPlayer(src)
    end

    return activeFramework
end

function Framework.HasMoneyProvider()
    local ok, bridgeFramework = bridgeCall("GetFrameworkName")
    if ok and bridgeFramework then
        return bridgeFramework ~= "standalone"
    end

    return ESX ~= nil or QBCore ~= nil or Qbox ~= nil
end

function Framework.Identifier(src)
    local ok, identifier = bridgeCall("GetIdentifier", src)
    if ok and identifier then
        return identifier
    end

    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        return xPlayer and (xPlayer.getIdentifier and xPlayer.getIdentifier() or xPlayer.identifier) or nil
    elseif QBCore then
        local player = QBCore.Functions.GetPlayer(src)
        return player and (player.PlayerData.citizenid or player.PlayerData.license) or nil
    elseif Qbox then
        local player = Qbox:GetPlayer(src)
        return player and player.PlayerData and (player.PlayerData.citizenid or player.PlayerData.license) or nil
    end

    return GetPlayerIdentifierByType(src, "license") or GetPlayerIdentifier(src, 0) or ("standalone:%s"):format(src)
end

function Framework.NameForPlayer(src)
    local ok, name = bridgeCall("GetPlayerName", src)
    if ok and name then
        return name
    end

    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        return xPlayer and xPlayer.getName() or ("Player %s"):format(src)
    elseif QBCore then
        local player = QBCore.Functions.GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.charinfo then
            local charinfo = player.PlayerData.charinfo
            local fullName = (("%s %s"):format(charinfo.firstname or "", charinfo.lastname or "")):gsub("^%s*(.-)%s*$", "%1")
            if fullName ~= "" then
                return fullName
            end
        end
    elseif Qbox then
        local player = Qbox:GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.charinfo then
            local charinfo = player.PlayerData.charinfo
            local fullName = (("%s %s"):format(charinfo.firstname or "", charinfo.lastname or "")):gsub("^%s*(.-)%s*$", "%1")
            if fullName ~= "" then
                return fullName
            end
        end
    end

    return GetPlayerName(src) or ("Player %s"):format(src)
end

function Framework.GetMoney(src, account)
    if not Framework.HasMoneyProvider() then
        return 0
    end

    local ok, amount = bridgeCall("GetMoney", src, account)
    if ok and amount ~= nil then
        return tonumber(amount) or 0
    end

    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return 0 end
        if account == "cash" or account == "money" then
            return xPlayer.getMoney and xPlayer.getMoney() or 0
        end
        local acc = xPlayer.getAccount and xPlayer.getAccount(account)
        return acc and acc.money or 0
    elseif QBCore then
        local player = QBCore.Functions.GetPlayer(src)
        if not player or not player.PlayerData or not player.PlayerData.money then return 0 end
        local qbAccount = account == "money" and "cash" or account
        return player.PlayerData.money[qbAccount] or 0
    elseif Qbox then
        local qboxAccount = account == "money" and "cash" or account
        local amount = Qbox:GetMoney(src, qboxAccount)
        return tonumber(amount) or 0
    end

    return 0
end

function Framework.RemoveMoney(src, account, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end
    if not Framework.HasMoneyProvider() then return false end

    local ok, removed = bridgeCall("RemoveMoney", src, amount, account, "chess-wager")
    if ok then
        return removed == true
    end

    if Framework.GetMoney(src, account) < amount then return false end

    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false end
        if account == "cash" or account == "money" then
            if xPlayer.removeMoney then
                xPlayer.removeMoney(amount)
                return true
            end
        elseif xPlayer.removeAccountMoney then
            xPlayer.removeAccountMoney(account, amount)
            return true
        end
    elseif QBCore then
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return false end
        local qbAccount = account == "money" and "cash" or account
        return player.Functions.RemoveMoney(qbAccount, amount, "chess-wager") == true
    elseif Qbox then
        local qboxAccount = account == "money" and "cash" or account
        return Qbox:RemoveMoney(src, qboxAccount, amount, "chess-wager") == true
    end

    return false
end

function Framework.AddMoney(src, account, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end
    if not Framework.HasMoneyProvider() then return false end

    local ok, added = bridgeCall("AddMoney", src, amount, account, "chess-payout")
    if ok then
        return added == true
    end

    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false end
        if account == "cash" or account == "money" then
            if xPlayer.addMoney then
                xPlayer.addMoney(amount)
                return true
            end
        elseif xPlayer.addAccountMoney then
            xPlayer.addAccountMoney(account, amount)
            return true
        end
    elseif QBCore then
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return false end
        local qbAccount = account == "money" and "cash" or account
        return player.Functions.AddMoney(qbAccount, amount, "chess-payout") == true
    elseif Qbox then
        local qboxAccount = account == "money" and "cash" or account
        return Qbox:AddMoney(src, qboxAccount, amount, "chess-payout") == true
    end

    return false
end

function Framework.Notify(src, msg, kind)
    local ok = bridgeCall("Notify", src, msg, kind or "info", 5000, "Peak Chess")
    if ok then
        return
    end

    TriggerClientEvent("peak-chess:notify", src, msg, kind or "info")
end
