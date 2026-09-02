import { publish } from "@platform/events";
import {
  ORDERS_DOMAIN,
  ORDER_CREATED,
  ORDER_CREATED_VERSION,
  ORDER_SERVICE,
  type OrderCreatedPayload,
} from "./events.js";

const args = process.argv.slice(2);
const orderId = args.find((arg) => !arg.startsWith("--")) ?? `ORD-${Date.now()}`;

// Eine Kette beginnt oft vor dem ersten Event, etwa an einem HTTP-Request.
// Ohne diesen Wert vergibt die Bibliothek eine neue correlationId.
const correlationId =
  readOption("--correlation-id") ?? process.env.CORRELATION_ID;

const payload: OrderCreatedPayload = { orderId, totalCents: 4999 };

const envelope = await publish({
  domain: ORDERS_DOMAIN,
  service: ORDER_SERVICE,
  type: ORDER_CREATED,
  version: ORDER_CREATED_VERSION,
  payload,
  correlationId,
});

console.log(
  `${envelope.type} für ${orderId} veröffentlicht ` +
    `(id=${envelope.id}, correlationId=${envelope.correlationId})`,
);

// Nur die Form --name=wert. Ein Wert nach einem Leerzeichen wäre von der
// orderId nicht zu unterscheiden.
function readOption(name: string): string | undefined {
  const prefix = `${name}=`;
  const match = args.find((arg) => arg.startsWith(prefix));

  return match?.slice(prefix.length);
}
