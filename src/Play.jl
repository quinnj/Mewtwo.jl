module Play

using REPL.TerminalMenus
using ..Client, ..Model

radio(msg, opts) = request(msg, RadioMenu(opts))
function entertocontinue()
    println("press enter to continue...")
    readline()
end

mutable struct Game
    game::Model.Game
    cond::Condition
end
Game(game) = Game(game, Condition())

function play(name::String, loc=false)
    # whether we play against a local or remote server
    Client.setServer!(loc)
    while true
        activeGames = Client.getActiveGames()
        games = Dict(game.gameId=>game for game in activeGames)
        opts = ["refresh games", "create new game"]
        if !isempty(games)
            push!(opts, "join game ($(length(games)))")
            push!(opts, "delete game")
        end
        ret = radio("\e[2Jwelcome to the mewtwo lobby $name\n", opts)
        if ret == 1
            continue
        elseif ret == 2
            while true
                print("\e[2J# players: ")
                N = readline()
                N == "q" && break
                try
                    n = parse(Int, N)
                    if n > 4
                        game = Client.createNewGame(n)
                        games[game.gameId] = game
                        break
                    else
                        println("enter a # >= 5")
                        entertocontinue()
                    end
                catch e
                    println("enter a # dummy or 'q' to go back")
                    entertocontinue()
                end
            end
        elseif ret == 3
            gameIds = collect(keys(games))
            opts = ["gameId: $i" for i in gameIds]
            push!(opts, "go back")
            ret = radio("\e[2Jwhich game", opts)
            if ret != length(opts)
                gameId = gameIds[ret]
                game = Game(games[gameId])
                Client.websocket(gameId, game)
                game.game = Client.joinGame(gameId, name)
                playerId = findfirst(x -> x !== nothing && x.name == name, game.game.players)
                if playerId === nothing
                    println("game's full man")
                    entertocontinue()
                    continue
                else
                    playerId -= 1
                end
                gameLoop(game, playerId)
            end
        elseif ret == 4
            gameIds = collect(keys(games))
            opts = ["gameId: $i" for i in gameIds]
            push!(opts, "go back")
            ret = radio("\e[2Jwhich game", opts)
            if ret != length(opts)
                Client.deleteGame(gameIds[ret])
                delete!(games, gameIds[ret])
            end
        end
    end
end

radiox(msg, opts, f=string) = opts[radio(msg, map(f, opts))]
notyou(game, playerId) = [i for i = 0:(game.game.numPlayers-1) if i != playerId]

function hands(game, playerId, roleAndHand)
    println("hands:")
    for i = 0:(game.numPlayers-1)
        if i == playerId && !game.hideOwnHand[i+1]
            println("your hand:")
            println(join(roleAndHand.hand, " "))
            println()
        else
            println("$(game.players[i+1].name)'s hand:")
            println(join(map(string, game.hands[i+1]), " "))
            println()
        end
    end
end

gamereport(game, playerId, roleAndHand) = println("""\e[2J
gameId: $(game.gameId)
you: playerId = $playerId, name = $(game.players[playerId+1].name)
# players: $(game.numPlayers)
current round: $(game.currentRound)
pikas found: $(game.pikasFound)
cards in discard: $(length(game.discard))
your role: $(roleAndHand.role)
status: $(game.players[game.whoseturn+1].name) to $(game.nextExpectedAction)
current round picks: $(join(map(x -> x.cardType, filter(x -> x.roundPicked == game.currentRound, game.picks)), " "))
""")

