import {
  Barbell,
  Bell,
  Brain,
  ChartLineUp,
  Drop,
  Fire,
  ForkKnife,
  House,
  Microphone,
  PersonSimpleWalk,
  Pill,
  Plus,
  Robot,
  UserCircle,
} from "@phosphor-icons/react";
import type { Icon } from "@phosphor-icons/react";
import { AnimatePresence, motion } from "framer-motion";
import { useEffect, useMemo, useState } from "react";
import { Area, AreaChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";

import { api, demoEvents, demoSnapshots, demoStrategy } from "./api";
import type { CoachEvent, MacroMetric, Snapshot, Strategy, TabKey } from "./types";

const tabs: { key: TabKey; label: string; icon: Icon }[] = [
  { key: "home", label: "Главная", icon: House },
  { key: "nutrition", label: "Питание", icon: ForkKnife },
  { key: "coach", label: "Добавить", icon: Plus },
  { key: "training", label: "Тренировки", icon: Barbell },
  { key: "profile", label: "Профиль", icon: UserCircle },
];

const toneMap = {
  violet: "#a985ff",
  green: "#62df7a",
  amber: "#ffd243",
  blue: "#4a9cff",
  orange: "#ff814f",
};

function App() {
  const [activeTab, setActiveTab] = useState<TabKey>("home");
  const [strategy, setStrategy] = useState<Strategy>(demoStrategy);
  const [snapshots, setSnapshots] = useState<Snapshot[]>(demoSnapshots);
  const [events, setEvents] = useState<CoachEvent[]>(demoEvents);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    window.Telegram?.WebApp?.ready?.();
    window.Telegram?.WebApp?.expand?.();

    Promise.all([api.strategy(), api.snapshots(), api.coachFeed()])
      .then(([nextStrategy, nextSnapshots, nextEvents]) => {
        setStrategy(nextStrategy);
        if (nextSnapshots.length > 0) setSnapshots(nextSnapshots);
        if (nextEvents.length > 0) setEvents(nextEvents);
      })
      .catch(() => setError("Демо-режим"))
      .finally(() => setLoading(false));
  }, []);

  const latest = snapshots[snapshots.length - 1] ?? demoSnapshots[demoSnapshots.length - 1];
  const metrics: MacroMetric[] = useMemo(
    () => [
      { label: "Калории", current: latest.calories, target: strategy.calorie_target || 2900, unit: "ккал", tone: "green" },
      { label: "Белок", current: Number(latest.protein_g.toFixed(1)), target: strategy.protein_target_g || 125, unit: "г", tone: "violet" },
      { label: "Жиры", current: Number(latest.fat_g.toFixed(1)), target: strategy.fat_target_g || 75, unit: "г", tone: "violet" },
      { label: "Углеводы", current: Number(latest.carbs_g.toFixed(1)), target: strategy.carbs_target_g || 400, unit: "г", tone: "amber" },
    ],
    [latest, strategy],
  );

  return (
    <main className="min-h-[100dvh] overflow-x-hidden bg-[#0f1015] text-zinc-100">
      <div className="fixed inset-0 pointer-events-none bg-[radial-gradient(circle_at_14%_8%,rgba(96,115,180,0.13),transparent_28%),radial-gradient(circle_at_86%_18%,rgba(169,133,255,0.12),transparent_22%),linear-gradient(145deg,#11131a_0%,#0c0d11_54%,#15161c_100%)]" />
      <div className="fixed inset-0 pointer-events-none opacity-[0.12] [background-image:linear-gradient(115deg,rgba(255,255,255,.035),transparent_32%),linear-gradient(245deg,rgba(255,255,255,.025),transparent_40%)]" />

      <div className="relative mx-auto min-h-[100dvh] max-w-[430px] px-5 pb-24 pt-4 sm:max-w-[520px]">
        <AnimatePresence mode="wait">
          <motion.section
            key={activeTab}
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ type: "spring", stiffness: 140, damping: 24 }}
          >
            {activeTab === "home" && (
              <Home latest={latest} metrics={metrics} snapshots={snapshots} events={events} strategy={strategy} loading={loading} error={error} />
            )}
            {activeTab === "nutrition" && <Nutrition metrics={metrics} />}
            {activeTab === "training" && <Training />}
            {activeTab === "progress" && <Progress snapshots={snapshots} />}
            {activeTab === "coach" && <Coach events={events} setEvents={setEvents} />}
            {activeTab === "profile" && <Profile strategy={strategy} />}
          </motion.section>
        </AnimatePresence>

        <BottomNavigation activeTab={activeTab} setActiveTab={setActiveTab} />
      </div>
    </main>
  );
}

