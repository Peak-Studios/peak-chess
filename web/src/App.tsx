import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Bot,
  Check,
  Coins,
  Crown,
  Eye,
  LogOut,
  Mouse,
  Signal,
  Swords,
  Trophy,
  Users,
} from "lucide-react";
import { onNuiMessage, postNui } from "./nui";
import type {
  ChessConfig,
  GameOverData,
  GameOverState,
  HudState,
  LobbyState,
  Locale,
  MatchSnapshot,
  MoveSummary,
  PromotionState,
  Side,
} from "./types";

const DEFAULT_CONFIG: ChessConfig = {
  betEnabled: false,
  betPresets: [0, 100, 500, 1000, 5000],
  betMin: 0,
  betMax: 50000,
  aiEnabled: true,
  aiLevels: ["easy", "medium", "hard"],
  account: "cash",
};

const DEFAULT_LOCALE: Locale = {
  ui_brand: "peak chess",
  ui_title: "Chess",
  ui_close: "Close",
  pvp_subtitle: "Take a seat and challenge a player",
  ai_subtitle: "Configure a match against the engine",
  vs_player: "Vs Player",
  vs_ai: "Vs AI",
  take_seat: "Take a seat",
  occupied: "Occupied",
  available: "Available",
  ai_badge: "AI",
  your_side: "Your side",
  difficulty: "Difficulty",
  wager: "Wager",
  wager_max: "max",
  you_play: "You play",
  ready: "Ready",
  ready_up: "Ready up",
  resign: "Resign",
  start_vs_ai: "Start vs AI",
  lvl_easy: "Easy",
  lvl_medium: "Medium",
  lvl_hard: "Hard",
  intent_casual_caption: "Forgiving, learns the ropes",
  intent_balanced_caption: "Balanced challenge",
  intent_ruthless_caption: "Punishing, plays sharp",
  status_idle: "idle",
  status_waiting: "waiting",
  status_playing: "playing",
  status_over: "over",
  you: "You",
  opponent: "Opponent",
  white: "White",
  black: "Black",
  white_to_move: "White to move",
  black_to_move: "Black to move",
  your_turn: "Your turn",
  their_turn: "Opponent's turn",
  check: "Check",
  ctrl_move: "Move a piece",
  ctrl_leave: "Stand up",
  promote_prompt: "Choose promotion",
  res_victory: "VICTORY",
  res_defeat: "DEFEAT",
  res_draw: "DRAW",
  res_checkmate: "Checkmate",
  res_stalemate: "Stalemate",
  res_by_resignation: "By resignation",
  good_game: "Good game",
};

const DEBUG_SNAPSHOT: MatchSnapshot = {
  id: 1,
  status: "waiting",
  seats: { white: false, black: "AI" },
  ready: { white: false, black: true },
  bet: { white: 500, black: 500 },
  aiLevel: "medium",
};

const DEBUG_HUD_SNAPSHOT: MatchSnapshot = {
  id: 1,
  status: "playing",
  seats: { white: true, black: "AI" },
  ready: { white: true, black: true },
  bet: { white: 500, black: 500 },
  turn: "w",
  check: true,
  lastMoves: {
    white: { from: "e2", to: "e4" },
    black: { from: "g8", to: "f6", captured: "wp" },
  },
};

const SIDE_TO_TURN: Record<Side, "w" | "b"> = { white: "w", black: "b" };
const OTHER_SIDE: Record<Side, Side> = { white: "black", black: "white" };
const PROMOTION = [
  { piece: "q", label: "Queen", glyph: { white: "♕", black: "♛" } },
  { piece: "r", label: "Rook", glyph: { white: "♖", black: "♜" } },
  { piece: "b", label: "Bishop", glyph: { white: "♗", black: "♝" } },
  { piece: "n", label: "Knight", glyph: { white: "♘", black: "♞" } },
] as const;