function gameLoop(game, playerId)
    # wait for all players to arrive
    sleep(2.0)
    while game.game.nextExpectedAction == Model.WaitingPlayers
        println("waiting for others to arrive")
        wait(game.cond)
    end
    currentRound = 1
    roleAndHand = Client.getRoleAndHand(game.game.gameId, playerId)
    while true
        gamereport(game.game, playerId, roleAndHand)
        hands(game.game, playerId, roleAndHand)
        game.game.finished && break
        if game.game.whoseturn == playerId
            if game.game.nextExpectedAction == Model.PickACard
                peeps = [i for i in notyou(game, playerId) if length(game.game.hands[i+1]) > 0]
                pickedPlayerId = radiox("pick from who", peeps, x->game.game.players[x+1].name)
                if length(game.game.hands[pickedPlayerId+1]) == 1
                    println("$(game.game.players[pickedPlayerId+1].name) only has one card")
                    entertocontinue()
                    cardNumberPicked = 0
                else
                    cardNumberPicked = radiox("pick what", 0:(length(game.game.hands[pickedPlayerId+1])), x->x == length(game.game.hands[pickedPlayerId+1]) ? "go back" : string(game.game.hands[pickedPlayerId+1][x+1]))
                    cardNumberPicked == length(game.game.hands[pickedPlayerId+1]) && continue
                end
                g = Client.takeAction(game.game.gameId, game.game.nextExpectedAction, (pickingPlayerId=playerId, pickedPlayerId=pickedPlayerId, cardNumberPicked=cardNumberPicked))
                game.game = g
                if g.privateActionResolution !== nothing
                    pick = g.picks[end]
                    if pick.cardType == Model.DetectivePikachu
                        p = g.players[pick.pickedPlayerId+1].name 
                        println("you picked dp, $p is a $(g.privateActionResolution == "Good" ? "goody" : "baddo")")
                        entertocontinue()
                    end
                elseif g.publicActionResolution !== nothing
                    println(g.publicActionResolution)
                    entertocontinue()
                end
            elseif game.game.nextExpectedAction == Model.WooperJumpedOut
                peeps = [i for i in notyou(game, playerId) if length(game.game.hands[i+1]) > 0]
                pickedPlayerId = radiox("wooper jumped out!\npick from who", peeps, x->game.game.players[x+1].name)
                if length(game.game.hands[pickedPlayerId+1]) == 1
                    println("$(game.game.players[pickedPlayerId+1].name) only has one card")
                    entertocontinue()
                    cardNumberPicked = 0
                else
                    cardNumberPicked = radiox("pick what", 0:(length(game.game.hands[pickedPlayerId+1])), x->x == length(game.game.hands[pickedPlayerId+1]) ? "go back" : string(game.game.hands[pickedPlayerId+1][x+1]))
                    cardNumberPicked == length(game.game.hands[pickedPlayerId+1]) && continue
                end
                g = Client.takeAction(game.game.gameId, game.game.nextExpectedAction, (pickingPlayerId=playerId, pickedPlayerId=pickedPlayerId, cardNumberPicked=cardNumberPicked))
                game.game = g
                if g.privateActionResolution !== nothing
                    pick = g.picks[end]
                    if pick.cardType == Model.DetectivePikachu
                        p = g.players[pick.pickedPlayerId+1].name 
                        println("you picked dp, $p is a $(g.privateActionResolution == "Good" ? "goody" : "baddo")")
                        entertocontinue()
                    end
                elseif g.publicActionResolution !== nothing
                    println(g.publicActionResolution)
                    entertocontinue()
                end
            elseif game.game.nextExpectedAction == Model.WarpPointSteal
                peeps = [i for i in notyou(game, playerId) if length(game.game.hands[i+1]) > 0]
                pickedPlayerId = radiox("steal from who", peeps, x->game.game.players[x+1].name)
                if length(game.game.hands[pickedPlayerId+1]) == 1
                    println("$(game.game.players[pickedPlayerId+1].name) only has one card")
                    entertocontinue()
                    cardNumberPicked = 0
                else
                    cardNumberPicked = radiox("steal what", 0:(length(game.game.hands[pickedPlayerId+1])), x->x == length(game.game.hands[pickedPlayerId+1]) ? "go back" : string(game.game.hands[pickedPlayerId+1][x+1]))
                    cardNumberPicked == length(game.game.hands[pickedPlayerId+1]) && continue
                end
                game.game = Client.takeAction(game.game.gameId, game.game.nextExpectedAction, (pickedPlayerId=pickedPlayerId, cardNumberPicked=cardNumberPicked))
                println("stole: $(game.game.privateActionResolution)")
                entertocontinue()
            elseif game.game.nextExpectedAction == Model.PubliclyPeek
                peeps = [i for i = 0:(game.game.numPlayers-1) if length(game.game.hands[i+1]) > 0]
                pickedPlayerId = radiox("peek at who", peeps, x->game.game.players[x+1].name)
                if length(game.game.hands[pickedPlayerId+1]) == 1
                    println("$(game.game.players[pickedPlayerId+1].name) only has one card")
                    entertocontinue()
                    cardNumberPicked = 0
                else
                    cardNumberPicked = radiox("peek what", 0:(length(game.game.hands[pickedPlayerId+1])), x->x == length(game.game.hands[pickedPlayerId+1]) ? "go back" : string(game.game.hands[pickedPlayerId+1][x+1]))
                    cardNumberPicked == length(game.game.hands[pickedPlayerId+1]) && continue
                end
                game.game = Client.takeAction(game.game.gameId, game.game.nextExpectedAction, (pickedPlayerId=pickedPlayerId, cardNumberPicked=cardNumberPicked))
                pickedPlayerId, cardNumberPicked, cardType = game.game.publicActionResolution["pickedPlayerId"], game.game.publicActionResolution["cardNumberPicked"], game.game.publicActionResolution["cardType"]
                println("peeked: $(cardType)")
                entertocontinue()
            elseif game.game.nextExpectedAction == Model.EscapeACard
                if length(roleAndHand.hand) == 1
                    println("you only have one other card to escape")
                    entertocontinue()
                    cardType = roleAndHand.hand[1]
                else
                    cardType = radiox("escape what", roleAndHand.hand)
                end
                game.game = Client.takeAction(game.game.gameId, game.game.nextExpectedAction, (cardType=cardType,))
            elseif game.game.nextExpectedAction == Model.RescueDiscarded
                discard = Client.getDiscard(game.game.gameId)
                if length(discard) == 1
                    println("$(discard[1]) is the only card in the discard to rescue")
                    entertocontinue()
                    cardNumberPicked = 0
                else
                    cardNumberPicked = radiox("rescue what", 0:(length(discard)-1), x->string(discard[x+1]))
                end
                game.game = Client.takeAction(game.game.gameId, game.game.nextExpectedAction, (cardNumberPicked=cardNumberPicked,))
            elseif game.game.nextExpectedAction == Model.ScoopOldCard
                picks = filter(x -> x.roundPicked < game.game.currentRound, game.game.picks)
                pickNumber = radiox("scoop what", 0:(length(picks)-1), x->string(picks[x+1].cardType))
                game.game = Client.takeAction(game.game.gameId, game.game.nextExpectedAction, (pickNumber=pickNumber,))
            elseif game.game.nextExpectedAction == Model.EnergySearchSomeone
                if game.game.numPlayers == 6
                    pickedPlayerId = radiox("energy search who", notyou(game, playerId), x->game.game.players[x+1].name)
                    game.game = Client.takeAction(game.game.gameId, game.game.nextExpectedAction, (pickedPlayerId=pickedPlayerId,))
                    p = game.game.players[pickedPlayerId+1].name
                    println("inspected $p, they're a $(game.game.publicActionResolution == "Good" ? "goody" : "baddo")")
                else
                    game.game = Client.takeAction(game.game.gameId, game.game.nextExpectedAction, NamedTuple())
                    println("your energy search was picked, out card is a $(game.game.privateActionResolution == "Good" ? "goody" : "baddo")")
                end
                entertocontinue()
            end
        elseif game.game.nextExpectedAction == Model.PubliclyPeek
            p = game.game.players[game.game.whoseturn+1].name
            println("waiting for $p to peek")
            wait(game.cond)
            g = game.game
            pickedPlayerId, cardNumberPicked, cardType = g.publicActionResolution["pickedPlayerId"], g.publicActionResolution["cardNumberPicked"], g.publicActionResolution["cardType"]
            p2 = g.players[pickedPlayerId+1].name
            println("$p peeked at $p2, it was $(cardType)")
            entertocontinue()
        else
            p = game.game.players[game.game.whoseturn+1].name
            println("waiting for $p to $(game.game.nextExpectedAction)")
            wait(game.cond)
            if game.game.publicActionResolution !== nothing
                println(game.game.publicActionResolution)
                entertocontinue()
            end
        end
        if game.game.currentRound > currentRound && !game.game.finished
            newCurrentRound = game.game.currentRound
            game.game.currentRound = currentRound
            gamereport(game.game, playerId, roleAndHand)
            println("round $currentRound done, press enter to continue")
            readline()
            game.game.currentRound = newCurrentRound
            currentRound = newCurrentRound
        end
        roleAndHand = Client.getRoleAndHand(game.game.gameId, playerId)
    end
    whowon = game.game.whoWon == Model.Good ? "goodies" : "baddos"
    println("game over! $whowon won!")
    entertocontinue()
    # ask for rematch

    return
end

end # module