const PRODUCTION_BASE = "https://ll.thespacedevs.com/2.3.0";

export interface Throttle {
  your_request_limit: number;
  limit_frequency_secs: number;
  current_use: number;
  next_use_secs: number;
}

export interface Ll2Page<T> {
  count: number;
  next: string | null;
  results: T[];
}

export function ll2BaseUrl(): string {
  return (process.env.LL2_BASE_URL ?? PRODUCTION_BASE).replace(/\/$/, "");
}

export function ll2Source(): "lldev" | "ll2" {
  return ll2BaseUrl().includes("lldev") ? "lldev" : "ll2";
}

export async function ll2Get<T>(pathAndQuery: string): Promise<T> {
  const path = pathAndQuery.startsWith("/") ? pathAndQuery : `/${pathAndQuery}`;
  const headers: Record<string, string> = {
    Accept: "application/json",
    "User-Agent": process.env.LL2_USER_AGENT ?? "LaunchWatch/0.1 (local-dev)",
  };
  if (process.env.LL2_TOKEN) {
    headers.Authorization = `Token ${process.env.LL2_TOKEN}`;
  }

  const response = await fetch(`${ll2BaseUrl()}${path}`, { headers });
  if (!response.ok) {
    throw new Error(`LL2 ${response.status} for ${path}`);
  }
  return (await response.json()) as T;
}

export function hasBudget(throttle: Throttle, callsNeeded: number): boolean {
  return throttle.your_request_limit - throttle.current_use > callsNeeded;
}
