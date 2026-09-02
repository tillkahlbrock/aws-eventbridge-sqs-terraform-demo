import { publish } from "@platform/events";
import {
  ORDERS_DOMAIN,
  ORDER_CREATED,
  ORDER_CREATED_VERSION,
  ORDER_SERVICE,
  type OrderCreatedPayload,
} from "./events.js";

const orderId = process.argv[2] ?? `ORD-${Date.now()}`;

const payload: OrderCreatedPayload = { orderId, totalCents: 4999 };

// Ohne eigene correlationId beginnt hier eine neue Kette. Der Consumer gibt
// sie an sein Folge-Event weiter.
const envelope = await publish({
  domain: ORDERS_DOMAIN,
  service: ORDER_SERVICE,
  type: ORDER_CREATED,
  version: ORDER_CREATED_VERSION,
  payload,
});

console.log(
  `${envelope.type} für ${orderId} veröffentlicht ` +
    `(id=${envelope.id}, correlationId=${envelope.correlationId})`,
);
