module Resource

using HTTP, JSON3
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
joinGame(req) = Service.joinGame(HTTP.URIs.splitpath(req.target)[3], JSON3.read(req.body))
HTTP.@register(ROUTER, "POST", "/mewtwo/game/*", joinGame)

"""
    getRoleAndHand

GET to `/mewtwo/game/{gameId}/hand/{playerId}`
"""
getRoleAndHand(req) = Service.getRoleAndHand(HTTP.URIs.splitpath(req.target)[3], HTTP.URIs.splitpath(req.target)[5])
HTTP.@register(ROUTER, "GET", "/mewtwo/game/*/hand/*", getRoleAndHand)

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
    return Service.takeAction(path[3], JSON3.read(string('"', path[5], '"'), Model.CardType), JSON3.read(req.body))
end
HTTP.@register(ROUTER, "POST", "/mewtwo/game/*/action/*", takeAction)

function requestHandler(req)
    try
        ret = HTTP.handle(ROUTER, req)
        if ret isa Model.Game
            # broadcast updated game to all clients
            # make a copy that doesn't
            # broadcast privateActionResolution
            broadcast(JSON3.write(copy(ret)))
        end
        return HTTP.Response(200, JSON3.write(ret))
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