function Home({
  latest,
  metrics,
  snapshots,
  events,
  strategy,
  loading,
  error,
}: {
  latest: Snapshot;
  metrics: MacroMetric[];
  snapshots: Snapshot[];
  events: CoachEvent[];
  strategy: Strategy;
  loading: boolean;
  error: string | null;
}) {
  const updatedLabel = loading ? "Обновление" : error ?? "Обновлено 23:58";
  return (
    <div className="space-y-4">
      <TopBar updatedLabel={updatedLabel} />
      <Section title="Сводка за день">
        <div className="grid grid-cols-2 gap-3">
          {metrics.map((metric, index) => (
            <MetricCard key={metric.label} metric={metric} index={index} />
          ))}
        </div>
      </Section>
      <Section title="Тренд веса">
        <WeightTrend snapshots={snapshots} strategy={strategy} />
      </Section>
      <Section title="Рекомендации ИИ">
        <CoachRecommendation event={events[0]} />
      </Section>
      <Section title="План на день" action="См. все">
        <DailyPlan latest={latest} strategy={strategy} />
      </Section>
      <Section title="Напоминания" action="См. все">
        <Reminders />
      </Section>
    </div>
  );
}

function TopBar({ updatedLabel }: { updatedLabel: string }) {
  return (
    <header className="pt-2">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="font-mono text-[1.22rem] font-semibold leading-none tracking-tight text-white">01:01</p>
          <h1 className="mt-5 text-[1.38rem] font-semibold leading-none tracking-wide text-white">05.08.2026</h1>
          <p className="mt-1 text-[0.78rem] text-zinc-500">{updatedLabel}</p>
        </div>
        <motion.button
          whileTap={{ scale: 0.97 }}
          className="mt-[2.9rem] inline-flex h-8 items-center gap-1.5 rounded-full border border-white/15 bg-white/[0.045] px-3 text-[0.74rem] font-medium text-zinc-100 shadow-[inset_0_1px_0_rgba(255,255,255,0.1)] backdrop-blur-2xl"
        >
          <Robot size={17} weight="duotone" className="text-[#a985ff]" />
          ИИ-помощник
        </motion.button>
      </div>
    </header>
  );
}

function Section({ title, action, children }: { title: string; action?: string; children: React.ReactNode }) {
  return (
    <section>
      <div className="mb-2 flex items-center justify-between">
        <h2 className="text-[0.92rem] font-semibold uppercase leading-none tracking-[0.105em] text-zinc-400">{title}</h2>
        {action && <button className="text-[0.82rem] font-medium text-zinc-100 active:scale-[0.98]">{action}</button>}
      </div>
      {children}
    </section>
  );
}

function MetricCard({ metric, index }: { metric: MacroMetric; index: number }) {
  const percent = metric.target ? Math.round((metric.current / metric.target) * 100) : 0;
  const capped = Math.min(percent, 100);
  const color = toneMap[metric.tone];

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.045, type: "spring", stiffness: 160, damping: 24 }}
      className="h-[5.45rem] rounded-[15px] border border-white/[0.12] bg-white/[0.055] px-3 py-2.5 shadow-[inset_0_1px_0_rgba(255,255,255,0.1),0_18px_42px_rgba(0,0,0,0.20)] backdrop-blur-2xl"
    >
      <p className="text-[0.74rem] text-zinc-400">{metric.label}</p>
      <div className="mt-1.5 flex items-baseline gap-1 whitespace-nowrap">
        <span className="font-mono text-[0.98rem] font-semibold leading-none text-white">{metric.current}</span>
        <span className="text-[0.7rem] text-zinc-400">/ {metric.target} {metric.unit}</span>
      </div>
      <div className="mt-2.5 h-1 overflow-hidden rounded-full bg-white/10">
        <motion.div
          initial={{ width: 0 }}
          animate={{ width: `${capped}%` }}
          transition={{ type: "spring", stiffness: 100, damping: 22 }}
          className="h-full rounded-full"
          style={{ backgroundColor: color, boxShadow: `0 0 10px ${color}55` }}
        />
      </div>
      <p className="mt-1.5 font-mono text-[0.68rem] text-zinc-400">{percent}%</p>
    </motion.div>
  );
}

