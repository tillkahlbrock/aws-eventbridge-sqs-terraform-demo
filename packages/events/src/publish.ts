import {
  EventBridgeClient,
  PutEventsCommand,
} from "@aws-sdk/client-eventbridge";
import {
  createEnvelope,
  toRoutingFields,
  type Envelope,
  type EnvelopeInput,
} from "./envelope.js";

export interface PublishOptions {
  client?: EventBridgeClient;
  eventBusArn?: string;
  sourcePrefix?: string;
}

let defaultClient: EventBridgeClient | undefined;

export async function publish<T>(
  input: EnvelopeInput<T>,
  options: PublishOptions = {},
): Promise<Envelope<T>> {
  const eventBusArn = options.eventBusArn ?? process.env.EVENT_BUS_ARN;

  if (!eventBusArn) {
    throw new Error(
      "Keine Event-Bus-ARN. Setze EVENT_BUS_ARN oder übergib eventBusArn.",
    );
  }

  const envelope = createEnvelope(input);
  const routing = toRoutingFields(envelope, options.sourcePrefix);

  defaultClient ??= new EventBridgeClient({});
  const client = options.client ?? defaultClient;

  const result = await client.send(
    new PutEventsCommand({
      Entries: [
        {
          EventBusName: eventBusArn,
          Source: routing.source,
          DetailType: routing.detailType,
          Detail: JSON.stringify(envelope),
        },
      ],
    }),
  );

  // PutEvents antwortet auch dann mit 200, wenn ein Eintrag fehlschlägt.
  if (result.FailedEntryCount) {
    const entry = result.Entries?.[0];
    throw new Error(
      `PutEvents fehlgeschlagen: ${entry?.ErrorCode} ${entry?.ErrorMessage}`,
    );
  }

  return envelope;
}