function cx(...classes: Array<string | false | null | undefined>) {
  return classes.filter(Boolean).join(" ");
}

function formatMoney(value?: number) {
  return `$${Number(value || 0).toLocaleString("en-US")}`;
}

function sideLabel(locale: Locale, side: Side) {
  return locale[side] ?? (side === "white" ? "White" : "Black");
}

function pieceImage(side: Side) {
  return `img/bzzz_chess_color_${side === "white" ? "a6" : "b6"}.png`;
}

function difficultyIcon(index: number) {
  return ["img/bzzz_chess_color_a1.png", "img/bzzz_chess_color_a3.png", "img/bzzz_chess_color_a5.png"][index] ?? "img/bzzz_chess_color_a6.png";
}

function difficultyIntent(index: number) {
  return ["casual", "balanced", "ruthless"][index] ?? "balanced";
}

function moveLabel(move?: MoveSummary) {
  if (!move) return "-";
  return `${move.from} ${move.captured ? "x" : "->"} ${move.to}`;
}

function clampWager(value: number, config: ChessConfig) {
  const next = Math.floor(Number(value) || 0);
  return Math.max(config.betMin || 0, Math.min(config.betMax || next, next));
}

function getDebugMode() {
  return new URLSearchParams(window.location.search).get("debug");
}

function resultCopy(locale: Locale, data?: GameOverData) {
  if (!data) return { title: locale.good_game ?? "Good game", subtitle: "" };

  if (!data.winner) {
    return {
      title: locale.res_draw ?? "DRAW",
      subtitle: data.reason === "stalemate" ? locale.res_stalemate ?? "Stalemate" : locale.good_game ?? "Good game",
    };
  }

  if (data.yourColor) {
    return data.winner === data.yourColor
      ? { title: locale.res_victory ?? "VICTORY", subtitle: data.reason === "resign" ? locale.res_by_resignation ?? "By resignation" : locale.res_checkmate ?? "Checkmate" }
      : { title: locale.res_defeat ?? "DEFEAT", subtitle: data.reason === "resign" ? locale.res_by_resignation ?? "By resignation" : locale.res_checkmate ?? "Checkmate" };
  }

  return {
    title: data.winner === "white" ? locale.white ?? "White" : locale.black ?? "Black",
    subtitle: data.reason === "resign" ? locale.res_by_resignation ?? "By resignation" : locale.res_checkmate ?? "Checkmate",
  };
}

function WagerInput({
  value,
  onChange,
  config,
  locale,
}: {
  value: number;
  onChange: (value: number) => void;
  config: ChessConfig;
  locale: Locale;
}) {
  const presets = config.betPresets?.length ? config.betPresets : [0, 100, 500, 1000, 5000];

  return (
    <div className="wager">
      <Coins className="wager__icon" size={22} />
      <div className="wager__field">
        <span>$</span>
        <input
          type="number"
          inputMode="numeric"
          min={config.betMin}
          max={config.betMax}
          value={value === 0 ? "" : value}
          placeholder="0"
          onChange={(event) => onChange(clampWager(Number(event.target.value), config))}
        />
        {config.betMax > 0 && <small>{locale.wager_max ?? "max"} {formatMoney(config.betMax)}</small>}
      </div>
      <button type="button" className="stepper" onClick={() => onChange(clampWager(value - 100, config))}>−</button>
      <button type="button" className="stepper" onClick={() => onChange(clampWager(value + 100, config))}>+</button>
      <div className="preset-row">
        {presets.slice(0, 5).map((preset) => (
          <button
            type="button"
            key={preset}
            className={cx("preset", value === preset && "is-active")}
            onClick={() => onChange(clampWager(preset, config))}
          >
            {preset === 0 ? "0" : formatMoney(preset)}
          </button>
        ))}
      </div>
    </div>
  );
}

