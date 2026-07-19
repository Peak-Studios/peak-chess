Betting = {}

function Betting._Account()
    return Config.Betting.account
end

function Betting.IsAvailable()
    return Config.Betting.enabled == true and Framework.HasMoneyProvider()
end

function Betting._PayoutAmount(amount)
    local houseCut = Config.Betting.houseCut or 0
    return math.floor(amount * (1 - houseCut))
end

function Betting.CanAfford(playerId, amount)
    if amount <= 0 then
        return true
    end

    if not Betting.IsAvailable() then
        return false
    end

    return amount <= Framework.GetMoney(playerId, Betting._Account())
end

function Betting.EscrowSolo(playerId, amount)
    if amount <= 0 then
        return true
    end

    if not Betting.IsAvailable() then
        return false
    end

    return Framework.RemoveMoney(playerId, Betting._Account(), amount)
end

function Betting.EscrowPvP(whitePlayer, blackPlayer, amount)
    if amount <= 0 then
        return true
    end

    if not Betting.IsAvailable() then
        return false
    end

    local whitePaid = Framework.RemoveMoney(whitePlayer, Betting._Account(), amount)
    local blackPaid = Framework.RemoveMoney(blackPlayer, Betting._Account(), amount)

    if whitePaid and not blackPaid then
        Framework.AddMoney(whitePlayer, Betting._Account(), amount)
    elseif blackPaid and not whitePaid then
        Framework.AddMoney(blackPlayer, Betting._Account(), amount)
    end

    return whitePaid and blackPaid
end

function Betting._Refund(playerId, amount)
    if amount <= 0 then
        return
    end

    Framework.AddMoney(playerId, Betting._Account(), amount)
    Framework.Notify(playerId, Shared.L("bet_refunded", amount), "info")
end

function Betting._PayWinner(playerId, amount)
    if amount <= 0 then
        return
    end

    Framework.AddMoney(playerId, Betting._Account(), amount)
    Framework.Notify(playerId, Shared.L("bet_won", amount), "success")
end

function Betting.Settle(match, winnerColor)
    if not Betting.IsAvailable() then
        return
    end

    local whitePlayer = match.seats.white
    local blackPlayer = match.seats.black
    local whiteIsPlayer = type(whitePlayer) == "number"
    local blackIsPlayer = type(blackPlayer) == "number"
    local whiteBet = match.bet.white or 0
    local blackBet = match.bet.black or 0

    if whiteIsPlayer and blackIsPlayer then
        if not winnerColor then
            if Config.Betting.drawRefund then
                Betting._Refund(whitePlayer, whiteBet)
                Betting._Refund(blackPlayer, blackBet)
            end
            return
        end

        local winner = winnerColor == "white" and whitePlayer or blackPlayer
        Betting._PayWinner(winner, Betting._PayoutAmount(whiteBet + blackBet))
        return
    end

    local soloPlayer = whiteIsPlayer and whitePlayer or blackIsPlayer and blackPlayer or nil
    if not soloPlayer then
        return
    end

    local soloColor = whiteIsPlayer and "white" or "black"
    local soloBet = whiteIsPlayer and whiteBet or blackBet
    if soloBet <= 0 then
        return
    end

    if not winnerColor then
        Betting._Refund(soloPlayer, soloBet)
    elseif winnerColor == soloColor then
        Betting._PayWinner(soloPlayer, Betting._PayoutAmount(soloBet * 2))
    end
end
