exports("IsSeated", function()
    return CGame.seated == true
end)

exports("IsInGame", function()
    return CGame.seated == true and CGame.snapshot and CGame.snapshot.status == "playing"
end)

exports("GetCurrentTable", function()
    return CGame.current
end)

exports("GetColor", function()
    return CGame.color
end)

exports("OpenLobby", function(tableId)
    tableId = tonumber(tableId)
    if not tableId or not CGame.tables[tableId] then
        return false
    end

    CGame.current = tableId
    NUI.OpenLobby(tableId, CGame.snapshot)
    return true
end)
