import { createEnvelope, publish, toRoutingFields } from "@platform/events";
import {
  ORDERS_DOMAIN,
  ORDER_CREATED,
  ORDER_CREATED_VERSION,
  ORDER_SERVICE,
  type OrderCreatedPayload,
} from "./events.js";

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const orderId = args.find((arg) => !arg.startsWith("--")) ?? `ORD-${Date.now()}`;

// Eine Kette beginnt oft vor dem ersten Event, etwa an einem HTTP-Request.
// Ohne diesen Wert vergibt die Bibliothek eine neue correlationId.
const correlationId =
  readOption("--correlation-id") ?? process.env.CORRELATION_ID;

const payload: OrderCreatedPayload = { orderId, totalCents: 4999 };

const input = {
  domain: ORDERS_DOMAIN,
  service: ORDER_SERVICE,
  type: ORDER_CREATED,
  version: ORDER_CREATED_VERSION,
  payload,
  correlationId,
};

// Der Dry-Run zeigt Envelope und Routing-Felder ohne AWS-Aufruf. Die beiden
// Routing-Felder müssen zum event_pattern des Consumer-Stacks passen.
if (dryRun) {
  const envelope = createEnvelope(input);
  const routing = toRoutingFields(envelope);

  console.log("Dry-Run, kein PutEvents.");
  console.log(`Source     = ${routing.source}`);
  console.log(`DetailType = ${routing.detailType}`);
  console.log(JSON.stringify(envelope, null, 2));
} else {
  const envelope = await publish(input);

  console.log(
    `${envelope.type} für ${orderId} veröffentlicht ` +
      `(id=${envelope.id}, correlationId=${envelope.correlationId})`,
  );
}

function readOption(name: string): string | undefined {
  const prefix = `${name}=`;
  const inline = args.find((arg) => arg.startsWith(prefix));

  if (inline) {
    return inline.slice(prefix.length);
  }

  const index = args.indexOf(name);

  return index >= 0 ? args[index + 1] : undefined;
}
