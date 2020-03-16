module Mapper

using ..Model

const GAME_ID = Threads.Atomic{Int}(0)

struct Games
    lock::ReentrantLock
    games::Dict{Int, Model.Game}
end

const GAMES = Games(ReentrantLock(), Dict{Int, Model.Game}())

function createNewGame(game)
    game.gameId = Threads.atomic_add!(GAME_ID, 1)
    lock(GAMES.lock) do
        GAMES.games[game.gameId] = game
    end
    return game
end

getGame(gameId) = GAMES.games[gameId]

getActiveGames() = [x for x in values(GAMES.games) if !x.finished]

function deleteGame(gameId)
    lock(GAMES.lock) do
        haskey(GAMES.games, gameId) && delete!(GAMES.games, gameId)
    end
    return
end

function updateGame(game)
    lock(GAMES.lock) do
        GAMES.games[game.gameId] = game
    end
    return
end

function init()
    println("initializing Mapper")
    GAME_ID[] = 0
    empty!(GAMES.games)
    println("initialized Mapper")
    return
end

end # module