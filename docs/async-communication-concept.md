# Plattform für asynchrone Kommunikation

<!-- Ergebnis zur Aufgabe in docs/PlatformAufgabeE.pdf. Grenze: 6 Seiten. -->

## 1. Kontext, Ziel und Nicht-Ziele

Zwölf Produktteams, über zwanzig Services, je Team gewachsene Lösungen. Kein
Standard für Events, Retries und Fehlerbehandlung, unklare Ownership, verlorene
Messages.

Ziel ist ein Golden Path: veröffentlichen oder abonnieren soll ohne Transport,
Retries und Fehlerbehandlung selbst zu entwerfen möglich sein. Das Ziel ist erreicht, wenn 
- ein Abonnement ein nur durch einen Pull Request erstellt werden kann, 
- kein Fehler unentdeckt bleiben kann
- und das Plattformteam nicht der Flaschenhals ist.

**Was wir nicht bauen**, unabhängig vom Reifegrad:

- **Command-Bus.** Siehe 2.3. Punkt-zu-Punkt bekommt eine Queue.
- **IAM-Policies für Produkt-Identitäten.** Wer das SDK aufruft, kennt die
  nötige Berechtigung. Eine übergebene Policy erzwingt nichts.
- **Self-Service-Portal, Account Vending, Codegenerierung.** Jedes davon ist
  eigene Software mit eigenem Betrieb.
- **Event Sourcing.** Der Bus ist Transport, kein System of Record.
- **Multi-Region und Disaster Recovery.**

## 2. Architektur und Design

### 2.1 Zielarchitektur

![Zielarchitektur der Plattform für asynchrone Kommunikation](async-communication-architecture.png)

Eine Rule je Subscription filtert auf den Inhalt und stellt über eine Execution
Role in die Queue im Account des Consumers zu.

### 2.2 Auswahl der AWS Services und geprüfte Alternativen

**EventBridge** entscheidet das Routing: seine Rules filtern auf den Inhalt, ein
Producer erfährt nie, wer zuhört. **SQS** entscheidet die Zustellung: eine Queue
puffert Last, übersteht einen Ausfall des Consumers und trägt eine
Dead-Letter-Queue.

| Option | Verworfen, weil |
|---|---|
| SNS und SQS | Ein Topic je Event-Typ, also viele Topics und viele Resource Policies. Ein Producer wird je Topic freigeschaltet statt einmal für die Plattform. Kein Archive, kein Replay. Die Filterung ist kein Argument: SNS prüft mit `FilterPolicyScope = MessageBody` ebenfalls den Inhalt. |
| MSK oder Kafka | Starke Reihenfolge und Retention, aber zu viel Betrieb für ein Team von fünf Personen. |
| Queue je Service-Paar | Die Ausgangslage. Koppelt Producer an Consumer und verdeckt die Ownership. |

Zwei Einschränkungen folgen: keine garantierte Reihenfolge, und Zustellung
mindestens einmal. Consumer müssen idempotent sein, siehe 2.5.

### 2.3 Events und Commands

Diese Lösung unterstützt **Events** und ist kein Command-Bus.

Bei einem Event besitzt der Producer das Schema und kennt seine Consumer nicht.
Bei einem Command besitzt der Empfänger das Schema, und der Sender muss ihn
kennen — genau die Kopplung, die eventbasierte Kommunikation hier auflösen soll.

Für asynchrone Commands muss eine zweites System erstellt werden, das auf Punkt-zu-Punkt Kommunikation basiert. 
Dies ist nicht teil dieses Konzepts.
Dafür würden wir ein zusätzliches Modul erstelen mit SQS und Dead-Letter-Queue, ohne Bus und ohne Rules.
Die Events, die auf die Commands folgen, würden dann wieder die Event-Infrastruktur nutzen.

### 2.4 Event-Schema und Envelope

Jedes Event trägt einen Envelope um die fachliche Nutzlast:

| Feld | Zweck |
|---|---|
| `id` | Unsere eigene ID, nicht die von EventBridge. Für Tracing und Idempotenz. |
| `version` | Erlaubt eine Versionsprüfung vor dem Parsen. |
| `timestamp` | Wann der Producer veröffentlicht hat. |
| `domain` | Der Problemraum, zum Beispiel `orders`. |
| `service` | Der produzierende Service. |
| `type` | Der Event-Typ, zum Beispiel `OrderCreated`. |
| `correlationId` | Verbindet eine Kette über Servicegrenzen. |

Die eigene ID ist nötig, weil EventBridge bei Replay und SDK-Retry eine neue
vergibt: dasselbe Event käme zweimal mit zwei unterschiedlichen IDs an. Der Envelope ist zudem
transportunabhängig (SQS, SNS, Kinesis, ...).

`Source`, `DetailType` und `Detail` sind Pflichtfelder. Die Bibliothek leitet
sie aus dem Envelope ab, damit beide nicht auseinanderlaufen:

```
Source     = <Präfix>.<domain>      com.example.orders
DetailType = <type>                 OrderCreated
Detail     = { ...Envelope, payload }
```

