import { randomUUID } from "node:crypto";
import {
  EventBridgeClient,
  PutEventsCommand,
} from "@aws-sdk/client-eventbridge";

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    console.error(`Missing environment variable ${name}.`);
    process.exit(1);
  }
  return value;
}

// The ARN, not the name. PutEvents targets a bus in another account.
const eventBusArn = required("EVENT_BUS_ARN");
const orderId = process.argv[2] ?? randomUUID();

const client = new EventBridgeClient({});

const result = await client.send(
  new PutEventsCommand({
    Entries: [
      {
        EventBusName: eventBusArn,
        Source: "com.example.orders",
        DetailType: "OrderCreated",
        Detail: JSON.stringify({ orderId }),
      },
    ],
  }),
);

const entry = result.Entries?.[0];

// PutEvents answers 200 even when an entry fails. Always read FailedEntryCount.
if (result.FailedEntryCount) {
  console.error(`Publish failed: ${entry?.ErrorCode} ${entry?.ErrorMessage}`);
  process.exit(1);
}

console.log(`Published OrderCreated for order ${orderId} as ${entry?.EventId}`);