function Lobby({ state, config, locale }: { state: LobbyState; config: ChessConfig; locale: Locale }) {
  const snapshot = state.snapshot ?? DEBUG_SNAPSHOT;
  const seats = snapshot.seats ?? { white: false, black: false };
  const seatedSide = state.color ?? null;
  const [mode, setMode] = useState<"pvp" | "ai">("pvp");
  const [side, setSide] = useState<Side>("white");
  const [level, setLevel] = useState(config.aiLevels[0] ?? "easy");
  const [pvpWager, setPvpWager] = useState(0);
  const [aiWager, setAiWager] = useState(0);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (seatedSide && snapshot.ready) {
      setReady(snapshot.ready[seatedSide] === true);
    }
  }, [seatedSide, snapshot.ready]);

  const effectiveMode = config.aiEnabled ? mode : "pvp";
  const subtitle = seatedSide
    ? locale.waiting_opponent ?? "Waiting for an opponent..."
    : effectiveMode === "ai"
      ? locale.ai_subtitle ?? "Configure a match against the engine"
      : locale.pvp_subtitle ?? "Take a seat and challenge a player";

  const toggleReady = () => {
    const nextReady = !ready;
    setReady(nextReady);
    void postNui("setReady", { ready: nextReady, bet: pvpWager });
  };

  return (
    <div className="lobby-shell">
      <div className="lobby-panel">
        <header className="brand-row">
          <div className="brand-mark"><Crown size={34} /></div>
          <div className="brand-copy">
            <p>{locale.ui_brand ?? "peak chess"}</p>
            <h1>{locale.ui_title ?? "Chess"}</h1>
          </div>
          <div className="brand-divider" />
          <div className="brand-side"><Crown size={22} /><span>Table {String(snapshot.id).padStart(2, "0")}</span></div>
        </header>

        <p className="panel-subtitle">{subtitle}</p>

        <div className="seat-status">
          {(["white", "black"] as Side[]).map((seat) => (
            <span key={seat}>
              <i className={cx(seats[seat] ? "busy" : "open")} />
              {sideLabel(locale, seat)}
            </span>
          ))}
          <b>{locale[`status_${snapshot.status}`] ?? snapshot.status}</b>
        </div>

        {!seatedSide && config.aiEnabled && (
          <div className="mode-toggle">
            <button type="button" aria-pressed={effectiveMode === "pvp"} className={cx(effectiveMode === "pvp" && "is-active")} onClick={() => setMode("pvp")}>
              <Users size={20} /> {locale.vs_player ?? "Vs Player"}
            </button>
            <button type="button" aria-pressed={effectiveMode === "ai"} className={cx(effectiveMode === "ai" && "is-active")} onClick={() => setMode("ai")}>
              <Bot size={20} /> {locale.vs_ai ?? "Vs AI"}
            </button>
          </div>
        )}

        <main className="lobby-content">
          {seatedSide ? (
            <section className="selected-side">
              <img src={pieceImage(seatedSide)} alt="" />
              <div>
                <small>{locale.you_play ?? "You play"}</small>
                <strong>{sideLabel(locale, seatedSide)}</strong>
              </div>
            </section>
          ) : effectiveMode === "pvp" ? (
            <section>
              <h2>{locale.take_seat ?? "Take a seat"}</h2>
              <div className="seat-grid">
                {(["white", "black"] as Side[]).map((seat) => {
                  const occupied = seats[seat] !== false;
                  return (
                    <button
                      type="button"
                      key={seat}
                      className={cx("seat-card", seat, occupied && "is-occupied")}
                      disabled={occupied}
                      onClick={() => postNui("sit", { color: seat })}
                    >
                      <img src={pieceImage(seat)} alt="" />
                      <span>{sideLabel(locale, seat)}</span>
                      <em>{occupied ? (seats[seat] === "AI" ? locale.ai_badge ?? "AI" : locale.occupied ?? "Occupied") : locale.available ?? "Available"}</em>
                    </button>
                  );
                })}
              </div>
            </section>
          ) : (
            <>
              <section>
                <h2>{locale.your_side ?? "Your side"}</h2>
                <div className="side-choice">
                  {(["white", "black"] as Side[]).map((choice) => (
                    <button type="button" key={choice} aria-pressed={side === choice} className={cx(side === choice && "is-active")} onClick={() => setSide(choice)}>
                      <img src={pieceImage(choice)} alt="" /> {sideLabel(locale, choice)}
                    </button>
                  ))}
                </div>
              </section>
              <section>
                <h2>{locale.difficulty ?? "Difficulty"}</h2>
                <div className="difficulty-grid">
                  {config.aiLevels.map((item, index) => (
                    <button type="button" key={item} aria-pressed={level === item} className={cx(level === item && "is-active")} onClick={() => setLevel(item)}>
                      <Signal size={20} />
                      <img src={difficultyIcon(index)} alt="" />
                      <span>{locale[`lvl_${item}`] ?? item}</span>
                      <small>{locale[`intent_${difficultyIntent(index)}_caption`] ?? "Engine profile"}</small>
                    </button>
                  ))}
                </div>
              </section>
            </>
          )}

          {config.betEnabled && (
            <section>
              <h2>{locale.wager ?? "Wager"}</h2>
              <WagerInput
                value={effectiveMode === "ai" ? aiWager : pvpWager}
                onChange={effectiveMode === "ai" ? setAiWager : setPvpWager}
                config={config}
                locale={locale}
              />
            </section>
          )}
        </main>

        <footer className="lobby-actions">
          {seatedSide ? (
            <>
              <button type="button" className={cx("primary-action", ready && "is-ready")} onClick={toggleReady}>
                <Check size={22} /> {ready ? locale.ready ?? "Ready" : locale.ready_up ?? "Ready up"}
              </button>
              <button type="button" className="icon-action danger" onClick={() => postNui("leave")} aria-label="Leave">
                <LogOut size={22} />
              </button>
            </>
          ) : effectiveMode === "ai" ? (
            <button type="button" className="primary-action" onClick={() => postNui("startAI", { side, level, bet: aiWager })}>
              <Swords size={24} /> {locale.start_vs_ai ?? "Start vs AI"}
            </button>
          ) : (
            <button type="button" className="secondary-action" onClick={() => postNui("spectate")}>
              <Eye size={22} /> Spectate
            </button>
          )}
        </footer>
      </div>

      <div className="key-hint key-hint--close"><kbd>Esc</kbd><span>{locale.ui_close ?? "Close"}</span></div>
    </div>
  );
}

