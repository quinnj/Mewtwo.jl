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

function updateGame(game)
    GAMES[game.gameId] = game
    return
end

end # module