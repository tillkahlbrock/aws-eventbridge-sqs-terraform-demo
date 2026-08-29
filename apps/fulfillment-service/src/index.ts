import {
  DeleteMessageCommand,
  ReceiveMessageCommand,
  SQSClient,
} from "@aws-sdk/client-sqs";

interface EventBridgeEnvelope {
  id: string;
  source: string;
  "detail-type": string;
  detail: unknown;
}

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    console.error(`Missing environment variable ${name}.`);
    process.exit(1);
  }
  return value;
}

const queueUrl = required("QUEUE_URL");
const client = new SQSClient({});

// Long polling blocks for 20 seconds. Abort the request so that Ctrl-C answers
// at once instead of after the poll returns.
const controller = new AbortController();
let running = true;

process.on("SIGINT", () => {
  running = false;
  controller.abort();
});

console.log(`Waiting for events on ${queueUrl}. Press Ctrl-C to stop.`);

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
    const envelope = JSON.parse(message.Body ?? "{}") as EventBridgeEnvelope;
    const detail = envelope.detail as { orderId?: string };

    console.log(`Received ${envelope["detail-type"]} for order ${detail.orderId}`);

    // Delete only after the work succeeded. An unhandled error leaves the
    // message on the queue, and the redrive policy moves it to the DLQ.
    await client.send(
      new DeleteMessageCommand({
        QueueUrl: queueUrl,
        ReceiptHandle: message.ReceiptHandle,
      }),
    );
  }
}

console.log("Stopped.");
