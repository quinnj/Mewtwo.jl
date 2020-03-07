module Model

using StructTypes

@enum CardType begin
    FireEnergy
    CrazyBernie
    GrassEnergy
    WaterEnergy
    SocialistEnergy
    FairyEnergy
    Pikachu
    Mewtwo
    WarpPoint
    PeekingRedCard
    Ghastly
    EscapeRope
    ReverseValley
    RepeatBall
    RescueStretcher
    Switch
    SuperScoopUp
    OldRodForFun
    DualBall
    DetectivePikachu
    EnergySearch
end

const Energies = [FireEnergy, CrazyBernie, GrassEnergy, FairyEnergy, WaterEnergy, SocialistEnergy]
const StartingForFive = [FireEnergy, CrazyBernie, GrassEnergy, FairyEnergy, WaterEnergy, SocialistEnergy, Pikachu, Pikachu, Pikachu, Pikachu, Pikachu, Mewtwo, WarpPoint, PeekingRedCard, Ghastly, EscapeRope, ReverseValley, RepeatBall, RescueStretcher, Switch, SuperScoopUp, OldRodForFun, DualBall, DetectivePikachu, EnergySearch]

mutable struct Card
    cardType::CardType
    sidewaysForNew::Bool
    cardNumber::Int
    # cardImage
end
Card() = Card(GrassEnergy, false)
StructTypes.StructType(::Type{Card}) = StructTypes.Mutable()

@enum Role Good Bad

const Roles = Dict{Int, Vector{Role}}(
    5 => [Good, Good, Good, Good, Bad, Bad],
    6 => [Good, Good, Good, Good, Bad, Bad],
    7 => [Good, Good, Good, Good, Good, Bad, Bad, Bad],
    8 => [Good, Good, Good, Good, Good, Good, Bad, Bad, Bad],
    9 => [Good, Good, Good, Good, Good, Good, Bad, Bad, Bad, Bad],
    10 => [Good, Good, Good, Good, Good, Good, Good, Bad, Bad, Bad, Bad],
    11 => [Good, Good, Good, Good, Good, Good, Good, Good, Bad, Bad, Bad, Bad],
    12 => [Good, Good, Good, Good, Good, Good, Good, Good, Bad, Bad, Bad, Bad, Bad]
)

mutable struct Player
    playerId::Int
    name::String
    # avatar
    joined::Bool
    seatingOrder::Int
    # hidden
    role::Role
    hand::Vector{Card}
end
Player() = Player(0, "", false, 0, Good, Card[])
StructTypes.StructType(::Type{Player}) = StructTypes.Mutable()
StructTypes.excludes(::Type{Player}) = (:role, :hand)

@enum Action WaitingPlayers PickACard WarpPointSteal PubliclyPeek EscapeACard RescueDiscarded ScoopOldCard InspectRole InspectOutRole EnergySearchSomeone

mutable struct Pick
    pickingPlayerId::Int
    pickedPlayerId::Int
    cardNumberPicked::Int
    roundPicked::Int
    roundPickNumber::Int
    card::Card
end
Pick() = Pick(0, 0, 0, 0, Card())
Pick(a, b, c, d) = Pick(a, b, c, d, Card())
StructTypes.StructType(::Type{Pick}) = StructTypes.Mutable()

struct DiscardedCard
    originalPlayerId::Int
    cardNumberDiscarded::Int
    card::Card
end

StructTypes.StructType(::Type{DiscardedCard}) = StructTypes.Mutable()

mutable struct Game
    # core fields
    gameId::Int
    numPlayers::Int
    players::Vector{Player}
    whoseturn::Int # playerId
    nextExpectedAction::Action
    currentRound::Int
    finished::Bool
    # joined fields
    picks::Vector{Pick}
    discard::Vector{DiscardedCard}
    # calculated fields
    cardsPicked::Vector{Vector{Bool}}
    pikasFound::Int
    whoWon::Model.Role
    Game() = new()
end

StructTypes.StructType(::Type{Game}) = StructTypes.Mutable()

end # module