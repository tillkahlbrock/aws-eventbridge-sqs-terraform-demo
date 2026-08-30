import { publish } from "@platform/events";

const orderId = process.argv[2] ?? `ORD-${Date.now()}`;

const envelope = await publish({
  domain: "orders",
  service: "order-service",
  type: "OrderCreated",
  payload: { orderId },
});

console.log(
  `OrderCreated für ${orderId} veröffentlicht, Envelope-ID ${envelope.id}`,
);
