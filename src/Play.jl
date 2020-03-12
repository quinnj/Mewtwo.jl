module Play

using REPL.TerminalMenus
using ..Client, ..Model

radio(msg, opts) = request(msg, RadioMenu(opts))

function play(name::String, loc=false)
    # whether we play against a local or remote server
    Client.setServer!(loc)
    games = Dict{Int, Model.Game}()
    while true
        activeGames = Client.getActiveGames()
        for game in activeGames
            games[game.gameId] = game
        end
        opts = ["refresh games", "create new game"]
        if !isempty(games)
            push!(opts, "join game ($(length(games)))")
            push!(opts, "delete game")
        end
        ret = radio("\e[2Jmewtwo lobby\nwadya want", opts)
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
                    end
                catch e
                    println("enter a # dummy or 'q' to go back")
                end
            end
        elseif ret == 3
            gameIds = collect(keys(games))
            opts = ["gameId: $i" for i in gameIds]
            push!(opts, "go back")
            ret = radio("\e[2Jwhich game", opts)
            if ret != length(opts)
                gameId = gameIds[ret]
                game = Ref{Model.Game}(games[gameId])
                Client.websocket(gameId, game)
                playerId = findfirst(isnothing, game[].players) - 1
                if playerId !== nothing
                    Client.joinGame(gameId, playerId, name)
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

function gameLoop(game, playerId)
    
end

end # module