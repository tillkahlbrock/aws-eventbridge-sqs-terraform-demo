**AWS EventBridge + SQS**

**Terraform Demo Implementation Specification**

*Implementation brief for an AI coding agent*

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>Goal</strong></p>
<p>Implement a Terraform-only demo of a platform-wide asynchronous
eventing pattern using a shared Amazon EventBridge event bus and Amazon
SQS for consumer delivery. The demo must make ownership boundaries
between the Platform Team and Product Teams explicit across three AWS
accounts.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

| **Scope**            | Terraform only                                                                     |
|----------------------|------------------------------------------------------------------------------------|
| **AWS accounts**     | 1 shared platform account, 1 sender workload account, 1 receiver workload account  |
| **Primary services** | Amazon EventBridge, Amazon SQS, IAM                                                |
| **Out of scope**     | Producer application, consumer application, event payload generation or processing |

# 1. Objective and Scope

Create a small, understandable Terraform demo that proves cross-account
asynchronous communication through a centrally provided EventBridge
event bus. The implementation should emphasize module consumers and
ownership boundaries rather than production completeness.

- Platform Team owns and deploys the shared EventBridge base
  infrastructure in a dedicated platform account.

- A sender Product Team deploys producer-side IAM infrastructure in a
  sender workload account.

- A receiver Product Team deploys consumer-side subscription and SQS
  infrastructure spanning the platform account and receiver workload
  account.

- No application code is required. Terraform outputs and optional AWS
  CLI commands may be documented for manual verification, but must not
  be implemented as producer or consumer services.

## Non-goals

- Production-grade organizational onboarding, self-service portals, or
  account vending.

- Schema registry, event catalog, schema compatibility enforcement, or
  event versioning workflows.

- Multi-region failover, disaster recovery, encryption-key lifecycle
  management, or advanced observability.

- Application deployment, Lambda functions, ECS services, or
  long-running producer/consumer processes.

- A generic enterprise module supporting every EventBridge or SQS
  feature.

# 2. Target Architecture

Use three separate AWS accounts. Account IDs must be configurable and
must never be hard-coded in reusable modules.

┌──────────────────────────────────────────────────────┐  
│ Platform Account │  
│ Platform Team │  
│ │  
│ Shared EventBridge Event Bus │  
│ + Event Bus Resource Policy │  
│ + Receiver-owned EventBridge Rule + IAM Role │  
└───────────────▲───────────────────────┬──────────────┘  
│ PutEvents │ rule target  
│ │  
┌───────────────┴──────────────┐ ┌────▼─────────────────────────┐  
│ Sender Workload Account │ │ Receiver Workload Account │  
│ Product Team A │ │ Product Team B │  
│ │ │ │  
│ Producer IAM Policy / Role │ │ SQS Queue + DLQ │  
│ (application not included) │ │ Queue Policy │  
└──────────────────────────────┘ │ (consumer not included) │  
└──────────────────────────────┘

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>Important EventBridge constraint</strong></p>
<p>An EventBridge rule belongs to the same account and event bus on
which it is created. Therefore, the consumer module in this demo must
use two AWS provider contexts: one for the platform account to create
the EventBridge rule/target, and one for the receiver workload account
to create the SQS queue, DLQ, and queue policy.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## Account responsibilities

| **Account**       | **Owner**      | **Purpose**                     | **Demo resources**                                                  |
|-------------------|----------------|---------------------------------|---------------------------------------------------------------------|
| Platform          | Platform Team  | Shared eventing foundation      | Custom event bus, resource policy, consumer EventBridge rule/target |
| Sender workload   | Product Team A | Publishes domain events         | IAM policy / optional demo role for events:PutEvents                |
| Receiver workload | Product Team B | Receives selected domain events | SQS queue, DLQ, redrive configuration, queue policy                 |

# 3. Repository Structure

Implement reusable modules separately from deployable demo root modules.
Each root represents a different Terraform user and state boundary.

terraform/  
├── modules/  
│ ├── event-platform/  
│ │ ├── main.tf  
│ │ ├── variables.tf  
│ │ ├── outputs.tf  
│ │ └── versions.tf  
│ ├── event-producer/  
│ │ ├── main.tf  
│ │ ├── variables.tf  
│ │ ├── outputs.tf  
│ │ └── versions.tf  
│ └── event-consumer/  
│ ├── main.tf  
│ ├── variables.tf  
│ ├── outputs.tf  
│ └── versions.tf  
└── examples/  
├── platform-account/  
│ ├── main.tf  
│ ├── providers.tf  
│ ├── variables.tf  
│ └── terraform.tfvars.example  
├── sender-workload-account/  
│ ├── main.tf  
│ ├── providers.tf  
│ ├── variables.tf  
│ └── terraform.tfvars.example  
└── receiver-workload-account/  
├── main.tf  
├── providers.tf  
├── variables.tf  
└── terraform.tfvars.example

