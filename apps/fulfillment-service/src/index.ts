import {
  DeleteMessageCommand,
  ReceiveMessageCommand,
  SQSClient,
} from "@aws-sdk/client-sqs";
import { parse } from "@platform/events";

const queueUrl = process.env.QUEUE_URL;

if (!queueUrl) {
  console.error("Umgebungsvariable QUEUE_URL fehlt.");
  process.exit(1);
}

const client = new SQSClient({});

const controller = new AbortController();
let running = true;

process.on("SIGINT", () => {
  running = false;
  controller.abort();
});

console.log(`Warte auf Events an ${queueUrl}. Ctrl-C beendet.`);

while (running) {
  let messages;

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
    const envelope = parse<{ orderId: string }>(message.Body ?? "{}");

    console.log(
      `${envelope.type} für ${envelope.payload.orderId} empfangen ` +
        `(id=${envelope.id}, correlationId=${envelope.correlationId})`,
    );

    await client.send(
      new DeleteMessageCommand({
        QueueUrl: queueUrl,
        ReceiptHandle: message.ReceiptHandle,
      }),
    );
  }
}

console.log("Beendet.");
