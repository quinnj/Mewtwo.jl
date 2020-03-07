module Service

using ..Model, ..Mapper

listPlayers() = Mapper.listPlayers()

function createPlayer(params)
    player = Model.Player()
    player.name = params.name
    Mapper.createPlayer(player)
    return player
end

function generateDeckAndRoles(n)
    deck = copy(Model.StartingForFive)
    for i = 1:(n - 5)
        append!(dec, [
            Model.Pikachu,
            rand(Model.Energies),
            rand(Model.Energies),
            rand(Model.Energies),
            rand(Model.Energies)
        ])
    end
    return deck, copy(Model.Roles[n])
end

pick!(A) = splice!(A, rand(1:length(A)))

function createNewGame(params)
    game = Model.Game()
    game.numPlayers = params.numPlayers
    game.whoseturn = rand(1:game.numPlayers)
    game.nextExpectedAction = Model.WaitingPlayers
    game.currentRound = 1
    game.finished = false
    game.picks = Model.Pick[]
    game.discard = Model.Card[]
    deck, roles = generateDeckAndRoles(game.numPlayers)
    game.players = map(1:game.numPlayers) do i
        Model.Player(
            0, "", false, i,
            pick!(roles),
            [Model.Card(pick!(deck), false, i) for i = 1:5]
        )
    end
    return calculateFields!(Mapper.createNewGame(game))
end

function joinGame(gameId, params)
    Mapper.joinGame(gameId, params.seatingOrder, params.playerId)
    game = Mapper.getGame(gameId)
    if all(x -> x.joined, game.players)
        Mapper.updateGameAction(gameId, PickACard)
        game.nextExpectedAction = PickACard
    end
    return calculateFields!(game)
end

numPikas(picks) = count(pick -> pick.card.cardType == Model.Pikachu, picks)

function calculateFields!(game)
    # cardsPicked

    # pikasFound
    game.pikasFound = numPikas(game.picks)
    # whoWon
    game.whoWon = game.pikasFound == game.numPlayers ? Model.Good : Model.Bad
    return game
end

function currentRoundPicks(game)
    return filter(game.picks) do pick
        pick.roundPicked == game.currentRound
    end
end

function remainingHand(game, playerId)
    hand = getPlayer(game, playerId).hand
    currentRoundPlayerPickedCards = map(x -> x.card, filter(currentRoundPicks(game)) do pick
        pick.pickedPlayerId == playerId
    end)
    return filter(hand) do card
        card ∉ currentRoundPlayerPickedCards
    end
end

getPlayer(game, id) = findfirst(x -> x.playerId == id, game.players)

function resolvePick!(game, pick)
    push!(game.picks, pick)
    cardType = pick.card.cardType
    # for almost all actions, the person picked gets to pick next
    game.whoseturn = pick.pickedPlayerId
    # default next action is pick a card
    game.nextExpectedAction = Model.PickACard
    # go to next round if last pick by default
    currentRound = game.currentRound
    game.currentRound += game.numPlayers == pick.roundPickNumber
    if cardType in Model.Energies
        nothing
    elseif cardType == Model.Pikachu
        if numPikas(game.picks) == game.numPlayers
            game.finished = true
        end
    elseif cardType == Model.Mewtwo
        game.finished = true
    elseif cardType == Model.WarpPoint
        game.nextExpectedAction = Model.WarpPointSteal
    elseif cardType == Model.PeekingRedCard
        game.nextExpectedAction = Model.PubliclyPeek
    elseif cardType == Model.Ghastly
        discards = [Model.DiscardedCard(pick.pickedPlayerId, card) for card in remainingHand(game, pick.pickedPlayerId)]
        append!(game.discard, discards)
        discards.foreach(discards) do x
            Mapper.createDiscard(game.gameId, x)
        end
    elseif cardType == Model.EscapeRope
        game.nextExpectedAction = Model.EscapeACard
    elseif cardType == Model.ReverseValley
        pickedPlayer = getPlayer(game, pick.pickedPlayerId)
        pickingPlayer = getPlayer(game, pick.pickingPlayerId)
        pickedPlayer.hand = remainingHand(game, pick.pickingPlayerId)
        pickingPlayer.hand = remainingHand(game, pick.pickedPlayerId)
    elseif cardType == Model.RepeatBall
        game.whoseturn = pick.pickingPlayerId
    elseif cardType == Model.RescueStretcher
        game.nextExpectedAction = Model.RescueDiscarded
    elseif cardType == Model.Switch

    elseif cardType == Model.SuperScoopUp
        game.nextExpectedAction = Model.ScoopOldCard
    elseif cardType == Model.OldRodForFun
        if pick.roundPickNumber < game.numPlayers
            game.whoseturn =  pick.pickingPlayerId
        end
    elseif cardType == Model.DualBall
        if length(game.picks) == 1 || game.picks[end-1].pickingPlayerid != pick.pickingPlayerId
            # picking player gets another pick
            game.whoseturn = pick.pickingPlayerId
        end
    elseif cardType == Model.DetectivePikachu
        game.nextExpectedAction = Model.InspectRole
    elseif cardType == Model.EnergySearch
        game.nextExpectedAction = game.numPlayers == 6 ?
            Model.EnergySearchSomeone : Model.InspectOutRole
    else
        error("can't resolvePick! for unknown cardType = $cardType")
    end
    if game.currentRound > currentRound
        empty!(game.discard)
        Mapper.clearDiscard!(gameId)
    end
end

function takeAction(gameId, action, body)
    game = Mapper.getGame(gameId)
    if action == Model.PickACard
        pick = Pick(body...)
        pickedPlayer = getPlayer(game, pick.pickedPlayerId)
        pick.card = pickedPlayer.hand[pick.cardNumberPicked]
        Mapper.createPick(gameId, pick)
        push!(game.picks, pick)

    end
end

function getHand(gameId, params)
    game = Mapper.getGame(gameId)
    return remainingHand(game, params.playerId)
end

end # module