Do not use Terraform remote-state references between the three example
roots. Pass shared identifiers such as the event bus ARN explicitly as
variables. This keeps the ownership and deployment boundaries visible in
the demo.

# 4. Terraform Modules

## 4.1 event-platform

Consumer: Platform Team. Deployment account: platform account.
Responsibility: create the shared EventBridge foundation and authorize
explicitly configured workload accounts to publish events.

### Required resources

- aws_cloudwatch_event_bus — one custom shared event bus.

- aws_cloudwatch_event_bus_policy — allow events:PutEvents from the
  configured sender workload account(s). Prefer a narrow resource-based
  policy scoped to the bus.

### Suggested inputs

- name: event bus name.

- allowed_producer_account_ids: set(string) containing workload account
  IDs allowed to publish.

- tags: map(string), default {}.

### Required outputs

- event_bus_name

- event_bus_arn

## 4.2 event-producer

Consumer: sender Product Team. Deployment account: sender workload
account. Responsibility: grant a workload identity permission to publish
to the shared platform event bus. No event bus is created in this
account.

### Required resources

- aws_iam_policy granting events:PutEvents only on the supplied shared
  event bus ARN.

- For demo convenience, optionally create an assumable IAM role and
  attach the policy. If implemented, make role creation configurable so
  the module can later be attached to an existing runtime role instead.

### Suggested inputs

- event_bus_arn: ARN exported by the platform deployment.

- policy_name: IAM policy name.

- create_demo_role: bool, default true for the demo.

- demo_role_name: optional role name.

- tags: map(string), default {}.

### Required outputs

- iam_policy_arn

- demo_role_arn (when the optional role is created)

## 4.3 event-consumer

Consumer: receiver Product Team. Deployment accounts: platform account
and receiver workload account. Responsibility: define which domain
events the team subscribes to and deliver matching events to a
workload-local SQS queue.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th><p><strong>Provider requirement</strong></p>
<p>The module must declare two provider configurations using
configuration_aliases, for example aws.platform and aws.receiver. The
root module supplies the respective provider aliases. Do not configure
credentials, regions, or assume-role behavior inside the reusable
module.</p></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

### Required resources

- aws_sqs_queue (receiver provider) — consumer queue.

- aws_sqs_queue (receiver provider) — dead-letter queue.

- Redrive policy on the consumer queue pointing to the DLQ.

- aws_iam_role (platform provider) — execution role assumable by
  events.amazonaws.com for cross-account target delivery.

- aws_iam_role_policy or aws_iam_policy (platform provider) — grant the
  execution role sqs:SendMessage on the receiver queue ARN only.

- aws_sqs_queue_policy (receiver provider) — allow the platform-side
  execution role (or, if necessary for compatibility, the platform
  account) to send messages to the queue. Keep the principal and
  resource as narrow as practical.

- aws_cloudwatch_event_rule (platform provider) — attached to the shared
  event bus and configured with a domain-specific event_pattern.

- aws_cloudwatch_event_target (platform provider) — target the
  cross-account SQS queue ARN and set role_arn to the platform-side
  EventBridge execution role.

### Suggested inputs

- event_bus_name: shared event bus name.

- event_bus_arn: shared event bus ARN, useful for policy construction
  and validation.

- subscription_name: stable name for the EventBridge rule.

- event_pattern: object/map or JSON string defining the subscription
  filter.

- queue_name: receiver queue name.

- dlq_name: dead-letter queue name.

- max_receive_count: number, default 5.

- message_retention_seconds: number with a reasonable demo default.

- eventbridge_execution_role_name: optional name for the platform-side
  target execution role.

- tags: map(string), default {}.

### Required outputs

- queue_url

- queue_arn

- dlq_arn

- event_rule_arn

- event_rule_name

- eventbridge_execution_role_arn

# 5. Demo Event Contract and Subscription

Use a minimal example event contract only to configure routing. No code
should emit or consume the event as part of the implementation.

{  
"source": "com.example.orders",  
"detail-type": "OrderCreated",  
"detail": {  
"orderId": "123"  
}  
}

The receiver subscription should demonstrate content-based routing with
an EventBridge event pattern similar to:

{  
"source": \["com.example.orders"\],  
"detail-type": \["OrderCreated"\]  
}

# 6. Provider and Deployment Model

The demo should make account boundaries explicit by using independent
example roots. Assume authentication is supplied externally via AWS
profiles, environment variables, or role assumption configured in the
root providers.

## Platform root

- Uses a provider authenticated to the platform account.

- Instantiates event-platform.

- Receives the sender workload account ID as configuration.

- Outputs the event bus name and ARN for manual hand-off to Product
  Teams.

## Sender root

