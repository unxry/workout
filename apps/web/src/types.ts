export type TabKey = "home" | "nutrition" | "training" | "progress" | "coach" | "profile";

export type MacroMetric = {
  label: string;
  current: number;
  target: number;
  unit: string;
  tone: "violet" | "green" | "amber";
};

export type CoachEvent = {
  id: string;
  event_type: string;
  severity: "info" | "warning" | "critical";
  title: string;
  body: string;
  recommendation: string;
  action_plan: string[];
  created_at: string;
};

export type Strategy = {
  bmr: number;
  tdee: number;
  calorie_target: number;
  protein_target_g: number;
  fat_target_g: number;
  carbs_target_g: number;
  water_target_ml: number;
  weekly_weight_delta_kg: number;
  expected_goal_date: string | null;
  rationale: string;
};

export type Snapshot = {
  snapshot_date: string;
  weight_kg: number | null;
  calories: number;
  protein_g: number;
  fat_g: number;
  carbs_g: number;
  water_ml: number;
  steps: number;
  sleep_hours: number | null;
  mood: number | null;
  stress_level: number | null;
  workouts_count: number;
};

