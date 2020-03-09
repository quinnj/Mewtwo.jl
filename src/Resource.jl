module Resource

using Sockets, HTTP, JSON3
using ..Model, ..Service

const ROUTER = HTTP.Router()

"""
    createNewGame

POST to `/mewtwo`, body like:
```
{
    numPlayers: 5
}
```
"""
createNewGame(req) = Service.createNewGame(JSON3.read(req.body))
HTTP.@register(ROUTER, "POST", "/mewtwo", createNewGame)

"""
    rematch

POST to `/mewtwo/game/{gameId}/rematch`, no body required
"""
rematch(req) = Service.rematch(parse(Int, HTTP.URIs.splitpath(req.target)[3]))
HTTP.@register(ROUTER, "POST", "/mewtwo/game/*/rematch", rematch)

"""
    getGame

GET to `/mewtwo/game/{gameId}`
"""
getGame(req) = Service.getGame(parse(Int, HTTP.URIs.splitpath(req.target)[3]))
HTTP.@register(ROUTER, "GET", "/mewtwo/game/*", getGame)

"""
    joinGame

POST to `/mewtwo/game/{gameId}`, body like:
```
{
    playerId: 1,
    name: "ahindes5"
}
```
`playerId` corresponds to the "seat" around the table
and user should be allowed to choose any empty seat.
"""
joinGame(req) = Service.joinGame(parse(Int, HTTP.URIs.splitpath(req.target)[3]), JSON3.read(req.body))
HTTP.@register(ROUTER, "POST", "/mewtwo/game/*", joinGame)

"""
    getRoleAndHand

GET to `/mewtwo/game/{gameId}/hand/{playerId}`
"""
getRoleAndHand(req) = Service.getRoleAndHand(parse(Int, HTTP.URIs.splitpath(req.target)[3]), parse(Int, HTTP.URIs.splitpath(req.target)[5]))
HTTP.@register(ROUTER, "GET", "/mewtwo/game/*/hand/*", getRoleAndHand)

"""
    getDiscard

GET to `/mewtwo/game/{gameId}/discard`
"""
getDiscard(req) = Service.getDiscard(parse(Int, HTTP.URIs.splitpath(req.target)[3]))
HTTP.@register(ROUTER, "GET", "/mewtwo/game/*/discard", getDiscard)

"""
    takeAction

POST to `/mewtwo/game/{gameId}/action/{Action}`, body requirements depend on `Action`:

* `PickACard`:
    * Body required: `{pickingPlayerId: number, pickedPlayerId: number, cardNumberPicked: number}`
* `WarpPointSteal`:
    * Body required: `{pickedPlayerId: number, cardNumberPicked: number}`
    * Returns: `game.privateActionResolution` has the `CardType` the player stole
* `PubliclyPeek`:
    * Body required: `{pickedPlayerId: number, cardNumberPicked: number}`
    * Returns: `game.publicActionResolution` has the `CardType` the player peeked at
* `EscapeACard`:
    * Body required: `{cardNumberPicked: number}`, card number of player's own hand
* `RescueDiscarded`:
    * Body required: `{cardNumberPicked: number}`, card number of `game.discard`
* `ScoopOldCard`:
    * Body required: `{pickNumber: number}`, index (1-based) of pick in `game.picks` that should be scooped
* `EnergySearchSomeone`:
    * Body required: `{pickedPlayerId: number}`
    * Returns: `game.privateActionResolution` has the `Role` of the player id
"""
function takeAction(req)
    path = HTTP.URIs.splitpath(req.target)
    return Service.takeAction(parse(Int, path[3]), JSON3.read(string('"', path[5], '"'), Model.Action), JSON3.read(req.body))
end
HTTP.@register(ROUTER, "POST", "/mewtwo/game/*/action/*", takeAction)

function requestHandler(req)
    try
        ret = HTTP.handle(ROUTER, req)
        if ret isa Model.Game
            # broadcast updated game to all clients
            # make a copy that doesn't
            # broadcast privateActionResolution
            broadcast(ret.gameId, JSON3.write(copy(ret)))
        end
        return HTTP.Response(200, JSON3.write(ret))
    catch e
        return HTTP.Response(500, sprint(showerror, e, catch_backtrace()))
    end
end

function broadcast(gameId, json)
    # for all open client websockets, publish updated game
    for ch in get(() -> Channel{String}[], BROADCAST_CHANNELS, gameId)
        put!(ch, json)
    end
    return
end

const BROADCAST_CHANNELS = Dict{Int, Vector{Channel{String}}}()
const WEBSOCKET_SERVER = Ref{Any}()

function run()
    WEBSOCKET_SERVER[] = @async HTTP.listen(IPv4(0, 0, 0, 0), 8082) do http
        if HTTP.WebSockets.is_upgrade(http.message)
            HTTP.WebSockets.upgrade(http) do ws
                @assert !eof(ws)
                x = JSON3.read(readavailable(ws))
                ch = Channel{String}(1)
                push!(get!(() -> Channel{String}[], BROADCAST_CHANNELS, x.gameId), ch)
                while true
                    msg = take!(ch)
                    write(ws, msg)
                end
            end
        end
    end
    HTTP.serve(requestHandler, IPv4(0, 0, 0, 0), 8081)
end

end # module