- Uses a provider authenticated to the sender workload account.

- Instantiates event-producer with the shared event bus ARN copied from
  the platform deployment output.

## Receiver root

- Defines two provider aliases: one authenticated to the platform
  account and one to the receiver workload account.

- Instantiates event-consumer and passes both providers explicitly via
  the module providers map.

- Passes the shared event bus name/ARN and the domain-specific event
  pattern.

module "order_events_consumer" {  
source = "../../modules/event-consumer"  
  
providers = {  
aws.platform = aws.platform  
aws.receiver = aws.receiver  
}  
  
event_bus_name = var.event_bus_name  
event_bus_arn = var.event_bus_arn  
subscription_name = "order-created-demo"  
queue_name = "order-created-demo"  
dlq_name = "order-created-demo-dlq"  
  
event_pattern = {  
source = \["com.example.orders"\]  
"detail-type" = \["OrderCreated"\]  
}  
}

# 7. IAM and Cross-Account Permissions

Keep permissions intentionally narrow so the demo demonstrates the
security model rather than relying on administrator-wide access inside
resource policies.

**Sender → platform bus:** The platform event bus resource policy
authorizes the sender workload account to call events:PutEvents on that
bus. The producer-side IAM policy independently authorizes the sender
workload identity to call events:PutEvents on the same ARN. Both sides
must permit the action.

**Platform EventBridge → receiver SQS:** For a cross-account AWS-service
target, create an EventBridge execution role in the platform account.
EventBridge assumes this role; its identity policy grants
sqs:SendMessage on the receiver queue. The receiver queue resource
policy must also trust the platform-side execution role (or platform
account, if required by the chosen policy form). Configure the target
with role_arn.

**Terraform execution roles:** Out of scope for reusable modules.
Example roots may assume pre-existing deployment roles. Do not create
broad cross-account administrator roles solely for the demo unless
required by the local execution environment.

# 8. Naming and Tags

Use simple deterministic names suitable for a demo. Avoid introducing a
large naming framework.

- Use a common prefix such as async-demo or event-demo.

- Expose names as variables when they are useful to distinguish module
  instances.

- Apply at least these tags where the AWS resource supports tagging:
  ManagedBy=Terraform, Environment=demo,
  Component=\<platform\|producer\|consumer\>.

- Do not encode AWS account IDs into resource names unless required.

# 9. Terraform Quality Requirements

- Use Terraform \>= 1.6 unless the repository already standardizes on
  another supported version.

- Pin the AWS provider to a compatible major-version range rather than
  an exact patch version.

- Every module must contain descriptions for variables and outputs.

- Use validation blocks for account IDs or other constrained values
  where it adds clarity without overengineering.

- Use jsonencode for EventBridge event patterns and IAM policies where
  practical.

- Avoid null_resource, local-exec, provisioners, shell scripts, and
  application code.

- Run terraform fmt -recursive and terraform validate for each example
  root.

- Keep module interfaces small and demo-focused.

# 10. Deployment Order

1.  Deploy examples/platform-account. Record event_bus_name and
    event_bus_arn.

2.  Deploy examples/sender-workload-account using the platform event bus
    ARN.

3.  Deploy examples/receiver-workload-account using both platform and
    receiver provider contexts plus the platform event bus outputs.

4.  Optionally verify the infrastructure manually with AWS CLI: publish
    one matching test event and inspect the receiver SQS queue. This
    verification command may be documented in a README but must not be
    part of Terraform resources or application code.

# 11. Acceptance Criteria

- The repository contains the three reusable modules and three clearly
  separated example roots described above.

- The shared custom EventBridge event bus exists only in the platform
  account.

- The sender workload account has an IAM identity/policy capable of
  publishing only to the configured shared event bus.

- The platform event bus resource policy authorizes the configured
  sender account to publish.

- The receiver workload account contains a standard SQS queue and a DLQ
  with redrive configuration.

- A domain-specific EventBridge rule exists in the platform account on
  the shared bus and targets the receiver-account SQS queue.

- A platform-account EventBridge execution role exists, trusts
  events.amazonaws.com, and can send only to the configured receiver
  queue.

- The SQS queue policy permits the platform-side execution identity to
  send to the queue and is scoped as narrowly as practical.

- No producer or consumer application is implemented.

- No module contains embedded AWS credentials or assumes a fixed account
  ID.

- terraform fmt -check and terraform validate succeed for all example
  roots after required variables are supplied.

- The README or example comments explain which team owns and deploys
  each root and which account it targets.

# 12. Expected AI Agent Deliverable

The coding agent should produce a self-contained Terraform demo
repository matching this specification. The final repository should
include a short README that explains the architecture, prerequisites,
account mapping, deployment order, module ownership, and a manual
test-event command. The README should explicitly state that application
producers and consumers are intentionally omitted.
