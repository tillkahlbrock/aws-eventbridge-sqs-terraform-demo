# AWS EventBridge + SQS Terraform Demo

This repository shows a platform-wide asynchronous eventing pattern. A shared
Amazon EventBridge event bus receives domain events. Amazon SQS delivers those
events to a consumer workload.

The demo contains Terraform only. It makes the ownership boundary between the
Platform Team and the Product Teams visible across three AWS accounts.

**Application producers and consumers are intentionally omitted.** The
repository contains no Lambda function, no container and no event payload
handling. Use the AWS CLI commands in [Manual test](#manual-test) to verify the
infrastructure.

The full requirements are in
[`docs/aws-eventbridge-sqs-terraform-demo-spec.md`](docs/aws-eventbridge-sqs-terraform-demo-spec.md).

## Architecture

```
┌──────────────────────────────────────────────────────┐
│ Platform Account                                     │
│ Platform Team                                        │
│                                                      │
│   Shared EventBridge Event Bus                       │
│   + Event Bus Resource Policy                        │
│   + Receiver-owned EventBridge Rule + IAM Role       │
└───────────────▲───────────────────────┬──────────────┘
                │ PutEvents             │ rule target
                │                       │
┌───────────────┴──────────────┐  ┌─────▼────────────────────────┐
│ Sender Workload Account      │  │ Receiver Workload Account    │
│ Product Team A               │  │ Product Team B               │
│                              │  │                              │
│ Producer IAM Policy / Role   │  │ SQS Queue + DLQ              │
│ (application not included)   │  │ Queue Policy                 │
└──────────────────────────────┘  │ (consumer not included)      │
                                  └──────────────────────────────┘
```

An EventBridge rule always belongs to the account that owns the event bus.
The receiver subscription therefore spans two accounts. The `event-consumer`
module uses two provider configurations for this reason.

## Account mapping

| Account           | Owner          | Purpose                         | Resources in this demo                                              |
|-------------------|----------------|---------------------------------|---------------------------------------------------------------------|
| Platform          | Platform Team  | Shared eventing foundation      | Custom event bus, resource policy, consumer EventBridge rule/target |
| Sender workload   | Product Team A | Publishes domain events         | IAM policy and optional demo role for `events:PutEvents`            |
| Receiver workload | Product Team B | Receives selected domain events | SQS queue, dead-letter queue, redrive configuration, queue policy   |

## Repository layout

```
terraform/
├── modules/                            reusable modules
│   ├── event-platform/                 shared event bus and its resource policy
│   ├── event-producer/                 permission to publish to the shared bus
│   └── event-consumer/                 subscription, rule, target, queues
└── examples/                           deployable roots, one per service
    ├── shared-infra/                    Platform Team
    ├── order-service/                   Product Team A, the producer
    └── persistence-service/             Product Team B, the consumer
```

Each example root is a separate state boundary. The roots do not read each
other's remote state. Shared identifiers, such as the event bus ARN, are passed
as variables. This keeps the hand-off between the teams explicit.

## Root ownership

| Root                          | Owner          | Module used      | Deploys into                           |
|-------------------------------|----------------|------------------|----------------------------------------|
| `examples/shared-infra`       | Platform Team  | `event-platform` | Platform account                       |
| `examples/order-service`      | Product Team A | `event-producer` | Sender workload account                |
| `examples/persistence-service`| Product Team B | `event-consumer` | Platform and receiver workload account |

The roots are named after the service that owns them, not after the AWS account
they target. A root is owned by one team, but it is not limited to one account:
`persistence-service` deploys into two. See
[Deviations from the specification](#deviations-from-the-specification).

## Prerequisites

- Terraform 1.6 or later.
- AWS provider 6.x. Terraform downloads it during `terraform init`.
- Three AWS accounts, or three sets of credentials that map to them.
- One AWS CLI profile per account, or equivalent environment variables.
- All three accounts use the same region. EventBridge sends events to
  cross-account targets in the same region only.

The example roots do not create deployment roles. Supply credentials through
AWS profiles, environment variables or role assumption.

## Deployment

Copy `terraform.tfvars.example` to `terraform.tfvars` in each root. Then edit
the values. Deploy the roots in this order.

### 1. shared-infra, platform account

```bash
cd terraform/examples/shared-infra
terraform init
terraform apply
```

Record the `event_bus_name` and `event_bus_arn` outputs. Hand both values to
the product teams.

### 2. order-service, sender workload account

```bash
cd terraform/examples/order-service
terraform init
terraform apply
```

Set `event_bus_arn` to the value from step 1.

### 3. persistence-service, platform and receiver workload account

```bash
cd terraform/examples/persistence-service
terraform init
terraform apply
```

Set `event_bus_name` and `event_bus_arn` to the values from step 1. This root
uses two provider aliases, `aws.platform` and `aws.receiver`.

Record the `queue_url` output for the manual test.

## Event contract

The demo routes one example event. No code emits or processes it.

```json
{
  "source": "com.example.orders",
  "detail-type": "OrderCreated",
  "detail": { "orderId": "123" }
}
```

The receiver subscribes with this event pattern:

```json
{
  "source": ["com.example.orders"],
  "detail-type": ["OrderCreated"]
}
```

## Manual test

These commands are documentation only. They are not part of the Terraform
configuration.

Publish one test event from the sender workload account. Use the event bus ARN,
because `PutEvents` targets a bus in another account.

```bash
aws events put-events \
  --profile sender-workload-account \
  --region eu-central-1 \
  --entries '[{
    "Source": "com.example.orders",
    "DetailType": "OrderCreated",
    "Detail": "{\"orderId\":\"123\"}",
    "EventBusName": "arn:aws:events:eu-central-1:222222222222:event-bus/async-demo"
  }]'
```

The response must report `"FailedEntryCount": 0`.

Read the event from the consumer queue in the receiver workload account.

```bash
aws sqs receive-message \
  --profile receiver-workload-account \
  --region eu-central-1 \
  --queue-url "<queue_url output from step 3>" \
  --max-number-of-messages 1
```

## Permission model

Two independent permissions control the publish path. Both must allow the call.

1. The event bus resource policy allows `events:PutEvents` from the configured
   sender account.
2. The producer IAM policy allows `events:PutEvents` on that bus ARN only.

The delivery path uses an execution role.

1. EventBridge assumes the platform-side execution role. The role trusts
   `events.amazonaws.com`.
2. The identity policy of that role allows `sqs:SendMessage` on the consumer
   queue ARN only.
3. The queue policy in the receiver account names that role ARN as the only
   allowed sender.
4. The rule target sets `role_arn` to that role.

See [Sending events to an AWS service in another account](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-service-cross-account.html).

## Verification

```bash
terraform fmt -check -recursive terraform/
```

Run `terraform validate` in each example root after `terraform init`.

## Deviations from the specification

The specification names the deployable roots after the AWS accounts:
`platform-account`, `sender-workload-account` and `receiver-workload-account`.
This repository names them after the service that owns them.

Reasons:

- An AWS account is a deployment target, not an identity. Account names bind a
  root to exactly one account. One account can hold many services.
- The consumer root already deploys into two accounts. It creates the
  EventBridge rule in the platform account and the queues in the receiver
  workload account. An account name cannot describe it correctly.
- Ownership follows the team and the service. Account names hide the owner.

The subscription resources also carry the name of the consuming service, for
example `persistence-service-order-created`. Several services can subscribe to
the same event without a name collision.

The README states the target account for each root, so the account boundary
stays visible.

## Known demo limitations

These points are out of scope for the demo. A production setup must address
them.

- The execution role trust policy has no `aws:SourceArn` or `aws:SourceAccount`
  condition. It follows the AWS documentation example. Add a condition after
  you verify it against the EventBridge behaviour in your accounts.
- The queues use SQS-managed encryption defaults. There is no customer-managed
  KMS key, and therefore no cross-account key policy.
- There is no schema registry, no event catalog and no event versioning.
- There is no multi-region setup, no disaster recovery and no alarming.
- The optional demo role in the sender account is a convenience for manual
  tests. A real workload attaches the IAM policy to its own runtime role.
  Set `create_demo_role = false` for that case.
