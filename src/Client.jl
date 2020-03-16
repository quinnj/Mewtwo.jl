module Client

using HTTP, JSON3, ..Model

const SERVER = Ref{String}()
const WS = Ref{String}()

function setServer!(loc=false)
    SERVER[] = loc ? "http://localhost:8081" : "http://mewtwo.bradr.dev:8081"
    WS[] = loc ? "ws://localhost:8082" : "ws://mewtwo.bradr.dev:8082"
    return
end

function __init__()
    setServer!()
    return
end

function websocket(gameId, game)
    @async HTTP.WebSockets.open(WS[]) do ws
        write(ws, JSON3.write((gameId=gameId,)))
        while !eof(ws)
            game.game = JSON3.read(readavailable(ws), Model.Game)
            notify(game.cond)
        end
        println("websocket for game = $gameId disconnected")
    end
end

function createNewGame(numPlayers)
    resp = HTTP.post(string(SERVER[], "/mewtwo"), [], JSON3.write((numPlayers=numPlayers,)); status_exception=false)
    if resp.status == 200
        return JSON3.read(resp.body, Model.Game)
    else
        return resp
    end
end

function rematch(gameId)
    resp = HTTP.post(string(SERVER[], "/mewtwo/game/$gameId/rematch"); status_exception=false)
    if resp.status == 200
        return JSON3.read(resp.body, Model.Game)
    else
        return resp
    end
end

function getGame(gameId)
    resp = HTTP.get(string(SERVER[], "/mewtwo/game/$gameId"); status_exception=false)
    if resp.status == 200
        return JSON3.read(resp.body, Model.Game)
    else
        return resp
    end
end

function getActiveGames()
    resp = HTTP.get(string(SERVER[], "/mewtwo/games"); status_exception=false)
    if resp.status == 200
        return JSON3.read(resp.body, Vector{Model.Game})
    else
        return resp
    end
end

function deleteGame(gameId)
    resp = HTTP.delete(string(SERVER[], "/mewtwo/game/$gameId"); status_exception=false)
    if resp.status == 200
        return nothing
    else
        return resp
    end
end

function joinGame(gameId, name)
    resp = HTTP.post(string(SERVER[], "/mewtwo/game/$gameId"), [], JSON3.write((name=name,)); status_exception=false)
    if resp.status == 200
        return JSON3.read(resp.body, Model.Game)
    else
        return resp
    end
end

function getRoleAndHand(gameId, playerId)
    resp = HTTP.get(string(SERVER[], "/mewtwo/game/$gameId/hand/$playerId"),)
    if resp.status == 200
        return JSON3.read(resp.body)
    else
        return resp
    end
end

function getDiscard(gameId)
    resp = HTTP.get(string(SERVER[], "/mewtwo/game/$gameId/discard"))
    if resp.status == 200
        return JSON3.read(resp.body, Model.Discard)
    else
        return resp
    end
end

function takeAction(gameId, action, body)
    resp = HTTP.post(string(SERVER[], "/mewtwo/game/$gameId/action/$action"), [], JSON3.write(body); status_exception=false)
    if resp.status == 200
        return JSON3.read(resp.body, Model.Game)
    else
        return resp
    end
end

end # module