function WeightTrend({ snapshots, strategy }: { snapshots: Snapshot[]; strategy: Strategy }) {
  const trend = useMemo(() => buildWeightTrend(snapshots), [snapshots]);
  const first = trend.values[0]?.weight ?? 62;
  const last = trend.values[trend.values.length - 1]?.weight ?? 63;
  const target = strategy.expected_goal_date ? "Цель активна" : `Цель: ${first.toFixed(1)} → ${(last + 4).toFixed(1)} кг`;

  return (
    <GlassCard className="relative h-[112px] overflow-hidden px-2.5 pb-2 pt-1.5">
      <div className="pointer-events-none absolute inset-x-6 top-7 h-10 rounded-full bg-[#62df7a]/[0.07] blur-2xl" />
      <svg viewBox="0 0 520 92" className="relative h-[82px] w-full overflow-visible" role="img" aria-label="Тренд веса">
        <defs>
          <linearGradient id="trendStroke" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor="#ff684e" />
            <stop offset="42%" stopColor="#ffd24a" />
            <stop offset="70%" stopColor="#78dd67" />
            <stop offset="100%" stopColor="#62d87d" />
          </linearGradient>
          <linearGradient id="trendArea" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#82df72" stopOpacity="0.18" />
            <stop offset="52%" stopColor="#d7b34c" stopOpacity="0.12" />
            <stop offset="100%" stopColor="#ff6a4a" stopOpacity="0.015" />
          </linearGradient>
          <filter id="trendShadow" x="-10%" y="-60%" width="120%" height="220%">
            <feDropShadow dx="0" dy="3" stdDeviation="2.2" floodColor="#05060a" floodOpacity="0.34" />
          </filter>
        </defs>
        <path d={trend.areaPath} fill="url(#trendArea)" opacity="0.85" />
        <path d={trend.linePath} fill="none" stroke="rgba(255,255,255,0.08)" strokeLinecap="round" strokeWidth="3.8" />
        <path d={trend.linePath} fill="none" stroke="url(#trendStroke)" strokeLinecap="round" strokeWidth="1.65" filter="url(#trendShadow)" />
        {trend.highlightPoints.map((point) => (
          <g key={point.label}>
            <text x={point.x} y={point.y - 8} textAnchor="middle" className="fill-zinc-100 font-mono text-[7px] font-semibold">
              {point.weight.toFixed(1)}
            </text>
            <circle cx={point.x} cy={point.y} r="3.2" fill="#15161c" stroke="#d8d8e3" strokeWidth="1.15" />
            <circle cx={point.x} cy={point.y} r="1.05" fill="#a985ff" />
          </g>
        ))}
        {trend.dateTicks.map((tick) => (
          <text key={tick.label} x={tick.x} y="80" textAnchor="middle" className="fill-zinc-500 font-mono text-[7px]">
            {tick.label}
          </text>
        ))}
      </svg>
      <p className="relative -mt-0.5 pl-1 text-[0.82rem] text-zinc-400">{target}</p>
    </GlassCard>
  );
}

