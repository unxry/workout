import type { CoachEvent, Snapshot, Strategy } from "./types";

const API_URL = import.meta.env.VITE_API_URL || "http://localhost:8000";

declare global {
  interface Window {
    Telegram?: {
      WebApp?: {
        initData?: string;
        ready?: () => void;
        expand?: () => void;
        HapticFeedback?: {
          impactOccurred?: (style: "light" | "medium" | "heavy") => void;
        };
      };
    };
  }
}

const demoHeaders = (): Record<string, string> => {
  const initData = window.Telegram?.WebApp?.initData;
  return initData
    ? { "X-Telegram-Init-Data": initData }
    : { "X-Dev-Telegram-Id": "dev-user", "X-Telegram-Id": "dev-user" };
};

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers = new Headers(options.headers);
  headers.set("Content-Type", "application/json");
  Object.entries(demoHeaders()).forEach(([key, value]) => headers.set(key, value));

  const response = await fetch(`${API_URL}${path}`, {
    ...options,
    headers,
  });
  if (!response.ok) {
    throw new Error(await response.text());
  }
  return response.json() as Promise<T>;
}

export const api = {
  strategy: () => request<Strategy>("/api/users/me/strategy"),
  snapshots: () => request<Snapshot[]>("/api/tracking/snapshots?days=30"),
  coachFeed: () => request<CoachEvent[]>("/api/coach/feed"),
  analyze: () => request<CoachEvent[]>("/api/coach/analyze", { method: "POST" }),
  chat: (message: string) =>
    request<{ answer: string; used_memory: string[] }>("/api/coach/chat", {
      method: "POST",
      body: JSON.stringify({ message }),
    }),
};

export const demoStrategy: Strategy = {
  bmr: 1780,
  tdee: 2759,
  calorie_target: 2262,
  protein_target_g: 172,
  fat_target_g: 72,
  carbs_target_g: 232,
  water_target_ml: 2870,
  weekly_weight_delta_kg: -0.64,
  expected_goal_date: "2026-12-03",
  rationale: "Moderate deficit designed to preserve muscle and reduce rebound risk.",
};

export const demoSnapshots: Snapshot[] = Array.from({ length: 14 }).map((_, index) => ({
  snapshot_date: `2026-08-${String(index + 1).padStart(2, "0")}`,
  weight_kg: 86.4 - index * 0.18 + (index % 3) * 0.08,
  calories: 2140 + (index % 4) * 90,
  protein_g: 138 + (index % 5) * 8,
  fat_g: 66 + (index % 3) * 4,
  carbs_g: 205 + (index % 4) * 12,
  water_ml: 2200 + (index % 3) * 250,
  steps: 6400 + (index % 5) * 730,
  sleep_hours: 6.2 + (index % 4) * 0.35,
  mood: 4,
  stress_level: 2,
  workouts_count: index % 4 === 0 ? 1 : 0,
}));

export const demoEvents: CoachEvent[] = [
  {
    id: "1",
    event_type: "low_protein",
    severity: "warning",
    title: "Белок отстает от цели",
    body: "До дневного ориентира осталось 37 г. Это влияет на сытость и сохранение мышц.",
    recommendation: "Сделай следующий прием пищи белковым: творог, рыба, яйца, курица, тофу или греческий йогурт.",
    action_plan: ["Добавить белковый ужин", "Оставить жиры умеренными", "Записать прием пищи после еды"],
    created_at: new Date().toISOString(),
  },
  {
    id: "2",
    event_type: "low_sleep",
    severity: "info",
    title: "Сон может усилить голод",
    body: "Прошлой ночью было 5.8 часа сна. Завтра вес может держать воду, а аппетит стать выше.",
    recommendation: "Не урезай калории агрессивнее. Держи план простым и добавь прогулку после еды.",
    action_plan: ["Запланировать завтрак", "Снизить интенсивность тренировки", "Лечь в фиксированное время"],
    created_at: new Date().toISOString(),
  },
];