`Source` und `DetailType` tragen die Identität eines Events, und genau darauf matchen die Rules. Zusätzliche Bedingungen dürfen auf `Detail` matchen, etwa auf einen Mandanten — sie ersetzen die Identität aber nicht.

### 2.5 Fehlerbehandlung: Retries, Dead-Letter-Queues, Idempotenz

Zwei unabhängige Fehlerfälle, jeder mit eigener Dead-Letter-Queue. Sie zu
verwechseln ist der häufigste Weg, ein Event zu verlieren.

**EventBridge kann nicht zustellen** — falsche Queue Policy, gedrosseltes
Target. EventBridge wiederholt 24 Stunden und bis zu 185-mal, danach verwirft es
das Event, außer das Target hat eine Dead-Letter-Queue. Diese gehört zur Rule
und liegt im Plattform-Account.

**Der Consumer kann nicht verarbeiten** — die Message kehrt nach dem Visibility
Timeout zurück und wandert nach `maxReceiveCount` Empfängen in die DLQ im
Account des Consumers.

Idempotenz ist Aufgabe des Consumers. Die Bibliothek legt die `id` offen, den
Speicher bringt sie nicht mit: nur der Service weiß, wie lange eine Wiederholung
folgenlos bleiben muss.

### 2.6 Zugang, Security und Isolation

An jeder Account-Grenze müssen beide Seiten zustimmen.

**Veröffentlichen.** Die Bus-Policy nennt den Producer-Account, und das Team
erlaubt seiner eigenen Identität `events:PutEvents` auf diese Bus-ARN.

**Zustellen.** EventBridge nimmt eine Execution Role im Plattform-Account an,
deren Policy `sqs:SendMessage` auf genau eine Queue erlaubt. Die Queue Policy im
Consumer-Account nennt diese Rolle als einzigen Absender.

**Identität eines Producers.** Die Bus-Policy erlaubt bisher einen ganzen
Account, damit kann jeder Principal dort unter fremder `Source` veröffentlichen.
`events:source` ist ein Condition Key für `PutEvents` und schließt die Lücke:

```json
"Condition": { "StringLike": { "events:source": "com.example.orders*" } }
```

Die Isolation folgt der Account-Grenze: die Queue liegt beim Consumer, ein
defekter Consumer trifft kein anderes Team. Der Bus ist die einzige geteilte
Komponente, und seine Konfiguration ändert nur das Plattformteam.

## 3. Terraform-Prototyp

