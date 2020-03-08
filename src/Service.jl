module Service

using ..Model, ..Mapper

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
    game.players = Vector{Model.Player}(undef, game.numPlayers)
    deck, roles = generateDeckAndRoles(game.numPlayers)
    game.roles = [pick!(roles) for i = 1:game.numPlayers]
    game.outRole = game.numPlayers != 6 ? pick!(roles) : Model.Good
    game.hands = [[Model.Card(pick!(deck), false) for i = 1:5] for i = 1:game.numPlayers]
    return calculateFields!(Mapper.createNewGame(game))
end

function joinGame(gameId, params)
    game = Mapper.getGame(gameId)
    game.players[params.playerId] = Model.Player(params.name)
    if all(i -> isassigned(game.players, i), 1:game.numPlayers)
        game.nextExpectedAction = Model.PickACard
    end
    Mapper.updateGame(game)
    return calculateFields!(game)
end

numPikas(picks) = count(pick -> pick.card.cardType == Model.Pikachu, picks)

function calculateFields!(game)
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

function resolvePick!(game, pick)
    push!(game.picks, pick)
    cardType = pick.card.cardType
    # for almost all actions, the person picked gets to pick next
    whoseturn = game.whoseturn
    game.whoseturn = pick.pickedPlayerId
    if length(game.picks) > 1
        if game.picks[end-1].card.cardType == Model.DualBall
            game.whoseturn = whoseturn
        end
        picks = currentRoundPicks(game)
        if any(x -> x.card.cardType == Model.OldRodForFun, picks) && length(picks) < game.numPlayers
            game.whoseturn = whoseturn
        end
    end
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
        pickedPlayerHand = game.hands[pick.pickedPlayerId]
        append!(game.discard, splice!(pickedPlayerHand, 1:length(pickedPlayerHand)))
    elseif cardType == Model.EscapeRope
        game.nextExpectedAction = Model.EscapeACard
    elseif cardType == Model.ReverseValley
        pickedPlayerHand = game.hands[pick.pickedPlayerId]
        pickingPlayerHand = game.hands[pick.pickingPlayerId]
        game.hands[pick.pickedPlayerId] = pickingPlayerHand
        game.hands[pick.pickingPlayerId] = pickedPlayerHand
    elseif cardType == Model.RepeatBall
        game.whoseturn = pick.pickingPlayerId
    elseif cardType == Model.RescueStretcher
        if !isempty(game.discard)
            game.nextExpectedAction = Model.RescueDiscarded
        end
    elseif cardType == Model.Switch
        pikaPick = findlast(x -> x.card.cardType == Model.Pikachu, game.picks)
        if pikaPick !== nothing
            game.currentRound = currentRound
            # swap picks
            pikaPick.card, pick.card = pick.card, pikaPick.card
            push!(game.discard, pick.card)
            pop!(game.picks)
        end
    elseif cardType == Model.SuperScoopUp
        if game.currentRound > 1
            game.nextExpectedAction = Model.ScoopOldCard
        end
    elseif cardType == Model.OldRodForFun
        nothing
    elseif cardType == Model.DualBall
        nothing
    elseif cardType == Model.DetectivePikachu
        game.privateActionResolution = game.roles[game.picks[end].pickedPlayerId]
    elseif cardType == Model.EnergySearch
        if game.numPlayers == 6
            game.nextExpectedAction = Model.EnergySearchSomeone
        else
            game.privateActionResolution = game.outRole
        end
    elseif cardType == Model.MrMime
        nothing
    else
        error("can't resolvePick! for unknown cardType = $cardType")
    end
    if game.currentRound > currentRound
        discarded = splice!(game.discard, 1:length(game.discard))
        # deal out new hands
        cards = append!(collect(Iterators.flatten(game.hands)), discarded)
        game.hands = [[pick!(cards) for i = 1:(6 - game.currentRound)] for i = 1:game.numPlayers]
    end
end

function takeAction(gameId, action, body)
    game = Mapper.getGame(gameId)
    if action == Model.PickACard
        pick = Model.Pick(body...)
        pick.roundPicked = game.currentRound
        pick.roundPickNumber = length(currentRoundPicks(game)) + 1
        pick.card = splice!(game.hands[pick.pickedPlayerId], pick.cardNumberPicked)
        resolvePick!(game, pick)
    elseif action == Model.WarpPointSteal
        card = splice!(game.hands[body.pickedPlayerId], body.cardNumberPicked)
        lastPick = game.picks[end]
        insert!(game.hands[lastPick.pickedPlayerId], lastPick.cardNumberPicked, card)
        card.sidewaysForNew = true
        game.privateActionResolution = card.cardType
        game.nextExpectedAction = Model.PickACard
    elseif action == Model.PubliclyPeek
        card = game.hands[body.pickedPlayerId][body.cardNumberPicked]
        card.sidewaysForNew = true
        game.publicActionResolution = card.cardType
        game.nextExpectedAction = Model.PickACard
    elseif action == Model.EscapeACard
        lastPick = game.picks[end]
        card = splice!(game.hands[lastPick.pickedPlayerId], body.cardNumberPicked)
        push!(game.discard, card)
        game.nextExpectedAction = Model.PickACard
    elseif action == Model.RescueDiscarded
        card = game.discard[body.cardNumberPicked]
        lastPick = game.picks[end]
        lastPickCard, lastPick.card = lastPick.card, card
        game.discard[body.cardNumberPicked] = lastPickCard
        if lastPick.card.cardType == Model.Pikachu
            if numPikas(game.picks) == game.numPlayers
                game.finished = true
            end
        elseif lastPick.card.cardType == Model.Mewtwo
            game.finished = true
        end
        game.nextExpectedAction = Model.PickACard
    elseif action == Model.ScoopOldCard
        lastPick = game.picks[end]
        scooped = game.picks[body.pickNumber]
        insert!(game.hands[lastPick.pickedPlayerId], lastPick.cardNumberPicked, scooped.card)
        scooped.card = lastPick.card
        pop!(game.picks)
        game.nextExpectedAction = Model.PickACard
    elseif action == Model.EnergySearchSomeone
        game.privateActionResolution = game.roles[body.pickedPlayerId]
        game.nextExpectedAction = Model.PickACard
    else
        error("unsupported action = $action")
    end
    Mapper.updateGame(game)
    return calculateFields!(game)
end

function getRoleAndHand(gameId, playerId)
    game = Mapper.getGame(gameId)
    hand = game.hands[playerId]
    return (hand=[x.cardType for x in hand], role=game.roles[playerId])
end

end # module