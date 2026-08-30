import { randomUUID } from "node:crypto";

export const DEFAULT_SOURCE_PREFIX = "com.example";

export interface Envelope<T = unknown> {
  id: string;
  version: number;
  timestamp: string;
  domain: string;
  service: string;
  type: string;
  correlationId: string;
  payload: T;
}

export interface EnvelopeInput<T> {
  domain: string;
  service: string;
  type: string;
  payload: T;
  version?: number;
  correlationId?: string;
}

export function createEnvelope<T>(input: EnvelopeInput<T>): Envelope<T> {
  requireValue("domain", input.domain);
  requireValue("service", input.service);
  requireValue("type", input.type);

  const id = randomUUID();

  return {
    id,
    version: input.version ?? 1,
    timestamp: new Date().toISOString(),
    domain: input.domain,
    service: input.service,
    type: input.type,
    // Ohne eigene correlationId beginnt hier eine neue Kette.
    correlationId: input.correlationId ?? id,
    payload: input.payload,
  };
}

// Source und DetailType sind Pflichtfelder. Sie werden hier abgeleitet, damit
// sie nicht vom Envelope abweichen können.
export function toRoutingFields(
  envelope: Envelope,
  sourcePrefix: string = DEFAULT_SOURCE_PREFIX,
): { source: string; detailType: string } {
  return {
    source: `${sourcePrefix}.${envelope.domain}`,
    detailType: envelope.type,
  };
}

function requireValue(name: string, value: string): void {
  if (!value || value.trim() === "") {
    throw new Error(`Envelope-Feld "${name}" darf nicht leer sein.`);
  }
}
