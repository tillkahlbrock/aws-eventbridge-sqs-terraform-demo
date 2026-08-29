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

1. A consumer team edits its own stack under `terraform/stacks/consumers/`. A
   producer team adds one line to `terraform/stacks/platform/producers.tf`.
2. The team opens a pull request.
3. `terraform` formats, validates and plans every stack.
4. The Platform Team reviews and merges. `CODEOWNERS` requires that approval.
5. The pipeline applies the stacks on `main`.

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
│ Nothing deployed here.       │  │ SQS Queue + DLQ              │
│ The team owns its own IAM.   │  │ Queue Policy                 │
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
| Sender workload   | Product Team A | Publishes domain events         | None. The team grants its own service `events:PutEvents`.           |
| Receiver workload | Product Team B | Receives selected domain events | SQS queue, dead-letter queue, redrive configuration, queue policy   |

## Repository layout

```
.github/
├── CODEOWNERS                          who must approve which path
└── workflows/
    └── terraform.yml                   validate, plan on pull request, apply on main
terraform/
├── bootstrap/                          run once, by hand, local state
├── modules/                            Platform Team only
│   ├── event-platform/                 shared event bus and its resource policy
│   └── event-consumer/                 subscription, rule, target, queues
└── stacks/
    ├── platform/                       Platform Team
    │   └── producers.tf                producer registry, one line per team
    └── consumers/
        └── fulfillment-service/        Product Team B
```

Each stack is a separate state boundary. The repository is shared, the state is
not. A product stack apply cannot damage the shared event bus.

## Stack ownership

| Stack                                       | Owner          | Modules used                                 | Deploys into                           |
|---------------------------------------------|----------------|----------------------------------------------|----------------------------------------|
| `stacks/platform`                           | Platform Team  | `event-platform`                             | Platform account                       |
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
- Administrative credentials for the platform and receiver accounts, once, to
  run [Bootstrap](#bootstrap).
- All three accounts use the same region. EventBridge sends events to
  cross-account targets in the same region only.

## Bootstrap

`terraform/bootstrap` creates what the pipeline needs before it can run:

- the S3 bucket for the Terraform state;
- the GitHub OIDC provider and the pipeline role in the platform account;
- one administrative deploy role in the platform account and one in the receiver
  workload account, both trusted by the pipeline role.

Run it once, by hand, with administrative credentials for both accounts. It keeps
local state, because it creates the bucket that every other stack writes to.

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # then edit
terraform init
terraform apply
```

Copy the outputs into the repository variables listed under
[Pipeline](#pipeline). If `state_bucket_name` is not the default, update the
`backend` block in each stack to match.

Set `create_github_oidc_provider = false` when the platform account already has
a GitHub OIDC provider. An account can only have one.

`github_subject_patterns` must match the `sub` claim that GitHub actually sends.
GitHub uses numeric ids, `repo:<owner>@<owner-id>/<name>@<repo-id>:*`, not
`repo:<owner>/<name>:*`. Read the ids with:

```bash
gh api repos/OWNER/NAME --jq '.owner.id, .id'
```

If the pipeline fails with `Not authorized to perform sts:AssumeRoleWithWebIdentity`,
look up the rejected claim in CloudTrail under `AssumeRoleWithWebIdentity`.

In production these roles would come from an account provisioning mechanism, not
from this repository.

## Pipeline

The pipeline holds base credentials only. Each stack assumes its own role
through the `assume_role` block in its `providers.tf`.

| Stack                  | Assumes                                          | In account        |
|------------------------|--------------------------------------------------|-------------------|
| `platform`             | `PLATFORM_DEPLOY_ROLE_ARN`                       | Platform          |
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
PIPELINE_ROLE_ARN
PLATFORM_DEPLOY_ROLE_ARN
FULFILLMENT_SERVICE_DEPLOY_ROLE_ARN
```

Producer accounts are **not** configured here. They live in
`terraform/stacks/platform/producers.tf`, so that authorizing a producer appears
in a diff.

## Running a stack locally

Local apply is not the normal path. The pipeline applies every stack. To
inspect a plan, copy `terraform.tfvars.example` to `terraform.tfvars`, then:

```bash
cd terraform/stacks/platform
terraform init
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

Publish one test event from the sender workload account. The identity you use
needs `events:PutEvents` on the bus. This repository does not grant it, so use a
principal that already has it. Use the event bus ARN, because `PutEvents`
targets a bus in another account.

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

1. The event bus resource policy allows `events:PutEvents` from each registered
   producer account. The Platform Team owns this side.
2. An identity policy in that account allows `events:PutEvents` on the bus ARN.
   The product team owns this side, and this repository does not create it.

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

The pipeline runs both checks for every root on every pull request. The
plan and apply jobs are skipped until `PIPELINE_ROLE_ARN` is set.

## Deviations from the specification

Section 3 of the specification defines `terraform/examples/` with three roots
named after the AWS accounts, and section 6 hands the event bus ARN between them
by hand. This repository uses one central repository with one pipeline.

| Specification                        | This repository                             |
|--------------------------------------|---------------------------------------------|
| `examples/platform-account`          | `stacks/platform`                           |
| `examples/sender-workload-account`   | Removed. See below.                         |
| `examples/receiver-workload-account` | `stacks/consumers/fulfillment-service`      |
| Event bus ARN copied into `tfvars`   | Event bus resolved by name with a data source |

### Why there is no producer stack

The specification requires an IAM policy in the sender account
(section 4.2, and an acceptance criterion). This repository does not create one.

A team that publishes with the AWS SDK already knows it needs `events:PutEvents`.
A policy handed over by the platform enforces nothing, because the team can
attach any policy it likes. The platform side that does bind is the bus resource
policy, and the Platform Team owns that.

With the policy gone, the `event-producer` module and the producer stack held no
resources, so both were removed. A producer now registers by adding one line to
`terraform/stacks/platform/producers.tf`. That list cannot be split into
per-team stacks: there is one bus resource policy and it is last-write-wins.

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

`CODEOWNERS` replaces it: the Platform Team approves every pull request.

That is a process control. It does not hold when the runner itself is the
problem. A scoped deploy role per stack would, and that is the recorded next
step in [`docs/concept.md`](docs/concept.md).

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
- Nothing verifies that a registered producer account actually restricts
  `events:PutEvents` to one service. The bus resource policy trusts the whole
  account. An `aws:PrincipalArn` condition per producer would bind it.
- The queues use SQS-managed encryption defaults. There is no customer-managed
  KMS key, and therefore no cross-account key policy.
- The pipeline applies without a manual gate. Add a GitHub environment approval
  for the platform stack.
- There is no schema registry, no event catalog and no event versioning.
- There is no multi-region setup, no disaster recovery and no alarming.
