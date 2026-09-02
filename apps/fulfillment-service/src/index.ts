import {
  DeleteMessageCommand,
  type Message,
  ReceiveMessageCommand,
  SQSClient,
} from "@aws-sdk/client-sqs";
import {
  createEnvelope,
  parse,
  publish,
  toRoutingFields,
  type Envelope,
} from "@platform/events";
import {
  FULFILLMENT_DOMAIN,
  FULFILLMENT_SERVICE,
  SHIPMENT_PREPARED,
  SHIPMENT_PREPARED_VERSION,
  SUPPORTED_ORDER_CREATED_VERSION,
  type OrderCreatedRead,
  type ShipmentPreparedPayload,
} from "./events.js";

const queueUrl = process.env.QUEUE_URL;

if (!queueUrl) {
  console.error("Umgebungsvariable QUEUE_URL fehlt.");
  process.exit(1);
}

const client = new SQSClient({});

// Idempotenz auf der Envelope-ID. EventBridge vergibt bei Replay und
// SDK-Retry eine neue ID, die Envelope-ID bleibt gleich. In Produktion trägt
// diesen Speicher eine DynamoDB-Tabelle mit TTL, nicht der Prozess.
const processedIds = new Set<string>();

const controller = new AbortController();
let running = true;

process.on("SIGINT", () => {
  running = false;
  controller.abort();
});

console.log(`Warte auf Events an ${queueUrl}. Ctrl-C beendet.`);

while (running) {
  let messages: Message[];

  try {
    const result = await client.send(
      new ReceiveMessageCommand({
        QueueUrl: queueUrl,
        MaxNumberOfMessages: 10,
        WaitTimeSeconds: 20,
      }),
      { abortSignal: controller.signal },
    );
    messages = result.Messages ?? [];
  } catch (error) {
    if (!running) break;
    throw error;
  }

  for (const message of messages) {
    let deletable: boolean;

    try {
      deletable = await handleMessage(message);
    } catch (error) {
      // Die Message kehrt nach dem Visibility Timeout zurück.
      console.error(`Verarbeitung fehlgeschlagen: ${describe(error)}`);
      continue;
    }

    if (deletable) {
      await client.send(
        new DeleteMessageCommand({
          QueueUrl: queueUrl,
          ReceiptHandle: message.ReceiptHandle,
        }),
      );
    }
  }
}

console.log("Beendet.");

// Der Rückgabewert entscheidet, ob die Message gelöscht wird. Wer nicht löscht,
// überlässt sie nach maxReceiveCount der Dead-Letter-Queue.
async function handleMessage(message: Message): Promise<boolean> {
  let envelope: Envelope<OrderCreatedRead>;

  try {
    envelope = parse<OrderCreatedRead>(message.Body ?? "");
  } catch (error) {
    // Poison Message. Ein Retry repariert sie nicht. SQS hat aber keinen
    // anderen Weg in die DLQ: die Message muss maxReceiveCount Empfänge
    // durchlaufen.
    console.error(
      `Message nicht lesbar, geht nach maxReceiveCount in die DLQ: ` +
        describe(error),
    );
    return false;
  }

  // Die Versionsprüfung steht vor jedem Zugriff auf die Payload.
  if (envelope.version !== SUPPORTED_ORDER_CREATED_VERSION) {
    console.error(
      `Version ${envelope.version} wird nicht unterstützt, erwartet ` +
        `${SUPPORTED_ORDER_CREATED_VERSION}. Die Message geht nach ` +
        `maxReceiveCount in die DLQ.`,
    );
    return false;
  }

  if (processedIds.has(envelope.id)) {
    console.log(`Envelope ${envelope.id} ist bereits verarbeitet.`);
    return true;
  }

  console.log(
    `${envelope.type} für ${envelope.payload.orderId} empfangen ` +
      `(id=${envelope.id}, correlationId=${envelope.correlationId}, ` +
      `timestamp=${envelope.timestamp})`,
  );

  await prepareShipment(envelope);

  processedIds.add(envelope.id);

  return true;
}

// Ein Consumer ist meistens auch ein Producer. Die correlationId des
// eingehenden Events setzt die Kette fort, statt eine neue zu beginnen.
async function prepareShipment(
  order: Envelope<OrderCreatedRead>,
): Promise<void> {
  const payload: ShipmentPreparedPayload = {
    orderId: order.payload.orderId,
    shipmentId: `SHP-${order.payload.orderId}`,
  };

  const input = {
    domain: FULFILLMENT_DOMAIN,
    service: FULFILLMENT_SERVICE,
    type: SHIPMENT_PREPARED,
    version: SHIPMENT_PREPARED_VERSION,
    payload,
    correlationId: order.correlationId,
  };

  // Veröffentlichen braucht einen Eintrag in producers.tf für diesen Account.
  // Ohne EVENT_BUS_ARN zeigt der Dry-Run die Kette trotzdem.
  if (!process.env.EVENT_BUS_ARN) {
    const envelope = createEnvelope(input);
    const routing = toRoutingFields(envelope);

    console.log(
      `Dry-Run ${routing.source} ${routing.detailType} ` +
        `(id=${envelope.id}, correlationId=${envelope.correlationId})`,
    );
    return;
  }

  const envelope = await publish(input);

  console.log(
    `${envelope.type} veröffentlicht ` +
      `(id=${envelope.id}, correlationId=${envelope.correlationId})`,
  );
}

function describe(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