function buildWeightTrend(snapshots: Snapshot[]) {
  const rawValues = snapshots
    .filter((item) => item.weight_kg !== null)
    .slice(-5)
    .map((item) => ({
      label: item.snapshot_date.slice(5).replace("-", "."),
      weight: item.weight_kg ?? 0,
    }));
  const values = rawValues.length >= 3 ? rawValues : [
    { label: "01.08", weight: 62.0 },
    { label: "03.08", weight: 63.2 },
    { label: "05.08", weight: 63.0 },
  ];
  const min = Math.min(...values.map((item) => item.weight));
  const max = Math.max(...values.map((item) => item.weight));
  const range = Math.max(max - min, 0.8);
  const width = 520;
  const left = 14;
  const right = 506;
  const top = 18;
  const bottom = 56;
  const points = values.map((item, index) => {
    const x = values.length === 1 ? width / 2 : left + ((right - left) * index) / (values.length - 1);
    const y = bottom - ((item.weight - min) / range) * (bottom - top);
    return { ...item, x, y };
  });
  const linePath = smoothPath(points);
  const areaPath = `${linePath} L ${points[points.length - 1].x} 68 L ${points[0].x} 68 Z`;
  const middleIndex = Math.floor((points.length - 1) / 2);
  const highlightPoints = [points[0], points[middleIndex], points[points.length - 1]].filter(Boolean);
  const dateTicks = [points[0], points[middleIndex], points[points.length - 1]].filter(Boolean);

  return { values, linePath, areaPath, highlightPoints, dateTicks };
}

function smoothPath(points: { x: number; y: number }[]) {
  if (points.length < 2) {
    return "";
  }
  if (points.length === 2) {
    return `M ${points[0].x} ${points[0].y} L ${points[1].x} ${points[1].y}`;
  }

  let path = `M ${points[0].x} ${points[0].y}`;
  for (let index = 0; index < points.length - 1; index += 1) {
    const p0 = points[Math.max(0, index - 1)];
    const p1 = points[index];
    const p2 = points[index + 1];
    const p3 = points[Math.min(points.length - 1, index + 2)];
    const tension = 0.82;
    const cp1x = p1.x + ((p2.x - p0.x) / 6) * tension;
    const cp1y = p1.y + ((p2.y - p0.y) / 6) * tension;
    const cp2x = p2.x - ((p3.x - p1.x) / 6) * tension;
    const cp2y = p2.y - ((p3.y - p1.y) / 6) * tension;
    path += ` C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${p2.x} ${p2.y}`;
  }
  return path;
}

function CoachRecommendation({ event }: { event?: CoachEvent }) {
  return (
    <GlassCard className="flex min-h-[5.15rem] items-center gap-3 px-3 py-2.5">
      <motion.div
        animate={{ scale: [1, 1.035, 1], opacity: [0.92, 1, 0.92] }}
        transition={{ duration: 2.7, repeat: Infinity }}
        className="grid h-[2.7rem] w-[2.7rem] shrink-0 place-items-center rounded-full border-2 border-[#a985ff] bg-[#171a45] shadow-[inset_0_0_18px_rgba(169,133,255,.35),0_0_18px_rgba(169,133,255,.28)]"
      >
        <Robot size={24} weight="duotone" className="text-[#72a7ff]" />
      </motion.div>
      <div className="min-w-0 flex-1">
        <p className="line-clamp-2 text-[0.74rem] leading-4 text-zinc-300">{event?.body ?? "Сегодня план идет стабильно."}</p>
        <p className="mt-0.5 text-[0.82rem] font-semibold text-[#62df7a]">{event?.title ?? "Отличный результат"}</p>
        <p className="mt-0.5 line-clamp-1 text-[0.72rem] leading-4 text-zinc-500">{event?.recommendation ?? "Хочешь подсказку по питанию или тренировке?"}</p>
      </div>
      <button className="h-9 shrink-0 rounded-full border-2 border-[#a985ff] px-3 text-[0.72rem] font-semibold text-zinc-100 shadow-[inset_0_1px_0_rgba(255,255,255,0.13)]">
        Спросить ИИ
      </button>
    </GlassCard>
  );
}

