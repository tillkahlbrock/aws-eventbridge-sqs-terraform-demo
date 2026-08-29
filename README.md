# AWS EventBridge + SQS Terraform Demo

This repository shows a platform-wide asynchronous eventing pattern. A shared
Amazon EventBridge event bus receives domain events. Amazon SQS delivers those
events to a consumer workload.

The Platform Team owns this repository. One pipeline applies every stack across
three AWS accounts. A product team changes its own eventing setup by opening a
pull request here.

**Application producers and consumers are intentionally omitted.** The
repository contains no Lambda function, no container and no event payload
handling. Use the AWS CLI commands in [Manual test](#manual-test) to verify the
infrastructure.

The original requirements are in
[`docs/aws-eventbridge-sqs-terraform-demo-spec.md`](docs/aws-eventbridge-sqs-terraform-demo-spec.md).
This repository deviates from section 3 of that document. See
[Deviations from the specification](#deviations-from-the-specification).

## How a product team makes a change

1. The team edits its own stack under `terraform/stacks/producers/` or
   `terraform/stacks/consumers/`.
2. The team opens a pull request.
3. `scope-check` confirms that the pull request touches one product stack and no
   shared code.
4. `terraform` plans every stack and posts the result.
5. The Platform Team reviews and merges. `CODEOWNERS` requires that approval.
6. The pipeline applies the stacks on `main`.

A product stack is a provider block, a module block and its outputs. A routine
change edits the event pattern and nothing else. Review stays a reading task,
not an audit of arbitrary Terraform.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│ Platform Account                                     │
│ Platform Team                                        │
│                                                      │
│   Shared EventBridge Event Bus                       │
│   + Event Bus Resource Policy                        │
│   + Consumer EventBridge Rule + Execution Role       │
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
The consumer stack therefore spans two accounts. The `event-consumer` module
uses two provider configurations for this reason.

## Account mapping

| Account           | Owner          | Purpose                         | Resources in this demo                                              |
|-------------------|----------------|---------------------------------|---------------------------------------------------------------------|
| Platform          | Platform Team  | Shared eventing foundation      | Event bus, resource policy, consumer EventBridge rule and target    |
| Sender workload   | Product Team A | Publishes domain events         | IAM policy and optional demo role for `events:PutEvents`            |
| Receiver workload | Product Team B | Receives selected domain events | SQS queue, dead-letter queue, redrive configuration, queue policy   |

## Repository layout

```
.github/
├── CODEOWNERS                          who must approve which path
└── workflows/
    ├── terraform.yml                   plan on pull request, apply on main
    └── scope-check.yml                 one product stack per pull request
terraform/
├── modules/                            Platform Team only
│   ├── event-platform/                 shared event bus and its resource policy
│   ├── event-producer/                 permission to publish to the shared bus
│   └── event-consumer/                 subscription, rule, target, queues
└── stacks/
    ├── platform/                       Platform Team
    ├── producers/
    │   └── order-service/              Product Team A
    └── consumers/
        └── fulfillment-service/        Product Team B
```

Each stack is a separate state boundary. The repository is shared, the state is
not. A product stack apply cannot damage the shared event bus.

## Stack ownership

| Stack                                       | Owner          | Modules used                                 | Deploys into                           |
|---------------------------------------------|----------------|----------------------------------------------|----------------------------------------|
| `stacks/platform`                           | Platform Team  | `event-platform`                             | Platform account                       |
| `stacks/producers/order-service`            | Product Team A | `event-producer`                             | Sender workload account                |
| `stacks/consumers/fulfillment-service`      | Product Team B | `event-consumer`                             | Platform and receiver workload account |

Stacks are named after the service that owns them, not after the AWS account
they target. One account can hold many stacks, and `fulfillment-service`
deploys into two accounts.

## Contracts between the stacks

The stacks do not read each other's state. They resolve the shared event bus by
name with `data.aws_cloudwatch_event_bus`. The default name is `async-demo`.

A name is the interface. No stack copies an ARN from another stack's output, and
no stack reads a remote state file. The lookup fails clearly when the platform
stack has not run yet.

## Prerequisites

- Terraform 1.6 or later.
- AWS provider 6.x. Terraform downloads it during `terraform init`.
- Three AWS accounts, or three sets of credentials that map to them.
- An S3 bucket for the Terraform state. The pipeline supplies it through
  `-backend-config`.
- One pipeline role with OIDC trust to this repository. Each stack role trusts
  that pipeline role.
- All three accounts use the same region. EventBridge sends events to
  cross-account targets in the same region only.

## Pipeline

The pipeline holds base credentials only. Each stack assumes its own role
through the `assume_role` block in its `providers.tf`.

| Stack                  | Assumes                                          | In account        |
|------------------------|--------------------------------------------------|-------------------|
| `platform`             | `PLATFORM_DEPLOY_ROLE_ARN`                       | Platform          |
| `order-service`        | `ORDER_SERVICE_DEPLOY_ROLE_ARN`                  | Sender workload   |
| `order-service`        | `PLATFORM_DEPLOY_ROLE_ARN`                       | Platform          |
| `fulfillment-service`  | `FULFILLMENT_SERVICE_DEPLOY_ROLE_ARN`            | Receiver workload |
| `fulfillment-service`  | `PLATFORM_DEPLOY_ROLE_ARN`                       | Platform          |

The platform account uses one administrative role. Every stack that touches that
account assumes it. Splitting it into a scoped role per stack is a later
improvement, recorded in [`docs/concept.md`](docs/concept.md).

The platform job runs first, because the product stacks resolve the event bus
that it publishes.

Configure these GitHub repository variables:

```
AWS_REGION
TF_STATE_BUCKET
PIPELINE_ROLE_ARN
PLATFORM_DEPLOY_ROLE_ARN
SENDER_ACCOUNT_ID
ORDER_SERVICE_DEPLOY_ROLE_ARN
FULFILLMENT_SERVICE_DEPLOY_ROLE_ARN
```

## Running a stack locally

Local apply is not the normal path. The pipeline applies every stack. To
inspect a plan, copy `terraform.tfvars.example` to `terraform.tfvars`, then:

```bash
cd terraform/stacks/platform
terraform init -backend=false
terraform plan
```

Your local credentials must be able to assume the role in `deploy_role_arn`.

## Event contract

The demo routes one example event. No code emits or processes it.

```json
{
  "source": "com.example.orders",
  "detail-type": "OrderCreated",
  "detail": { "orderId": "123" }
}
```

The consumer subscribes with this event pattern:

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
  --queue-url "<queue_url output of the fulfillment-service stack>" \
  --max-number-of-messages 1
```

## Permission model

### Runtime

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

### Deploy time

The pipeline holds credentials for all three accounts. The account boundary is
therefore no longer the control it was in a federated setup.

The demo uses one administrative role in the platform account. Every stack that
touches that account assumes it, including the consumer stack that creates the
EventBridge rule and its execution role.

This is deliberate for a first version. Least privilege at deploy time is a
separate improvement, recorded in [`docs/concept.md`](docs/concept.md). Two
things that code review does not cover motivate it.

1. **A stack overwriting the bus resource policy.** `aws_cloudwatch_event_bus_policy`
   is last-write-wins, and the policy lives in the platform stack state. If
   another stack replaces it, Terraform gives no warning and every other
   producer loses access.
2. **A compromised pipeline.** Review gates the code in this repository. It does
   not gate the actions, the providers or the Terraform binary that the runner
   executes.

## Verification

```bash
terraform fmt -check -recursive terraform/
```

Run `terraform validate` in each stack after `terraform init`.

The pipeline runs both checks for every stack on every pull request.

## Deviations from the specification

Section 3 of the specification defines `terraform/examples/` with three roots
named after the AWS accounts, and section 6 hands the event bus ARN between them
by hand. This repository uses one central repository with one pipeline.

| Specification                        | This repository                             |
|--------------------------------------|---------------------------------------------|
| `examples/platform-account`          | `stacks/platform`                           |
| `examples/sender-workload-account`   | `stacks/producers/order-service`            |
| `examples/receiver-workload-account` | `stacks/consumers/fulfillment-service`      |
| Event bus ARN copied into `tfvars`   | Event bus resolved by name with a data source |

### Why the stacks carry service names

- An AWS account is a deployment target, not an identity. Account names bind a
  stack to exactly one account. One account can hold many services.
- The consumer stack deploys into two accounts. It creates the EventBridge rule
  in the platform account and the queues in the receiver workload account. An
  account name cannot describe it correctly.
- Ownership follows the team and the service. Account names hide the owner.

The README states the target account for each stack, so the account boundary
stays visible.

### Why the directory is stacks, not examples

By Terraform convention, `examples/` holds sample usage of the modules beside
them. These roots are not samples. They are the deployable units that the
pipeline applies. `stacks/` states that.

### Why the consumer is a domain service

The consumer is `fulfillment-service`, a domain service that reacts to
`OrderCreated`. A technical name such as `persistence-service` implies that the
service stores all events. That contradicts the demo, which shows content-based
routing on one `detail-type`.

The subscription resources also carry the name of the consuming service, for
example `fulfillment-service-order-created`. Several services can subscribe to
the same event without a name collision.

### What the central model costs

In a federated model, each team applies its own stack with its own credentials.
A product team cannot reach the platform account at all. That control is strong,
and the central model gives it up: one pipeline holds credentials for all three
accounts.

Three controls replace it.

1. `CODEOWNERS` requires Platform Team approval on every pull request.
2. `scope-check` blocks a pull request that mixes a product stack with shared
   code.
Both are process controls. Neither holds when the runner itself is the problem.
A scoped deploy role would, and that is the recorded next step.

## Known demo limitations

These points are out of scope for the demo. A production setup must address
them.

- Every pull request needs a human review. That puts the Platform Team on the
  critical path of every product change, which is the bottleneck that a platform
  is meant to remove. The next step is a policy check that auto-approves a
  routine subscription, and reserves review for a new producer, a cross-domain
  subscription, or a pattern without a `detail-type` filter.
- Product teams write Terraform. At around ten subscriptions, replace the stack
  directories with a declarative manifest per team, and expand it with
  `for_each`. Review then compares event patterns instead of HCL. The stacks are
  deliberately uniform so that this step stays mechanical.
- The platform account uses one administrative deploy role. A consumer stack can
  therefore do anything in the platform account at apply time. See
  [`docs/concept.md`](docs/concept.md) for the intended next step.
- The execution role trust policy has no `aws:SourceArn` or `aws:SourceAccount`
  condition. It follows the AWS documentation example. Add a condition after you
  verify it against the EventBridge behaviour in your accounts.
- The queues use SQS-managed encryption defaults. There is no customer-managed
  KMS key, and therefore no cross-account key policy.
- The pipeline applies without a manual gate. Add a GitHub environment approval
  for the platform stack.
- There is no schema registry, no event catalog and no event versioning.
- There is no multi-region setup, no disaster recovery and no alarming.
- The optional demo role in the sender account is a convenience for manual
  tests. A real workload attaches the IAM policy to its own runtime role.
  Set `create_demo_role = false` for that case.
