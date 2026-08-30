import type { Envelope } from "./envelope.js";

const REQUIRED_FIELDS = [
  "id",
  "version",
  "timestamp",
  "domain",
  "service",
  "type",
  "correlationId",
] as const;

// Der Body einer SQS-Message ist das vollständige EventBridge-Event. Der
// Envelope liegt in detail.
export function parse<T = unknown>(body: string | object): Envelope<T> {
  const event = typeof body === "string" ? safeParse(body) : body;
  const detail = (event as { detail?: unknown }).detail ?? event;

  if (typeof detail !== "object" || detail === null) {
    throw new Error("Kein Envelope in detail gefunden.");
  }

  const candidate = detail as Record<string, unknown>;
  const missing = REQUIRED_FIELDS.filter((field) => candidate[field] == null);

  if (missing.length > 0) {
    throw new Error(`Envelope unvollständig, es fehlt: ${missing.join(", ")}`);
  }

  return candidate as unknown as Envelope<T>;
}

function safeParse(body: string): unknown {
  try {
    return JSON.parse(body);
  } catch {
    throw new Error("Message-Body ist kein gültiges JSON.");
  }
}