function Hud({ state, locale }: { state: HudState; locale: Locale }) {
  const snapshot = state.snapshot ?? DEBUG_HUD_SNAPSHOT;
  const playerSide = state.color ?? null;
  const isSpectator = playerSide == null;
  const isYourTurn = playerSide ? snapshot.turn === SIDE_TO_TURN[playerSide] : false;
  const turnText = isSpectator
    ? snapshot.turn === "w"
      ? locale.white_to_move ?? "White to move"
      : locale.black_to_move ?? "Black to move"
    : isYourTurn
      ? locale.your_turn ?? "Your turn"
      : locale.their_turn ?? "Opponent's turn";
  const pot = (snapshot.bet?.white ?? 0) + (snapshot.bet?.black ?? 0);
  const rows = isSpectator
    ? [
        { side: "white" as Side, label: sideLabel(locale, "white"), move: snapshot.lastMoves?.white },
        { side: "black" as Side, label: sideLabel(locale, "black"), move: snapshot.lastMoves?.black },
      ]
    : [
        { side: playerSide, label: locale.you ?? "You", move: snapshot.lastMoves?.[playerSide] },
        { side: OTHER_SIDE[playerSide], label: locale.opponent ?? "Opponent", move: snapshot.lastMoves?.[OTHER_SIDE[playerSide]] },
      ];

  return (
    <>
      <aside className="hud-panel">
        <div className="hud-turn" aria-live="polite">
          <span className={cx("turn-dot", isYourTurn && "pulse")} />
          <strong>{turnText}</strong>
          {snapshot.check && <b>{locale.check ?? "Check"}</b>}
        </div>
        <div className="hud-moves">
          {rows.map((row) => (
            <div key={row.label} className="hud-row">
              <span className={cx("piece-dot", row.side)} />
              <span>{row.label}</span>
              <code>{moveLabel(row.move)}</code>
            </div>
          ))}
        </div>
        {pot > 0 && (
          <div className="hud-pot">
            <Coins size={26} />
            <strong>{formatMoney(pot)}</strong>
          </div>
        )}
        {!isSpectator && (
          <button type="button" className="hud-resign" onClick={() => postNui("resign")}>
            <LogOut size={18} />
            {locale.resign ?? "Resign"}
          </button>
        )}
      </aside>

      <div className="control-hints">
        <div><Mouse size={28} /><span>{locale.ctrl_move ?? "Move a piece"}</span></div>
        <div><kbd>X</kbd><span>{locale.ctrl_leave ?? "Stand up"}</span></div>
      </div>
    </>
  );
}

