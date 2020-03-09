using Test, Mewtwo

game = Service.createNewGame((numPlayers=5,))
# @test game.gameId == 1
@test game.numPlayers == 5
@test game.whoseturn in 1:5
@test game.nextExpectedAction == Model.WaitingPlayers
@test game.currentRound == 1
@test game.finished === false
@test isempty(game.picks)
@test isempty(game.discard)
@test length(game.roles) == 5
@test length(game.hands) == 5
@test all(x -> length(x) == 5, game.hands)

game = Service.joinGame(game.gameId, (playerId=1, name="jacobah"))
game = Service.joinGame(game.gameId, (playerId=2, name="ahindes5"))
game = Service.joinGame(game.gameId, (playerId=3, name="velocipop"))
game = Service.joinGame(game.gameId, (playerId=4, name="new"))
game = Service.joinGame(game.gameId, (playerId=5, name="old"))

@test game.nextExpectedAction == Model.PickACard

x = Service.getRoleAndHand(game.gameId, 1)

function newgame()
    game = Service.createNewGame((numPlayers=5,))
    for i = 1:5
        Service.joinGame(game.gameId, (playerId=i, name="$i"))
    end
    return game
end

game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.FireEnergy, false)
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1

game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.Pikachu, false)
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1
@test game.pikasFound == 1

game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.Mewtwo, false)
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1
@test game.finished
@test game.whoWon == Model.Bad

# warp point
game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.WarpPoint, false)
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.WarpPointSteal
@test length(game.picks) == 1

game.hands[1][1] = Model.Card(Model.FireEnergy, false)
body = (pickedPlayerId=1, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.WarpPointSteal, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1
@test game.privateActionResolution == Model.FireEnergy
@test length(game.hands[1]) == 4
@test game.hands[2][1].cardType == Model.FireEnergy
@test game.hands[2][1].sidewaysForNew

# peeking red card
game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.PeekingRedCard, false)
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PubliclyPeek
@test length(game.picks) == 1

game.hands[1][1] = Model.Card(Model.FireEnergy, false)
body = (pickedPlayerId=1, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PubliclyPeek, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1
@test game.publicActionResolution == Model.FireEnergy
@test game.hands[1][1].cardType == Model.FireEnergy
@test game.hands[1][1].sidewaysForNew

# ghastly
game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.Ghastly, false)
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1
@test length(game.hands[2]) == 0
@test length(game.discard) == 4

# escape rope
game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.EscapeRope, false)
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.EscapeACard
@test length(game.picks) == 1

game.hands[2][1] = Model.Card(Model.FireEnergy, false)
body = (cardNumberPicked=1,)
game = Service.takeAction(game.gameId, Model.EscapeACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1
@test length(game.discard) == 1

# reverse valley
game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.ReverseValley, false)
p1hand = game.hands[1]
p2hand = game.hands[2]
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1
@test game.hands[1] == p2hand && game.hands[2] == p1hand

# repeat ball
game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.RepeatBall, false)
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 1
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1

# rescue stretch
game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.RescueStretcher, false)
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1

#TODO: test actually rescuing discarded card

# switch
game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.Switch, false)
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1

#TODO: test discard pika in current round, past round

# scoop
game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.SuperScoopUp, false)
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1

# dual ball
game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.DualBall, false)
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1

game.hands[1][1] = Model.Card(Model.FireEnergy, false)
body = (pickingPlayerId=2, pickedPlayerId=1, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 2

game.hands[1][1] = Model.Card(Model.FireEnergy, false)
body = (pickingPlayerId=2, pickedPlayerId=1, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 1
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 3

# old rod
game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.OldRodForFun, false)
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1

body = (pickingPlayerId=2, pickedPlayerId=1, cardNumberPicked=1)
game.hands[1][1] = Model.Card(Model.FireEnergy, false)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 2
game.hands[1][1] = Model.Card(Model.FireEnergy, false)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 3
game.hands[1][1] = Model.Card(Model.FireEnergy, false)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 4
game.hands[1][1] = Model.Card(Model.FireEnergy, false)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 1
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 5
@test game.currentRound == 2
@test all(x -> length(x) == 4, game.hands)

# detective pikachu
game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.DetectivePikachu, false)
game.roles[2] = Model.Bad
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1
@test game.privateActionResolution == Model.Bad

# energy search
game = newgame()
game.whoseturn = 1
game.hands[2][1] = Model.Card(Model.EnergySearch, false)
game.outRole = Model.Bad
body = (pickingPlayerId=1, pickedPlayerId=2, cardNumberPicked=1)
game = Service.takeAction(game.gameId, Model.PickACard, body)
@test game.whoseturn == 2
@test game.nextExpectedAction == Model.PickACard
@test length(game.picks) == 1
@test game.privateActionResolution == Model.Bad

Service.rematch(game.gameId)
