module Resource

using Sockets, HTTP, JSON3, Dates
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
    getActiveGames

GET to `/mewtwo/games`
"""
getActiveGames(req) = Service.getActiveGames()
HTTP.@register(ROUTER, "GET", "/mewtwo/games", getActiveGames)

"""
    deleteGame

DELETE to `/mewtwo/game/{gameId}`
"""
deleteGame(req) = Service.deleteGame(parse(Int, HTTP.URIs.splitpath(req.target)[3]))
HTTP.@register(ROUTER, "DELETE", "/mewtwo/game/*", deleteGame)

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

* `PickACard` or `WooperJumpedOut`:
    * Body required: `{pickingPlayerId: number, pickedPlayerId: number, cardNumberPicked: number}`
* `WarpPointSteal`:
    * Body required: `{pickedPlayerId: number, cardNumberPicked: number}`
    * Returns: `game.privateActionResolution` has the `CardType` the player stole
* `PubliclyPeek`:
    * Body required: `{pickedPlayerId: number, cardNumberPicked: number}`
    * Returns: `game.publicActionResolution` has the `CardType` the player peeked at
* `EscapeACard`:
    * Body required: `{cardType: CardType}`, cardType of player's own hand they want to discard
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

const WEBAPP_DIR = joinpath(@__DIR__, "../mewtwo/build")
getMewtwoApp(req) = HTTP.Response(200, read(joinpath(WEBAPP_DIR, req.target == "/" ? "index.html" : chop(req.target, head=1, tail=0))))
HTTP.@register(ROUTER, "GET", "/", getMewtwoApp)

function requestHandler(req)
    start = Dates.now(Dates.UTC)
    if req.method == "OPTIONS"
        @show req
        return HTTP.Response(200, [
            "Access-Control-Allow-Origin"=>"*",
            "Access-Control-Allow-Methods"=>"POST, GET, OPTIONS, DELETE",
            "Access-Control-Allow-Headers"=>"x-domo-requestcontext, x-requested-with, content-type"
        ])
    end
    try
        println((now=start, event="ServiceRequestBegin", method=req.method, target=req.target, headers=req.headers, body=String(copy(req.body))))
        ret = HTTP.handle(ROUTER, req)
        if ret isa Model.Game
            # broadcast updated game to all clients
            # make a copy that doesn't
            # broadcast privateActionResolution
            broadcast(ret.gameId, JSON3.write(copy(ret)))
        end
        stop = Dates.now(Dates.UTC)
        if ret isa HTTP.Response
            println((now=stop, event="ServiceRequestEnd", method=req.method, target=req.target, duration=Dates.value(stop - start), status=ret.status, bodysize=length(ret.body)))
            return ret
        else
            resp = HTTP.Response(200, ["Access-Control-Allow-Origin"=>"*"]; body=JSON3.write(ret))
            println((now=stop, event="ServiceRequestEnd", method=req.method, target=req.target, duration=Dates.value(stop - start), status=resp.status, body=String(copy(resp.body))))
            return resp
        end
    catch e
        @error "requestHandler" exception=(e, catch_backtrace())
        resp = HTTP.Response(500, sprint(showerror, e, catch_backtrace()))
        stop = Dates.now(Dates.UTC)
        println((now=stop, event="ServiceRequestEnd", method=req.method, target=req.target, duration=Dates.value(stop - start), status=resp.status, body=String(copy(resp.body))))
        return resp
    end
end

function broadcast(gameId, json)
    # for all open client websockets, publish updated game
    chans = get(() -> Channel{String}[], BROADCAST_CHANNELS, gameId)
    for ch in chans
        if isopen(ch)
            put!(ch, json)
        end
    end
    filter!(isopen, chans)
    return
end

const BROADCAST_CHANNELS = Dict{Int, Vector{Channel{String}}}()
const WEBSOCKET_SERVER = Ref{Any}()

function init()
    println("initializing Resource")
    # force compilation
    req = HTTP.Request("GET", "/", [], JSON3.write((numPlayers=5,)))
    createNewGame(req)
    println("initialized Resource")
    return
end

function run()
    WEBSOCKET_SERVER[] = @async HTTP.listen(IPv4(0, 0, 0, 0), 8082) do http
        if HTTP.WebSockets.is_upgrade(http.message)
            HTTP.WebSockets.upgrade(http) do ws
                @assert !eof(ws)
                x = JSON3.read(readavailable(ws))
                ch = Channel{String}(1)
                push!(get!(() -> Channel{String}[], BROADCAST_CHANNELS, x.gameId), ch)
                try
                    while true
                        msg = take!(ch)
                        write(ws, msg)
                    end
                catch e
                    @warn sprint(showerror, e, catch_backtrace())
                finally
                    close(ch)
                end
            end
        end
    end
    HTTP.serve(requestHandler, IPv4(0, 0, 0, 0), 8081)
end

end # module