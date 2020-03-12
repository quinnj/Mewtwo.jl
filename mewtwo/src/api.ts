let SERVER = 'http://localhost:8081';
let WS = 'ws://localhost:8082';

export function setServer(loc = false) {
    SERVER = loc ? 'http://localhost:8081' : 'http://mewtwo.bradr.dev:8081';
    WS = loc ? 'ws://localhost:8082' : 'ws://mewtwo.bradr.dev:8082';
}

export function syncGame(gameId: number) {
    let ws = new WebSocket(WS);
    ws.onopen = () => {
        ws.send(JSON.stringify({ gameId: gameId }));
    };
    return ws;
}

export enum Action {
    WaitingPlayers = "WaitingPlayers",
    PickACard = "PickACard",
    WooperJumpedOut = "WooperJumpedOut",
    WarpPointSteal = "WarpPointSteal",
    PubliclyPeek = "PubliclyPeek",
    EscapeACard = "EscapeACard",
    RescueDiscarded = "RescueDiscarded",
    ScoopOldCard = "ScoopOldCard",
    EnergySearchSomeone = "EnergySearchSomeone",
}

export enum CardType {
    FireEnergy = "FireEnergy",
    CrazyBernie = "CrazyBernie",
    GrassEnergy = "GrassEnergy",
    WaterEnergy = "WaterEnergy",
    FairyEnergy = "FairyEnergy",
    Pikachu = "Pikachu",
    Mewtwo = "Mewtwo",
    WarpPoint = "WarpPoint",
    PeekingRedCard = "PeekingRedCard",
    Ghastly = "Ghastly",
    EscapeRope = "EscapeRope",
    ReverseValley = "ReverseValley",
    RepeatBall = "RepeatBall",
    RescueStretcher = "RescueStretcher",
    Switch = "Switch",
    SuperScoopUp = "SuperScoopUp",
    OldRodForFun = "OldRodForFun",
    DualBall = "DualBall",
    DetectivePikachu = "DetectivePikachu",
    EnergySearch = "EnergySearch",
    MrMime = "MrMime",
}

export interface Card {
    sidewaysForNew: boolean;
}

export enum Role {
    Good = "Good",
    Bad = "Bad",
}

export interface Player {
    name: string;
}

export interface Pick {
    pickingPlayerId: number;
    pickedPlayerId: number;
    cardNumberPicked: number;
    roundPicked: number;
    roundPickNumber: number;
    cardType: CardType;
}

export interface Game {
    gameId: number;
    numPlayers: number;
    players: Player[];
    whoseturn: number;
    lastAction: Action;
    nextExpectedAction: Action;
    currentRound: number;
    finished: boolean;
    picks: Pick[];
    discard: Card[];
    hands: Card[][];
    publicActionResolution: any;
    privateActionResolution: any;
    pikasFound: number;
    whoWon: Role;
}

const http = {
    get: (url: string) => {
        return fetch(url, {
            method: 'GET',
            mode: 'cors',
        }).then(x => x.json())
    },
    post: (url: string, data?: any) => {
        return fetch(url, {
            method: 'POST',
            mode: 'cors',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        }).then(x => x.json())
    },
    delete: (url: string) => {
        return fetch(url, {
            method: 'DELETE',
            mode: 'cors'
        }).then(x => x.json())
    }
}

export function createNewGame(numPlayers: number): Promise<Game> {
    return http.post(`${SERVER}/mewtwo`, { numPlayers });
}

export function rematch(gameId: number): Promise<Game> {
    return http.post(`${SERVER}/mewtwo/game/${gameId}/rematch`);
}

export function getGame(gameId: number): Promise<Game> {
    return http.get(`${SERVER}/mewtwo/game/${gameId}`);
}

export function getActiveGames(): Promise<Game[]> {
    return http.get(`${SERVER}/mewtwo/games`);
}

export function deleteGame(gameId: number) {
    return http.delete(`${SERVER}/mewtwo/game/${gameId}`);
}

export function joinGame(
    gameId: number,
    playerId: number,
    name: string,
): Promise<Game> {
    return http
        .post(`${SERVER}/mewtwo/game/${gameId}`, { playerId, name })
        ;
}

export interface RoleAndHand {
    hand: CardType[];
    role: Role;
}

export function getRoleAndHand(
    gameId: number,
    playerId: number,
): Promise<RoleAndHand> {
    return http
        .get(`${SERVER}/mewtwo/game/${gameId}/hand/${playerId}`)
        ;
}

export function getDiscard(gameId: number): Promise<{ discard: CardType[] }> {
    return http.get(`${SERVER}/mewtwo/game/${gameId}/discard`);
}

export function takeAction(
    gameId: number,
    action: Action,
    body: any,
): Promise<Game> {
    return http
        .post(`${SERVER}/mewtwo/game/${gameId}/action/${action}`, body)
        ;
}