function DailyPlan({ latest, strategy }: { latest: Snapshot; strategy: Strategy }) {
  const rows = [
    {
      icon: ForkKnife,
      title: "Питание",
      value: latest.calories,
      target: strategy.calorie_target || 2900,
      unit: "ккал",
      color: toneMap.green,
    },
    {
      icon: Barbell,
      title: "Тренировка",
      value: 450,
      target: 400,
      unit: "ккал",
      color: toneMap.violet,
    },
    {
      icon: PersonSimpleWalk,
      title: "Активность",
      value: latest.steps,
      target: 10000,
      unit: "шагов",
      color: toneMap.amber,
    },
    {
      icon: Drop,
      title: "Вода",
      value: Number((latest.water_ml / 1000).toFixed(1)),
      target: Number(((strategy.water_target_ml || 2500) / 1000).toFixed(1)),
      unit: "л",
      color: toneMap.blue,
    },
  ];

  return (
    <div className="space-y-2">
      {rows.map((row, index) => (
        <PlanRow key={row.title} {...row} index={index} />
      ))}
    </div>
  );
}

function PlanRow({
  icon: Icon,
  title,
  value,
  target,
  unit,
  color,
  index,
}: {
  icon: Icon;
  title: string;
  value: number;
  target: number;
  unit: string;
  color: string;
  index: number;
}) {
  const percent = target ? Math.round((value / target) * 100) : 0;
  const capped = Math.min(percent, 100);
  return (
    <motion.div
      initial={{ opacity: 0, x: -8 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ delay: index * 0.04, type: "spring", stiffness: 160, damping: 24 }}
      className="grid min-h-[2.18rem] grid-cols-[1.55rem_1fr_auto] items-center gap-1.5 rounded-[10px] border border-white/10 bg-white/[0.052] px-2.5 shadow-[inset_0_1px_0_rgba(255,255,255,0.08)]"
    >
      <Icon size={15} weight="duotone" style={{ color }} />
      <div className="min-w-0">
        <div className="flex items-baseline gap-2">
          <p className="w-[4.25rem] shrink-0 text-[0.68rem] font-medium text-zinc-100">{title}</p>
          <p className="truncate font-mono text-[0.6rem] text-zinc-300">
            {value.toLocaleString("ru-RU")} <span className="text-zinc-500">/ {target.toLocaleString("ru-RU")} {unit}</span>
          </p>
        </div>
        <div className="mt-1 h-1 overflow-hidden rounded-full bg-white/10">
          <motion.div initial={{ width: 0 }} animate={{ width: `${capped}%` }} className="h-full rounded-full" style={{ backgroundColor: color }} />
        </div>
      </div>
      <p className="font-mono text-[0.62rem] text-zinc-200">{percent}%</p>
    </motion.div>
  );
}

function Reminders() {
  const rows = [
    { icon: Bell, title: "Выпей воду", subtitle: "Каждые 2 часа", time: "01:00", color: toneMap.blue },
    { icon: Barbell, title: "Тренировка", subtitle: "Верх тела • 19:00", time: "19:00", color: toneMap.orange },
    { icon: Pill, title: "Добавка", subtitle: "Омега-3 • После еды", time: "13:00", color: toneMap.orange },
  ];

  return (
    <div className="space-y-2">
      {rows.map((row) => (
        <div key={row.title} className="grid min-h-[2.25rem] grid-cols-[1.55rem_1fr_auto] items-center gap-1.5 rounded-[10px] border border-white/10 bg-white/[0.052] px-2.5 shadow-[inset_0_1px_0_rgba(255,255,255,0.08)]">
          <row.icon size={15} weight="duotone" style={{ color: row.color }} />
          <div>
            <p className="text-[0.7rem] font-medium text-zinc-100">{row.title}</p>
            <p className="text-[0.61rem] text-zinc-500">{row.subtitle}</p>
          </div>
          <p className="font-mono text-[0.62rem] text-zinc-300">{row.time}</p>
        </div>
      ))}
    </div>
  );
}

