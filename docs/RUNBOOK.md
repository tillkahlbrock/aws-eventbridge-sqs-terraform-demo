# Runbook

How to bootstrap, deploy and test the prototype. The concept behind it is in
[`async-communication-concept.md`](async-communication-concept.md).

## Prerequisites

- Terraform 1.6 or later.
- AWS provider 6.x. Terraform downloads it during `terraform init`.
- Three AWS accounts, or three sets of credentials that map to them.
- Administrative credentials for the platform and fulfillment-service accounts, once, to
  run [Bootstrap](#bootstrap).
- All three accounts use the same region. EventBridge sends events to
  cross-account targets in the same region only.

## Bootstrap

`terraform/bootstrap` creates what the pipeline needs before it can run:

- the S3 bucket for the Terraform state;
- the GitHub OIDC provider and the pipeline role in the platform account;
- one administrative deploy role in the platform account and one in the
  fulfillment-service account, both trusted by the pipeline role.

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
| `fulfillment-service`  | `FULFILLMENT_SERVICE_DEPLOY_ROLE_ARN`            | Fulfillment       |
| `fulfillment-service`  | `PLATFORM_DEPLOY_ROLE_ARN`                       | Platform          |

The platform account uses one administrative role. Every stack that touches that
account assumes it. Splitting it into a scoped role per stack is a later
improvement, recorded in [`concept.md`](concept.md).

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

## Sample applications

Two Node.js samples in `apps/`, one per team. Both use `@platform/events` from
`packages/events`, which owns the event envelope. Copy them as a template.

The envelope carries `id`, `version`, `timestamp`, `domain`, `service`, `type`
and `correlationId` around the payload. The library derives the two mandatory
EventBridge fields from it, so envelope and routing cannot drift:

```
Source     = <prefix>.<domain>      com.example.orders
DetailType = <type>                 OrderCreated
Detail     = { ...envelope, payload }
```

Each app declares the events that it owns in its own `src/events.ts`. The
producer owns the schema of `OrderCreated`. The consumer declares only the
fields that it reads, so a new field in the payload does not break it.

The package is wired as a `file:` dependency. There is no registry and no build
step: `tsx` reads the TypeScript source through the link. A private registry is
the next step, not this one.

Both read their AWS credentials from the environment, so `AWS_PROFILE` works.
The identity you use needs `events:PutEvents` on the bus, or
`sqs:ReceiveMessage` and `sqs:DeleteMessage` on the queue. This repository does
not grant either. See [Why there is no producer stack](async-communication-concept.md).

### Producer

Publish an event. The order id is optional.

```bash
cd apps/order-service
npm install
export AWS_REGION=eu-central-1
export EVENT_BUS_ARN="<event_bus_arn output of the platform stack>"
npm start -- ORD-1001
```

`--correlation-id=REQ-42` starts the chain at an upstream request instead of at
the event. Without it the library assigns a new correlation id.

### Consumer

Start the consumer. It long-polls until you press Ctrl-C.

```bash
cd apps/fulfillment-service
npm install
export AWS_REGION=eu-central-1
export QUEUE_URL="<queue_url output of the fulfillment-service stack>"
export EVENT_BUS_ARN="<event_bus_arn output of the platform stack>"
npm start
```

The consumer needs the bus, because it publishes a follow-up event. It stops at
once when one of the two variables is missing.

For each message the consumer does five things. Each one uses a field of the
envelope:

1. It parses the body. A body that it cannot read stays in the queue and goes
   to the dead-letter queue after `maxReceiveCount`. A retry cannot repair it.
2. It compares `version` before it reads the payload. An unsupported version
   also stays for the dead-letter queue.
3. It skips an `id` that it processed before. The envelope id differs from the
   EventBridge id, and it survives a replay or an SDK retry. That is what a
   consumer deduplicates on. The sample holds these ids in memory. In
   production a DynamoDB table with a TTL holds them.
4. It publishes `ShipmentPrepared` with the `correlationId` of the order event.
   The chain now spans two services and two domains, and one query finds both
   events.
5. It deletes the message.

A consumer is normally a producer as well. This one publishes into the
`fulfillment` domain. The platform account must therefore list the account of
the consumer in `terraform/stacks/platform/producers.tf`. Until that entry
exists, `PutEvents` is refused. The order event then stays in the queue and
goes to the dead-letter queue after `maxReceiveCount`.

## Manual test

These commands are documentation only. They are not part of the Terraform
configuration.

Publish one test event from the sender workload account. The identity you use
needs `events:PutEvents` on the bus. This repository does not grant it, so use a
principal that already has it. Use the event bus ARN, because `PutEvents`
targets a bus in another account.

```bash
aws events put-events \
  --profile order-service-account \
  --region eu-central-1 \
  --entries '[{
    "Source": "com.example.orders",
    "DetailType": "OrderCreated",
    "Detail": "{\"orderId\":\"123\"}",
    "EventBusName": "arn:aws:events:eu-central-1:222222222222:event-bus/async-demo"
  }]'
```

The response must report `"FailedEntryCount": 0`.

Read the event from the consumer queue in the fulfillment-service account.

```bash
aws sqs receive-message \
  --profile fulfillment-service-account \
  --region eu-central-1 \
  --queue-url "<queue_url output of the fulfillment-service stack>" \
  --max-number-of-messages 1
```

## Verification

```bash
terraform fmt -check -recursive terraform/
```

Run `terraform validate` in each stack after `terraform init`.

The pipeline runs both checks for every root on every pull request. The
plan and apply jobs are skipped until `PIPELINE_ROLE_ARN` is set.
