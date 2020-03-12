import * as React from 'react';
import * as Api from './api';
import './Mewtwo.css';

export default function Mewtwo() {
  const [name, setName] = React.useState('');
  const [numPlayers, setNumPlayers] = React.useState(5);
  const [inLobby, setInLobby] = React.useState(true);
  const [activeGames, setActiveGames] = React.useState<Api.Game[]>([]);
  const [game, setGame] = React.useState<Api.Game | null>(null);
  const [errorText, setErrorText] = React.useState('');
  const [playerId, setPlayerId] = React.useState(-1);
  const [roleAndHand, setRoleAndHand] = React.useState<Api.RoleAndHand>({hand: [], role: Api.Role.Good});
  const [seeRoleAndHand, setSeeRoleAndHand] = React.useState(false);
  const [discard, setDicard] = React.useState<Api.CardType[]>([]);
  const [webSocket, setWebSocket] = React.useState<WebSocket | null>(null);
  const [escapedCard, setEscapedCard] = React.useState<Api.CardType | null>(null);
  const [rescuedCard, setRescuedCard] = React.useState(0);
  const [scoopedCard, setScoopedCard] = React.useState<Api.CardType | null>(null);
  const [showPicks, setShowPicks] = React.useState(false);
  const [energySearchedDude, setEnergySearchedDude] = React.useState(0);
  const [history, setHistory] = React.useState<any[]>([]);

  const getActiveGames = () => {
    Api.getActiveGames().then(games => {
      setActiveGames(games);
    });
  };

  React.useEffect(() => {
    if (inLobby) {
      getActiveGames();
    }
  }, [inLobby]);

  React.useEffect(() => {
    if (game) {
      if (game.nextExpectedAction === Api.Action.WooperJumpedOut) {
        setErrorText('wooper jumped out! make pick');
        setHistory(history.concat({action: game.nextExpectedAction}))
      } else if (
        game.nextExpectedAction === Api.Action.WarpPointSteal &&
        game.whoseturn === playerId
      ) {
        setErrorText('steal a card');
      } else if (
        game.nextExpectedAction === Api.Action.PubliclyPeek &&
        game.whoseturn === playerId
      ) {
        setErrorText('peek a card');
      } else if (
        game.nextExpectedAction === Api.Action.EscapeACard &&
        game.whoseturn === playerId
      ) {
        setSeeRoleAndHand(true);
        setErrorText('escape a card');
      } else if (
        game.nextExpectedAction === Api.Action.RescueDiscarded &&
        game.whoseturn === playerId
      ) {
        getDiscard();
        setErrorText('put a card on the rescue stretcher');
      } else if (
        game.nextExpectedAction === Api.Action.ScoopOldCard &&
        game.whoseturn === playerId
      ) {
        setShowPicks(true);
        setErrorText('scoop a card');
      } else if (
        game.nextExpectedAction === Api.Action.EnergySearchSomeone &&
        game.whoseturn === playerId
      ) {
        setErrorText('energy search someone');
      } else if (
        game.lastAction === Api.Action.WarpPointSteal &&
        game.privateActionResolution !== null
      ) {
        setErrorText('stole ' + game.privateActionResolution);
        setHistory(history.concat({ action: game.lastAction, cardType: game.privateActionResolution }))
      } else if (
        game.lastAction === Api.Action.PubliclyPeek &&
        game.publicActionResolution !== null
      ) {
        setErrorText('peek is ' + game.publicActionResolution);
        setHistory(history.concat({ action: game.lastAction, cardType: game.publicActionResolution }))
      } else if (
        game.lastAction === Api.Action.EnergySearchSomeone &&
        game.privateActionResolution !== null
      ) {
        setErrorText(
          game.players[game.privateActionResolution.playerId].name +
          ' is ' +
          (game.privateActionResolution.role === Api.Role.Good
            ? 'goody'
            : 'baddo'),
        );
        setHistory(history.concat({ action: game.lastAction, playerId: game.privateActionResolution.playerId, role: game.privateActionResolution.role }))
      }
    }
  }, [game]);

  const createNewGame = () => {
    if (numPlayers > 4) {
      Api.createNewGame(numPlayers).then(game => {
        getActiveGames();
      });
    } else {
      setErrorText('need players >= 5');
    }
  };

  const joinGame = (game: Api.Game) => {
    let playerId =
      game.players.findIndex(x => x !== null && x.name === name);
    if (playerId === -1) {
      playerId = game.players.findIndex(x => x === null);
    }
    if (playerId === -1) {
      setErrorText("game's full man");
    } else if (!name) {
      setErrorText('type your name');
    } else {
      setPlayerId(playerId);
      Api.joinGame(game.gameId, playerId, name).then(game => {
        setGame(game);
        Api.getRoleAndHand(game.gameId, playerId).then(x => {
          setRoleAndHand(x);
        });
        setInLobby(false);
        let ws = Api.syncGame(game.gameId);
        ws.onmessage = e => {
          setGame(JSON.parse(e.data));
        };
        setWebSocket(ws);
      });
    }
  };

  const deleteGame = (game: Api.Game) => {
    if (errorText === 'are you sure') {
      Api.deleteGame(game.gameId).then(x => {
        setErrorText('');
        getActiveGames();
      });
    } else {
      setErrorText('are you sure');
    }
  };

  const rematch = () => {
    if (game) {
      Api.rematch(game.gameId).then(game => {
        setGame(game);
        setHistory([])
      });
    }
  };

  const getDiscard = () => {
    if (game) {
      Api.getDiscard(game.gameId).then(x => {
        setDicard(x.discard);
      });
    }
  };

  const escapeCard = (cardType: Api.CardType) => {
    if (game &&
      game.nextExpectedAction === Api.Action.EscapeACard &&
      game.whoseturn === playerId
    ) {
      setEscapedCard(cardType);
    }
  };

  const rescue = (cardNumberPicked: number) => {
    if (game &&
      game.nextExpectedAction === Api.Action.RescueDiscarded &&
      game.whoseturn === playerId
    ) {
      setRescuedCard(cardNumberPicked);
    }
  };

  const _takeAction = (body: any) => {
    if (game) {
      Api.takeAction(game.gameId, game.nextExpectedAction, body).then(game => {
        setGame(game);
      });
    }
  };

  const takeAction = (body: any) => {
    if (!game)
      return;
    if (
      game.whoseturn !== playerId ||
      game.nextExpectedAction === Api.Action.WaitingPlayers
    ) {
      setErrorText('hold your horses bucko');
    } else if (
      game.nextExpectedAction === Api.Action.PickACard ||
      game.nextExpectedAction === Api.Action.WooperJumpedOut
    ) {
      if (!body || body.pickedPlayerId == null || body.cardNumberPicked == null) {
        setErrorText('make a pick');
      } else if (body.pickedPlayerId === playerId) {
        setErrorText('dink someone else')
      } else {
        _takeAction({ pickingPlayerId: playerId, ...body });
        setHistory(history.concat({ action: game.nextExpectedAction, pickingPlayerId: playerId, pickedPlayerId: body.pickedPlayerId, cardNumberPicked: body.cardNumberPicked }))
      }
    } else if (game.nextExpectedAction === Api.Action.WarpPointSteal) {
      if (!body || body.pickedPlayerId == null || body.cardNumberPicked == null) {
        setErrorText('steal');
      } else if (body.pickedPlayerId === playerId) {
        setErrorText('dink someone else')
      } else {
        _takeAction(body);
        setHistory(history.concat({ action: game.nextExpectedAction, pickedPlayerId: body.pickedPlayerId, cardNumberPicked: body.cardNumberPicked }))
      }
    } else if (game.nextExpectedAction === Api.Action.PubliclyPeek) {
      if (body.pickedPlayerId == null || body.cardNumberPicked == null) {
        setErrorText('peek');
      } else if (body.pickedPlayerId === playerId) {
        setErrorText('dink someone else')
      } else {
        _takeAction(body);
        setHistory(history.concat({ action: game.nextExpectedAction, pickedPlayerId: body.pickedPlayerId, cardNumberPicked: body.cardNumberPicked }))
      }
    } else if (game.nextExpectedAction === Api.Action.EscapeACard) {
      if (!escapedCard) {
        setErrorText('escape');
      } else {
        _takeAction({ cardType: escapedCard });
        setHistory(history.concat({ action: game.nextExpectedAction, cardType: escapedCard }))
        setEscapedCard(null);
        setSeeRoleAndHand(false);
      }
    } else if (game.nextExpectedAction === Api.Action.RescueDiscarded) {
      if (!rescuedCard) {
        setErrorText('rescue');
      } else {
        _takeAction({ cardNumberPicked: rescuedCard });
        setHistory(history.concat({ action: game.nextExpectedAction }))
        setRescuedCard(0);
      }
    } else if (game.nextExpectedAction === Api.Action.ScoopOldCard) {
      if (!scoopedCard) {
        setErrorText('scoop');
      } else {
        _takeAction({ pickNumber: scoopedCard });
        setHistory(history.concat({ action: game.nextExpectedAction}))
        setShowPicks(false);
      }
    } else if (game.nextExpectedAction === Api.Action.EnergySearchSomeone) {
      if (!energySearchedDude) {
        setErrorText('energy search');
      } else if (body.pickedPlayerId === playerId) {
        setErrorText('dink someone else')
      } else {
        _takeAction({ pickedPlayerId: energySearchedDude });
        setHistory(history.concat({ action: game.nextExpectedAction, pickedPlayerId: body.pickedPlayerId }))
        setEnergySearchedDude(0);
      }
    }
  };

  console.log({ game });
  const currentRoundPicks = !game
    ? []
    : game.picks.filter(x => x.roundPicked === game.currentRound);
  return (
    <div className='mewtwo'>
      {inLobby ? (
        <div className='lobby'>
          {errorText && (
            <div className='errorText' style={{ color: 'red' }}>
              {errorText}
            </div>
          )}
          lobby
          <div className='name'>
            <input
              value={name}
              placeholder={'type your name'}
              type="text"
              onChange={e => setName(e.target.value)}
            />
          </div>
          <div className='activeGames'>
            <div onClick={getActiveGames} className='activeGamesHeader'>
              active games
            </div>
            {activeGames &&
              activeGames.map(game => {
                return (
                  <div key={game.gameId} className='activeGame'>
                    {'gameId: ' + game.gameId}
                    <div
                      className='joinGame'
                      onClick={() => joinGame(game)}
                    >
                      join game
                    </div>
                    <div
                      className='deleteGame'
                      onClick={() => deleteGame(game)}
                    >
                      delete game
                    </div>
                  </div>
                );
              })}
          </div>
          <div className='createNewGame' onClick={createNewGame}>
            create a new game
            <input
              value={numPlayers}
              placeholder={'number of players'}
              type="number"
              onChange={e => setNumPlayers(parseInt(e.target.value))}
            />
          </div>
        </div>
      ) : (game &&
          <div className='gameroom'>
            {errorText && (
              <div className='errorText' style={{ color: 'red' }}>
                {errorText}
              </div>
            )}
            <div className='backToLobby' onClick={() => setInLobby(true)}>
              &lt; back to lobby
          </div>
            game room
          <div className='gameInfo'>
              <div className='gameInfoName'>{'name: ' + name}</div>
              <div className='gameInfoId'>{'gameId: ' + game.gameId}</div>
              <div className='gameInfoNumPlayers'>
                {'numPlayers: ' + game.numPlayers}
              </div>
              <div className='gameInfoWhoseTurn'>
                {'whose turn: ' +
                  (game.players[game.whoseturn]
                    ? game.players[game.whoseturn].name
                    : game.whoseturn)}
              </div>
              <div className='gameInfoAction'>
                {'next expected action: ' + game.nextExpectedAction}
              </div>
              <div className='gameInfoPikas'>
                {'pikas found: ' + game.pikasFound}
              </div>
              {game.finished ? (
                <>
                  <div className='gameInfoFinished'>
                    {'game is finished, ' + game.whoWon + ' won'}
                  </div>
                  <div className='rematch' onClick={rematch}>
                    wanna rematch
                </div>
                </>
              ) : (
                  <div className='gameInfoCurrentRound'>
                    {'current round: ' + game.currentRound}
                  </div>
                )}
              <div
                className='seeRoleAndHand'
                onClick={() => setSeeRoleAndHand(!seeRoleAndHand)}
              >
                {(seeRoleAndHand ? 'hide ' : 'see ') + ' role/hand'}
              </div>
              {seeRoleAndHand && (
                <div className='roleAndHand'>
                  <div className='role'>{'role: ' + roleAndHand.role}</div>
                  <div className='hand'>
                    {roleAndHand.hand.map((c, j) => {
                      return (
                        <div
                          key={j}
                          onClick={() => escapeCard(c)}
                          className='handCard'
                        >
                          {c}
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}
              {discard && (
                <div className='discard'>
                  <div className='hand'>
                    {discard.map((c, j) => {
                      return (
                        <div
                          key={j}
                          onClick={() => rescue(j)}
                          className='handCard'
                        >
                          {c}
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}
            </div>
            <div className='currentRoundPicks'>
              <div
                onClick={() => setShowPicks(!showPicks)}
                className='currentRoundPicksHeader'
              >
                {(showPicks ? 'hide ' : 'see ') + 'past round picks'}
              </div>
              {showPicks && <div className='hand'>
                {game.picks
                  .filter(x => x.roundPicked < game.currentRound)
                  .map((x, j) => {
                    return (
                      <div 
                        onClick={() => setScoopedCard(x.cardType)}
                        key={j} className='handCard'
                      >
                        {x.cardType}
                      </div>
                    );
                  })}
              </div>}
            </div>
            <div className='currentRoundPicks'>
              <div className='currentRoundPicksHeader'>
                picks this round
            </div>
              <div className='hand'>
                {currentRoundPicks.map((x, j) => {
                  return (
                    <div key={j} className='handCard'>
                      {x.cardType}
                    </div>
                  );
                })}
              </div>
            </div>
            <div className='hands'>
              <div className='handsHeader'>player's hands</div>
              {Array.from(Array(game.numPlayers).keys()).map(i => {
                return (
                  <div key={i} className='playerHand'>
                    <div
                      onClick={() => setEnergySearchedDude(i + 1)}
                      className='playerName'
                    >
                      {'player name: ' +
                        (game.players[i] ? game.players[i].name : '')}
                    </div>
                    <div className='hand'>
                      {game.hands[i].map((c, j) => {
                        return (
                          <div
                            key={j}
                            onClick={() =>
                              takeAction({ pickedPlayerId: i, cardNumberPicked: j })
                            }
                            className={[
                              'handCard',
                              c.sidewaysForNew ? 'sidewaysForNew' : '',
                            ].join(' ')}
                          >
                            {j}
                          </div>
                        );
                      })}
                    </div>
                  </div>
                );
              })}
            </div>
            <div className='history'>
              <div className='historyHeader'>game history</div>
              {history.map(x => {
                return <div className='historyItem'>
                  <div className='historyItems'>{JSON.stringify(x)}</div>
                </div>
              })}
            </div>
          </div>
        )}
    </div>
  );
}