Ein lauffähiges [Repository](https://github.com/tillkahlbrock/aws-eventbridge-sqs-terraform-demo), deployt, mit einem Event über den ganzen Weg.

```
terraform/
├── bootstrap/                  einmalig: State Bucket, Deploy Roles
├── modules/
│   ├── event-platform/         Bus und Resource Policy
│   └── event-consumer/         Subscription: Rule, Target, Queue, DLQ
└── stacks/
    ├── platform/               Plattformteam; producers.tf registriert Producer
    └── consumers/
        └── fulfillment-service/
packages/events/                der Envelope: publish() und parse()
apps/                           je ein Beispiel für Producer und Consumer
```

Ein Repository, im Besitz des Plattformteams; `CODEOWNERS` erzwingt die
Freigabe, eine Pipeline (Github Action) wendet an. Der State ist je Stack getrennt, damit ein
Produktteam die geteilte Infrastruktur nicht versehentlich beschädigen kann.

`event-consumer` setzt Redrive Policy, `maxReceiveCount`, Retention, Execution
Role und beide Resource Policies. Es deklariert zwei Provider-Aliase und
konfiguriert weder Credentials noch Region, funktioniert also für jeden
Consumer-Account. Den Bus lösen Stacks über seinen Namen auf, nicht über fremden
State.

## 4. Developer Experience und Golden Path

### 4.1 Der Pfad

Es gibt zwei Berührungspunkte mit der Plattform, beide sind ein Pull Request: ein Eintrag in
`producers.tf` zum Veröffentlichen, ein Stack-Verzeichnis zum Abonnieren.

**Veröffentlichen.** Einmalig trägt das Team seinen Account ein. Danach ohne
weitere Plattform-Beteiligung, für jedes weitere Event:

```ts
await publish({
  domain: "orders", service: "order-service",
  type: "OrderCreated", payload: { orderId },
});
```

Ein neuer Event-Typ braucht keinen Pull Request. Es muss nur einmalig das Senden der Events aus dem Quell-Account erlaubt werden. 

**Abonnieren.** Der ganze Inhalt eines Consumer-Stacks ist ein Modulblock:

```hcl
module "order_created_subscription" {
  source = "../../../modules/event-consumer"

  providers = {
    aws.platform = aws.platform
    aws.consumer = aws.fulfillment
  }

  event_bus_name    = data.aws_cloudwatch_event_bus.shared.name
  event_bus_arn     = data.aws_cloudwatch_event_bus.shared.arn
  subscription_name = "fulfillment-service-order-created"
  queue_name        = "fulfillment-service-order-created"
  dlq_name          = "fulfillment-service-order-created-dlq"

  event_pattern = {
    source        = ["com.example.orders"]
    "detail-type" = ["OrderCreated"]
  }
}
```

Der Consumer liest die Queue und bekommt den Envelope getypt zurück:

```ts
const envelope = parse<{ orderId: string }>(message.Body);
```

Eine spätere Änderung ist ein Ein-Zeilen-Diff am `event_pattern`. Genau das ist
die Absicht: ein Reviewer liest ein Pattern, nicht Terraform.

### 4.2 Abstraktionen und Adoption

Drei Abstraktionen, mehr nicht: die Bibliothek `@platform/events` für Envelope,
Routing-Felder und Fehlerprüfung; das Terraform-Modul `event-consumer` für die
gesamte Subscription; die Beispiele in `apps/` als Vorlage zum Kopieren.

Neue Events zuerst; bestehende Queues und Cronjobs bleiben, solange sie halten
— eine Migration ohne neuen Nutzen kostet Vertrauen. Das Plattformteam begleitet
die ersten Abonnements je Team. Als Maß taugt die Zahl der Teams die die Lösung nutzen, nicht die Events pro Sekunde.

## 5. Betrieb und Stabilität

Drei Alarme je Subscription, einer für jeden Weg, auf dem ein Event stehen
bleibt. Sie gehören in das Modul, damit ein Team sie nicht vergessen kann.

| Alarm | Metrik | Bedeutung |
|---|---|---|
| Tiefe beider DLQs | `ApproximateNumberOfMessagesVisible` > 0 | Ein Event ist geparkt. |
| Fehlgeschlagene Zustellung | `FailedInvocations` der Rule | EventBridge hat endgültig aufgegeben. Retries und DLQ-Fälle zählt die Metrik nicht mit. |
| Alter der ältesten Message | `ApproximateAgeOfOldestMessage` | Nichts schlägt fehl, aber nichts kommt voran. |

Der dritte ist der wichtigste: die ersten beiden melden Fehler, der dritte
meldet Stillstand. Die Schwellen setzt das konsumierende Team, es kennt seine
Verarbeitungszeit.

Debugging beginnt an der Dead-Letter-Queue, weil dort das vollständige Event mit
Envelope liegt. Die `correlationId` verbindet eine Kette über mehrere Teams ohne
verteiltes Tracing. Ein nicht zugestelltes Event holt ein Replay aus dem Archive
zurück — möglich, weil Consumer idempotent sind.

Ein Event in einer DLQ ist ein Incident und gehört dem **Team des Consumers** —
auch wenn Rule und Execution Role im Plattform-Account liegen. Der Ort einer
Ressource entscheidet nicht über die Zuständigkeit, das Abonnement tut es. Beim
Plattformteam liegt ein Incident nur, wenn er keiner Subscription gehört.

### Alarmierung

Wie Alarme die Teams erreichen: Alarmierung ist eine zentrale Fähigkeit der Plattform 
und wird nicht von jedem Team individuell umgesetzt. Das Modul erstellt die notwendigen 
Alarme inklusive SNS-Topic. Die Plattform übernimmt die Anbindung an Chat und Incident-Management 
und definiert einheitliche Eskalationsregeln.

Dabei wird nach Dringlichkeit unterschieden: Eine Nachricht in der Dead-Letter-Queue kann 
beispielsweise bis zum nächsten Werktag warten, während ein kontinuierlich steigendes Alter 
der ältesten Nachricht eine sofortige Alarmierung auslöst. Das Produkt-Team konfiguriert 
lediglich das Ziel – etwa den eigenen Kanal – und ob ein Alarm außerhalb der Arbeitszeiten wecken darf.

Individuelle Zustellwege pro Team würden zu unterschiedlichen Eskalationsmechanismen führen 
und es erschweren sicherzustellen, dass kritische Alarme tatsächlich einen Menschen erreichen. 
Die Verantwortung für den Incident bleibt beim Team des Consumers; die zuverlässige Alarmierung 
dieses Teams liegt bei der Plattform.

## 6. Vision und Weiterentwicklung

Jeder Schritt schließt eine Lücke des Prototyps.

1. **Privates Registry für die Bibliothek.** Zwölf Teams binden sie
   nicht über einen Dateipfad ein.
2. **Automatische Freigabe für Routine-Abonnements.** Ein Policy-Check gibt
   frei; Review bleibt für Ausnahmen. Erst danach steht das Plattformteam nicht
   mehr im kritischen Pfad.
3. **Least Privilege beim Deployment.** Eine enge Rolle je Stack statt einer
   administrativen je Account.
4. **Client-Code-Generierung.** Eines eines Tools zum Serialisieren und für Client-Generierung wie z.B. Protobuff oder FlatBuffers.
5. **Abstraktion über Terraform.** Eine Abstraktionsschicht, die es Teams ermöglich, Subscriptions zu erstellen, ohne Terraform Code schreiben zu müssen.
6. **Schützen der Platform-Ressourcen.** Platform-Ressourcen in den Workload Accounts sollten geschützt werden. Vermutlich mit Tags + SCPs.

Eine Schema Registry kommt, wenn der Katalog Envelope und Review übersteigt —
vorher wäre sie Werkzeug ohne Problem.
