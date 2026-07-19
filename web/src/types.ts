export type Side = "white" | "black";
export type PieceCode = `${"w" | "b"}${"p" | "r" | "n" | "b" | "q" | "k"}`;

export interface ChessConfig {
  betEnabled: boolean;
  betPresets: number[];
  betMin: number;
  betMax: number;
  aiEnabled: boolean;
  aiLevels: string[];
  account: string;
}

export interface MoveSummary {
  from: string;
  to: string;
  flag?: string;
  captured?: PieceCode | null;
}

export interface MatchSnapshot {
  id: number;
  status: "idle" | "waiting" | "playing" | "over";
  seats: Record<Side, boolean | "AI">;
  ready?: Record<Side, boolean>;
  bet?: Record<Side, number>;
  aiLevel?: string | null;
  turn?: "w" | "b" | null;
  board?: Record<string, PieceCode>;
  lastMove?: MoveSummary | null;
  lastMoves?: Partial<Record<Side, MoveSummary>>;
  check?: boolean;
  result?: GameOverData | null;
}

export interface GameOverData {
  id?: number;
  winner?: Side | null;
  reason?: string;
  yourColor?: Side | null;
}

export type Locale = Record<string, string>;

export interface LobbyState {
  visible: boolean;
  id?: number;
  snapshot?: MatchSnapshot;
  color?: Side | null;
}

export interface HudState {
  visible: boolean;
  snapshot?: MatchSnapshot;
  color?: Side | null;
}

export interface PromotionState {
  visible: boolean;
  color?: Side;
}

export interface GameOverState {
  visible: boolean;
  data?: GameOverData;
}