function Nutrition({ metrics }: { metrics: MacroMetric[] }) {
  return (
    <div className="space-y-7 pt-8">
      <Section title="Добавление еды">
        <GlassCard className="space-y-3 p-4">
          {[
            { label: "Сфотографировать еду", icon: ForkKnife },
            { label: "Сказать голосом", icon: Microphone },
            { label: "Написать текстом", icon: Plus },
          ].map((item) => (
            <button key={item.label} className="flex h-14 w-full items-center justify-between rounded-[14px] border border-white/10 bg-white/[0.04] px-4 text-left text-[1rem] transition active:scale-[0.98]">
              <span>{item.label}</span>
              <item.icon size={22} className="text-[#a985ff]" />
            </button>
          ))}
        </GlassCard>
      </Section>
      <Section title="Макросы">
        <div className="grid grid-cols-2 gap-3">
          {metrics.map((metric, index) => (
            <MetricCard key={metric.label} metric={metric} index={index} />
          ))}
        </div>
      </Section>
    </div>
  );
}

function Training() {
  return (
    <div className="space-y-7 pt-8">
      <Section title="Тренировка">
        <GlassCard className="p-4">
          <p className="text-[0.95rem] text-zinc-500">Сегодня</p>
          <h2 className="mt-1 text-2xl font-semibold">Full Body A</h2>
          <div className="mt-5 space-y-4">
            {["Присед 4 x 6", "Жим лежа 4 x 6", "Тяга горизонтальная 3 x 10", "Румынская тяга 3 x 8"].map((exercise) => (
              <div key={exercise} className="flex items-center justify-between border-t border-white/10 pt-3 text-[1rem]">
                <span>{exercise}</span>
                <span className="font-mono text-[#62df7a]">RPE 7</span>
              </div>
            ))}
          </div>
        </GlassCard>
      </Section>
      <Section title="Коррекция ИИ">
        <GlassCard className="p-4">
          <p className="text-[1rem] leading-6 text-zinc-300">
            Из-за короткого сна оставляем рабочие веса, но убираем один отказной подход. Цель дня: техника и стабильность.
          </p>
        </GlassCard>
      </Section>
    </div>
  );
}

function Progress({ snapshots }: { snapshots: Snapshot[] }) {
  return (
    <div className="space-y-7 pt-8">
      <Section title="Прогресс">
        <GlassCard className="h-[360px] p-4">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={snapshots}>
              <defs>
                <linearGradient id="progress" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#62df7a" stopOpacity={0.4} />
                  <stop offset="95%" stopColor="#62df7a" stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis dataKey="snapshot_date" hide />
              <YAxis hide domain={["dataMin - 0.4", "dataMax + 0.4"]} />
              <Tooltip contentStyle={{ background: "#191a20", border: "1px solid rgba(255,255,255,.12)", borderRadius: 14 }} />
              <Area type="monotone" dataKey="weight_kg" stroke="#62df7a" strokeWidth={3} fill="url(#progress)" />
            </AreaChart>
          </ResponsiveContainer>
        </GlassCard>
      </Section>
    </div>
  );
}

function Coach({ events, setEvents }: { events: CoachEvent[]; setEvents: (events: CoachEvent[]) => void }) {
  const [message, setMessage] = useState("Можно ли сегодня пиццу?");
  const [answer, setAnswer] = useState("");

  const runAnalyze = async () => {
    window.Telegram?.WebApp?.HapticFeedback?.impactOccurred?.("medium");
    const nextEvents = await api.analyze().catch(() => events);
    setEvents(nextEvents.length ? nextEvents : events);
  };

  const send = async () => {
    const result = await api.chat(message).catch(() => ({
      answer: "Можно вписать в план. Запиши порцию, оставь следующий прием пищи белковым и добавь прогулку после еды.",
      used_memory: [],
    }));
    setAnswer(result.answer);
  };

  return (
    <div className="space-y-7 pt-8">
      <Section title="AI Chat">
        <GlassCard className="p-4">
          <textarea
            value={message}
            onChange={(event) => setMessage(event.target.value)}
            className="min-h-32 w-full resize-none rounded-[15px] border border-white/10 bg-zinc-950/40 p-4 text-[1rem] outline-none transition focus:border-[#a985ff]"
          />
          <button onClick={send} className="mt-3 h-12 w-full rounded-full bg-[#a985ff] text-[1rem] font-semibold text-white transition active:scale-[0.98]">
            Спросить ИИ
          </button>
          {answer && <p className="mt-4 rounded-[15px] border border-white/10 bg-white/[0.04] p-4 text-[0.98rem] leading-6 text-zinc-300">{answer}</p>}
        </GlassCard>
      </Section>
      <Section title="Память">
        <div className="space-y-2">
          {events.map((event) => (
            <GlassCard key={event.id} className="p-4">
              <div className="flex items-center justify-between gap-3">
                <h3 className="font-semibold">{event.title}</h3>
                <span className="font-mono text-xs text-[#ffd243]">{event.severity}</span>
              </div>
              <p className="mt-2 text-[0.95rem] leading-6 text-zinc-400">{event.recommendation}</p>
            </GlassCard>
          ))}
        </div>
        <button onClick={runAnalyze} className="mt-4 h-12 w-full rounded-full bg-white text-[1rem] font-semibold text-zinc-950 transition active:scale-[0.98]">
          Запустить анализ дня
        </button>
      </Section>
    </div>
  );
}

