module Resource

using HTTP, JSON3
using ..Model, ..Service

const ROUTER = HTTP.Router()

listPlayers(req) = Service.listPlayers()
HTTP.@register(ROUTER, "GET", "/mewtwo/player", listPlayers)

createPlayer(req) = Service.createPlayer(JSON3.read(req.body))
HTTP.@register(ROUTER, "POST", "/mewtwo/player", createPlayer)

createNewGame(req) = Service.createNewGame(JSON3.read(req.body))
HTTP.@register(ROUTER, "POST", "/mewtwo", createNewGame)

joinGame(req) = Service.joinGame(HTTP.URIs.splitpath(req.target)[3], JSON3.read(req.body))
HTTP.@register(ROUTER, "POST", "/mewtwo/game/*", joinGame)

getHand(req) = Service.getHand(HTTP.URIs.splitpath(req.target)[3], JSON3.read(req.body))
HTTP.@register(ROUTER, "GET", "/mewtwo/game/*/hand", getHand)

function takeAction(req)
    path = HTTP.URIs.splitpath(req.target)
    return Service.takeAction(path[3], path[5], JSON3.read(req.body))
end
HTTP.@register(ROUTER, "POST", "/mewtwo/game/*/action/*", takeAction)

function requestHandler(req)
    try
        ret = HTTP.handle(ROUTER, req)
        json = JSON3.write(ret)
        if ret isa Model.Game
            # broadcast updated game to all clients
            broadcast(json)
        end
        return HTTP.Response(200, json)
    catch e
        return HTTP.Response(500, sprint(showerror, e))
    end
end

function broadcast(json)
    # TODO: for all open client websockets, publish updated game
    return
end

function run()
    # TODO: start websocket server asynchronously
    HTTP.serve(requestHandler, IPv4(0, 0, 0, 0), 8081)
end

end # module