function PromotionModal({ state, locale }: { state: PromotionState; locale: Locale }) {
  const color = state.color ?? "white";
  return (
    <div className="modal-layer">
      <section className="promotion-modal" aria-label={locale.promote_prompt ?? "Choose promotion"}>
        <h2>{locale.promote_prompt ?? "Choose promotion"}</h2>
        <div className="promotion-grid">
          {PROMOTION.map((item) => (
            <button type="button" key={item.piece} onClick={() => postNui("promote", { piece: item.piece })}>
              <span>{item.glyph[color]}</span>
              <em>{item.label}</em>
            </button>
          ))}
        </div>
      </section>
    </div>
  );
}

function ResultBanner({ state, locale, onClose }: { state: GameOverState; locale: Locale; onClose: () => void }) {
  const copy = resultCopy(locale, state.data);

  useEffect(() => {
    if (!state.visible) return;
    const timeout = window.setTimeout(onClose, 5000);
    return () => window.clearTimeout(timeout);
  }, [onClose, state.visible]);

  if (!state.visible) return null;

  return (
    <section className="result-banner" aria-live="assertive">
      <Trophy size={28} />
      <div>
        <strong>{copy.title}</strong>
        {copy.subtitle && <span>{copy.subtitle}</span>}
      </div>
      <Trophy size={28} />
    </section>
  );
}

function setDebugState(
  mode: string,
  setLobby: (state: LobbyState) => void,
  setHud: (state: HudState) => void,
  setPromotion: (state: PromotionState) => void,
  setGameOver: (state: GameOverState) => void
) {
  document.body.classList.add("debug-bg");
  setLobby({ visible: false });
  setHud({ visible: false });
  setPromotion({ visible: false });
  setGameOver({ visible: false });

  if (mode === "lobby" || mode === "all") {
    setLobby({ visible: true, id: 1, snapshot: DEBUG_SNAPSHOT, color: null });
  }

  if (mode === "hud" || mode === "all") {
    setHud({ visible: true, snapshot: DEBUG_HUD_SNAPSHOT, color: "white" });
  }

  if (mode === "promotion" || mode === "all") {
    setHud({ visible: true, snapshot: DEBUG_HUD_SNAPSHOT, color: "white" });
    setPromotion({ visible: true, color: "white" });
  }

  if (mode === "result" || mode === "all") {
    setHud({ visible: true, snapshot: DEBUG_HUD_SNAPSHOT, color: "white" });
    setGameOver({ visible: true, data: { winner: "white", reason: "checkmate", yourColor: "white" } });
  }
}

function seedDebugState(
  setLobby: (state: LobbyState) => void,
  setHud: (state: HudState) => void,
  setPromotion: (state: PromotionState) => void,
  setGameOver: (state: GameOverState) => void
) {
  const mode = getDebugMode();
  if (mode) setDebugState(mode, setLobby, setHud, setPromotion, setGameOver);
}

