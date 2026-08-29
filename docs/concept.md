# Concept for an asynchronous service-to-service communication solution

## Todos

- [] Implement the basic infra
- [] Implement the module to be used by the teams
- [] Implement client code for publishing and consuming messages
- [] Implement message schema + tooling
- [] Finish this concept

## Introduction

This document has two main sections: 
1. The infrastructure components for the messaging system
2. The definition of how to structure messages, so they can be consistently send and consumed

## Environment

- One platform team (1 manager, 4 engineers) will be owning this solution
- Build on-top of AWS
- Will be used by currently 12 product teams and 20+ services

### Status quo

- Teams have different approaches to asynchronous communication (queues, cron, custom workers)
- No standard for events, retries, error handling, or monitoring 
- Unclear ownership of messages/events 
- Operational issues (lost messages, difficult debugging)
- No clear golden path (leads to bad DevEx)

## Solution

### Architecture decisions

- EventBridge as message bus in central platform account
- SQS in target accounts (where the consuming service lives)
- shared terraform module for product teams, to start consuming messages
- use dead-letter queues with SQS for redriving messages (needs more description)
- undecided: what's needed for teams to produce messages?
- undecided: how to handle command-based communication?
- undecided: how to define and store message schemas?
- use custom envelope (needs tooling to consistently read and write metadata)

### Alternatives considered

- SNS + SQS (simpler / easier to understand then EventBridge; routing get complicated / messy as the platform grows)
- Kafka (good persistence features; too much complexity for too little gain)

### Envelope

- Use custom envelope as described in https://theburningmonk.com/2024/11/eventbridge-best-practice-why-you-should-wrap-events-in-event-envelopes/
- Makes it much easier to process messages with same tooling delivered over different services (EventBridge, SQS, SNS, Kinesis)
- Ship a library (or something similar) to create envelope consistently
- We use our own ID (do not rely on EventBridge id), because
  - makes tracing events easier (we might want to have a dedicated correlation id for that)
  - idempotency: makes it easy to deduplicate events (it's possible to get the same event with different EB ids twice (DLQ, SDK retry))
- Use versioning to make sure, fields can be parsed
- Fields to use (at least)
  - id: This is the unique ID for the event. 
  - version 
  - timestamp: When you published the event, not when EventBridge received it. 
  - domain: Not to be confused with “service”. A domain represents a problem space that your system is supposed to address. Within a domain, you might have many services working together to solve the problem. 
  - service: name of the service producing this event 
  - type: Event type.
- Alternative (rejected): Just use default AWS-service envelope

### Schema

Possible solutions
- Protobuf + Github (MOIA)
- Something else + Github
- EventBridge Schema Registry + TypeScript library (Envelope, domain specific events)

### Ideas for improvement / evolution

- An abstraction, so that product teams do not need to write terraform code. Maybe even self-service via chatbot or the like.
- Protobuf or similar for event serialization and client code generation
- Securing the platform resources in the workload accounts (tags + SCP)
- Least privilege at deploy time: replace the single admin role in the platform account with a scoped role per stack (limits a compromised pipeline, stops a stack from overwriting the last-write-wins bus resource policy)
- A ready-to-assume publish role for producers, if manual testing becomes frequent (today the module only creates the IAM policy)