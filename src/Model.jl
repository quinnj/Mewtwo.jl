module Model

using StructTypes

@enum CardType begin
    FireEnergy
    CrazyBernie
    GrassEnergy
    WaterEnergy
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
    MrMime
end

const Energies = [FireEnergy, CrazyBernie, GrassEnergy, FairyEnergy, WaterEnergy]
const StartingForFive = [FireEnergy, CrazyBernie, GrassEnergy, FairyEnergy, WaterEnergy, MrMime, Pikachu, Pikachu, Pikachu, Pikachu, Pikachu, Mewtwo, WarpPoint, PeekingRedCard, Ghastly, EscapeRope, ReverseValley, RepeatBall, RescueStretcher, Switch, SuperScoopUp, OldRodForFun, DualBall, DetectivePikachu, EnergySearch]

mutable struct Card
    i::Int
    sidewaysForNew::Bool
    # cardImage
end
Card() = Card(0, false)
StructTypes.StructType(::Type{Card}) = StructTypes.Struct()
Base.string(c::Card) = c.sidewaysForNew ? "Card(sidewaysForNew=true)" : "Card()"

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

struct Player
    name::String
    # avatar
end
StructTypes.StructType(::Type{Player}) = StructTypes.Struct()

@enum Action begin
    WaitingPlayers
    PickACard
    WooperJumpedOut
    WarpPointSteal
    PubliclyPeek
    EscapeACard
    RescueDiscarded
    ScoopOldCard
    EnergySearchSomeone
end

mutable struct Pick
    pickingPlayerId::Int
    pickedPlayerId::Int
    cardNumberPicked::Int
    roundPicked::Int
    roundPickNumber::Int
    cardType::CardType
    i::Int
end
Pick() = Pick(0, 0, 0, 0, 0, FireEnergy, 0)
Pick(a, b, c) = Pick(a, b, c, 0, 0, FireEnergy, 0)
StructTypes.StructType(::Type{Pick}) = StructTypes.Mutable()

mutable struct Game
    lock::ReentrantLock
    # core fields
    gameId::Int
    numPlayers::Int
    players::Vector{Union{Nothing, Player}}
    whoseturn::Int # playerId
    lastAction::Action
    nextExpectedAction::Action
    currentRound::Int
    finished::Bool
    # joined fields
    picks::Vector{Pick}
    discard::Vector{Card}
    hands::Vector{Vector{Card}} # length == numPlayers
    hideOwnHand::Vector{Bool}
    # hidden fields
    cardTypes::Vector{CardType}
    roles::Vector{Role} # length == numPlayers
    outRole::Role
    # temporary field (not persisted)
    publicActionResolution::Any
    # private for one user
    privateActionResolution::Any
    # calculated fields
    pikasFound::Int
    whoWon::Role
end

Game() = Game(ReentrantLock(), 0, 0, Union{Nothing, Player}[], 0, WaitingPlayers, WaitingPlayers, 1, false, Pick[], Card[], Vector{Card}[], Bool[], CardType[], Role[], Good, nothing, nothing, 0, Good)

StructTypes.StructType(::Type{Game}) = StructTypes.Mutable()
StructTypes.excludes(::Type{Game}) = (:lock, :cardTypes, :roles, :outRole)

function Base.copy(game::Game)
    g = Game()
    for f in fieldnames(Game)
        if f != :privateActionResolution && isdefined(game, f)
            setfield!(g, f, getfield(game, f))
        end
    end
    return g
end

end # module