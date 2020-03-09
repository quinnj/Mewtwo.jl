module Client

using HTTP, JSON3, ..Model

# const SERVER = "http://localhost:8081"
# const WS = "ws://localhost:8082"
const SERVER = "http://mewtwo.bradr.dev:8081"
const WS = "ws://mewtwo.bradr.dev:8082"

function websocket(gameId)
    @async HTTP.WebSockets.open(WS) do ws
        write(ws, JSON3.write((gameId=gameId,)))
        while !eof(ws)
            data = String(readavailable(ws))
            println("got game update: $data")
        end
    end
end

function createNewGame(numPlayers)
    resp = HTTP.post(string(SERVER, "/mewtwo"), [], JSON3.write((numPlayers=numPlayers,)); status_exception=false)
    if resp.status == 200
        return JSON3.read(resp.body, Model.Game)
    else
        return resp
    end
end

function rematch(gameId)
    resp = HTTP.post(string(SERVER, "/mewtwo/game/$gameId/rematch"); status_exception=false)
    if resp.status == 200
        return JSON3.read(resp.body, Model.Game)
    else
        return resp
    end
end

function getGame(gameId)
    resp = HTTP.get(string(SERVER, "/mewtwo/game/$gameId"); status_exception=false)
    if resp.status == 200
        return JSON3.read(resp.body, Model.Game)
    else
        return resp
    end
end

function joinGame(gameId, playerId, name)
    resp = HTTP.post(string(SERVER, "/mewtwo/game/$gameId"), [], JSON3.write((playerId=playerId, name=name)); status_exception=false)
    if resp.status == 200
        return JSON3.read(resp.body, Model.Game)
    else
        return resp
    end
end

function getRoleAndHand(gameId, playerId)
    resp = HTTP.get(string(SERVER, "/mewtwo/game/$gameId/hand/$playerId"),)
    if resp.status == 200
        return JSON3.read(resp.body)
    else
        return resp
    end
end

function getDiscard(gameId)
    resp = HTTP.get(string(SERVER, "/mewtwo/game/$gameId/discard"))
    if resp.status == 200
        return JSON3.read(resp.body, NamedTuple{(:discard,), Tuple{Vector{Model.CardType}}})
    else
        return resp
    end
end

function takeAction(gameId, action, body)
    resp = HTTP.post(string(SERVER, "/mewtwo/game/$gameId/action/$action"), [], JSON3.write(body); status_exception=false)
    if resp.status == 200
        return JSON3.read(resp.body, Model.Game)
    else
        return resp
    end
end

end # module