function Profile({ strategy }: { strategy: Strategy }) {
  return (
    <div className="space-y-7 pt-8">
      <Section title="Стратегия">
        <GlassCard className="p-4">
          <div className="grid grid-cols-2 gap-3">
            <ProfileStat icon={Fire} label="BMR" value={`${strategy.bmr}`} />
            <ProfileStat icon={PersonSimpleWalk} label="TDEE" value={`${strategy.tdee}`} />
            <ProfileStat icon={ForkKnife} label="Цель kcal" value={`${strategy.calorie_target}`} />
            <ProfileStat icon={ChartLineUp} label="Темп" value={`${strategy.weekly_weight_delta_kg} кг`} />
          </div>
          <p className="mt-5 text-[0.98rem] leading-6 text-zinc-400">{strategy.rationale}</p>
        </GlassCard>
      </Section>
    </div>
  );
}

function ProfileStat({ icon: Icon, label, value }: { icon: Icon; label: string; value: string }) {
  return (
    <div className="rounded-[15px] border border-white/10 bg-white/[0.04] p-4">
      <Icon size={20} className="text-[#62df7a]" />
      <p className="mt-3 text-[0.82rem] text-zinc-500">{label}</p>
      <p className="mt-1 font-mono text-[1.1rem] text-white">{value}</p>
    </div>
  );
}

function GlassCard({ className = "", children }: { className?: string; children: React.ReactNode }) {
  return (
    <div className={`rounded-[19px] border border-white/[0.12] bg-white/[0.058] shadow-[inset_0_1px_0_rgba(255,255,255,0.10),0_22px_55px_rgba(0,0,0,0.25)] backdrop-blur-2xl ${className}`}>
      {children}
    </div>
  );
}

function BottomNavigation({ activeTab, setActiveTab }: { activeTab: TabKey; setActiveTab: (tab: TabKey) => void }) {
  return (
    <nav className="fixed bottom-5 left-1/2 w-[calc(100%-1rem)] max-w-[430px] -translate-x-1/2 rounded-[22px] border border-white/[0.07] bg-[#1b1c22]/[0.88] px-3 pb-2 pt-1.5 shadow-[inset_0_1px_0_rgba(255,255,255,0.08),0_24px_70px_rgba(0,0,0,0.50)] backdrop-blur-2xl sm:max-w-[520px]">
      <div className="grid grid-cols-5 items-end gap-1">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.key;
          const isCenter = tab.key === "coach";
          return (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              title={tab.label}
              className={`relative flex h-[2.7rem] flex-col items-center justify-end gap-0.5 text-[0.58rem] transition active:scale-[0.96] ${
                isActive ? "text-[#b99aff]" : "text-zinc-400"
              }`}
            >
              {isCenter ? (
                <span className="mb-0.5 grid h-[2.4rem] w-[2.4rem] place-items-center rounded-full border-[3px] border-[#a985ff] bg-[#242332] text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.18),0_0_24px_rgba(169,133,255,0.20)]">
                  <Icon size={22} weight="regular" />
                </span>
              ) : (
                <>
                  <Icon size={19} weight={isActive ? "fill" : "regular"} />
                  <span>{tab.label}</span>
                </>
              )}
            </button>
          );
        })}
      </div>
    </nav>
  );
}

export default App;
