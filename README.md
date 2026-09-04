# AWS EventBridge + SQS — Prototyp

Prototyp einer plattformweiten Lösung für asynchrone Kommunikation zwischen
Services: ein geteilter EventBridge Bus im Plattform-Account, je Consumer eine
SQS Queue mit Dead-Letter-Queue im Workload-Account und eine zweite
Dead-Letter-Queue an der Rule im Plattform-Account, alles in Terraform, dazu
ein kleines Paket für den Event-Envelope und je ein Beispiel für Producer und
Consumer.

**Das Konzept dahinter** — Architekturentscheidungen, Trade-offs, Golden Path,
Betrieb und offene Punkte — steht in
[`docs/async-communication-concept.md`](docs/async-communication-concept.md).

Aufsetzen, deployen und testen: [`docs/RUNBOOK.md`](docs/RUNBOOK.md).