export default function App() {
  const [config, setConfig] = useState<ChessConfig>(DEFAULT_CONFIG);
  const [locale, setLocale] = useState<Locale>(DEFAULT_LOCALE);
  const [lobby, setLobby] = useState<LobbyState>({ visible: false });
  const [hud, setHud] = useState<HudState>({ visible: false });
  const [promotion, setPromotion] = useState<PromotionState>({ visible: false });
  const [gameOver, setGameOver] = useState<GameOverState>({ visible: false });

  const closeGameOver = useCallback(() => setGameOver({ visible: false }), []);

  useEffect(() => {
    seedDebugState(setLobby, setHud, setPromotion, setGameOver);

    window.peakChessDebug = {
      send(action, data = {}) {
        window.postMessage({ action, data }, "*");
      },
    };

    return onNuiMessage((action, data) => {
      if (action === "lobby") {
        if (data.config) setConfig((previous) => ({ ...previous, ...(data.config as Partial<ChessConfig>) }));
        if (data.locale) setLocale((previous) => ({ ...previous, ...(data.locale as Locale) }));
        setLobby((previous) => (
          data.visible === false
            ? { ...previous, visible: false }
            : {
                visible: true,
                id: typeof data.id === "number" ? data.id : previous.id,
                snapshot: (data.snapshot as MatchSnapshot | undefined) ?? previous.snapshot,
                color: data.color === undefined ? previous.color : data.color as Side | null,
              }
        ));
      } else if (action === "hud") {
        if (data.locale) setLocale((previous) => ({ ...previous, ...(data.locale as Locale) }));
        setHud((previous) => (
          data.visible === false
            ? { ...previous, visible: false }
            : {
                visible: true,
                snapshot: (data.snapshot as MatchSnapshot | undefined) ?? previous.snapshot,
                color: data.color === undefined ? previous.color : data.color as Side | null,
              }
        ));
      } else if (action === "promotion") {
        setPromotion({ visible: data.visible === true, color: data.color as Side | undefined });
      } else if (action === "gameover") {
        if (data.locale) setLocale((previous) => ({ ...previous, ...(data.locale as Locale) }));
        setGameOver({ visible: true, data: (data.data as GameOverData | undefined) ?? (data as GameOverData) });
      } else if (action === "closeAll") {
        setLobby({ visible: false });
        setHud({ visible: false });
        setPromotion({ visible: false });
        setGameOver({ visible: false });
      }
    });
  }, []);

  useEffect(() => {
    if (!getDebugMode()) return;

    const shortcuts: Record<string, string> = {
      "1": "lobby",
      "2": "hud",
      "3": "promotion",
      "4": "result",
      "5": "all",
    };

    const onDebugKey = (event: KeyboardEvent) => {
      const mode = shortcuts[event.key];
      if (mode) setDebugState(mode, setLobby, setHud, setPromotion, setGameOver);
    };

    window.addEventListener("keydown", onDebugKey);
    return () => window.removeEventListener("keydown", onDebugKey);
  }, []);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape" && lobby.visible) {
        void postNui("closeLobby");
      }
    };

    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [lobby.visible]);

  const hasVisibleUi = useMemo(() => lobby.visible || hud.visible || promotion.visible || gameOver.visible, [gameOver.visible, hud.visible, lobby.visible, promotion.visible]);

  return (
    <div className={cx("app", hasVisibleUi && "is-visible")}>
      {lobby.visible && <Lobby state={lobby} config={config} locale={locale} />}
      {hud.visible && <Hud state={hud} locale={locale} />}
      {promotion.visible && <PromotionModal state={promotion} locale={locale} />}
      <ResultBanner state={gameOver} locale={locale} onClose={closeGameOver} />
    </div>
  );
}
