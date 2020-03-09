module Mapper

using ..Model

const GAME_ID = Ref{Int}(0)

const GAMES = Dict{Int, Model.Game}()

function createNewGame(game)
    game.gameId = (GAME_ID[] += 1)
    GAMES[game.gameId] = game
    return game
end

getGame(gameId) = GAMES[gameId]

getActiveGames() = [x for x in values(GAMES) if !x.finished]

function deleteGame(gameId)
    haskey(GAMES, gameId) && delete!(GAMES, gameId)
    return
end

function updateGame(game)
    GAMES[game.gameId] = game
    return
end

function init()
    println("initializing Mapper")
    GAME_ID[] = 0
    empty!(GAMES)
    println("initialized Mapper")
    return
end

end # module