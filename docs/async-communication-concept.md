# Plattform für asynchrone Kommunikation

<!-- Ergebnis zur Aufgabe in docs/PlatformAufgabeE.pdf. Grenze: 6 Seiten. -->

## 1. Kontext und Ziel

### 1.1 Ausgangslage

Zwölf Produktteams betreiben mehr als zwanzig Services. Asynchrone
Kommunikation ist je Team gewachsen: Queues, Cronjobs und eigene Worker. Es gibt
keinen Standard für Events, Retries, Fehlerbehandlung oder Monitoring. Sobald
eine Message eine Teamgrenze überschreitet, ist die Ownership unklar. Messages
gehen verloren, und das Debugging eines Flows heißt, drei Accounts von Hand zu
lesen.

### 1.2 Ziel

Ein Golden Path für asynchrone Kommunikation zwischen Services. Ein Team muss
ein Domain-Event veröffentlichen oder abonnieren können, ohne Transport, Retries
oder Fehlerbehandlung selbst zu entwerfen.

Wir sind fertig, wenn:

- ein Produkt-Team ein Event per Pull Request bestimmte Events abonnieren kann;
- jedes Event einen Owner, ein Schema und einen veröffentlichten Namen hat;
- keine Message still verloren gehen kann und jeder Fehler dort landet, wo ein Mensch
  ihn sieht;
- das Plattformteam nicht im kritischen Pfad einer Routine-Subscription steht.

### 1.3 Nicht-Ziele: was wir bewusst nicht bauen

- **Einen Command-Bus.** Siehe 2.3. Punkt-zu-Punkt-Kommunikation bekommt eine
  Queue, nicht den gemeinsamen Bus.
- **IAM-Policies für Produkt-Identitäten.** Ein Team, das das AWS SDK aufruft,
  kennt die nötige Berechtigung.
- **Eine Schema Registry, in der ersten Iteration.** Konventionen für Envelope und Eventstruktur reichen,
  bis der Event-Katalog darüber hinauswächst.
- **Self-Service Account Vending oder ein Entwicklerportal.** Pull Requests auf
  ein Repository decken zwölf Teams ab.
- **Multi-Region und Disaster Recovery.** Eine Region, bis eine fachliche
  Anforderung etwas anderes verlangt.
- **Event Sourcing.** Der Bus ist Transport. Er ist kein System of Record.

## 2. Architektur und Design

### 2.1 Zielarchitektur

![Zielarchitektur der Plattform für asynchrone Kommunikation](async-communication-architecture.png)

Ein Producer im Account des Order Service veröffentlicht über `PutEvents` auf
den gemeinsamen Bus. Eine Rule je Subscription filtert auf den Inhalt und stellt
über eine Execution Role in die SQS Queue im Account des Consumers zu. Die
Dead-Letter-Queue nimmt auf, was der Consumer wiederholt nicht verarbeiten kann.

### 2.2 Auswahl der AWS Services und geprüfte Alternativen

Ein eigener **EventBridge** Event Bus in einem Plattform-Account trägt jedes
Domain-Event. **SQS** gibt jeder Subscription einen eigenen dauerhaften Puffer im
Account des konsumierenden Teams.

EventBridge entscheidet das Routing, denn seine Rules filtern auf den Inhalt
eines Events. Ein Consumer erklärt, was er will; ein Producer erfährt nie, wer
zuhört. SQS entscheidet die Zustellung, denn eine Queue puffert Last, übersteht
einen Ausfall des Consumers und unterstützt eine Dead-Letter-Queue.

| Option | Verworfen, weil |
|---|---|
| SNS und SQS | Einfacher zu erklären, aber das Routing wird mit dem Wachstum der Plattform unübersichtlich. Fan-out braucht ein Topic je Event-Typ, und Filter Policies prüfen Attribute statt Inhalt. |
| MSK oder Kafka | Starke Eigenschaften bei Reihenfolge und Retention. Der Betriebsaufwand ist für ein Plattformteam von fünf Personen zu hoch. |
| Queue je Service-Paar | Das ist die Ausgangslage. Sie koppelt Producer an Consumer und verdeckt die Ownership. |

Aus der Wahl folgen zwei Einschränkungen. Weder EventBridge noch eine SQS
Standard Queue garantiert die Reihenfolge. Die Zustellung erfolgt mindestens
einmal, deshalb müssen Consumer idempotent sein. Siehe 2.5.

### 2.3 Events und Commands

Die Plattform unterstützt **Events**. Wir bauen keinen Command-Bus.

Ein Event nennt eine Tatsache, die bereits eingetreten ist. Der Producer besitzt
das Schema und kennt seine Consumer nicht. Ein Command weist einen benannten
Empfänger an zu handeln. Der Empfänger besitzt das Schema, und der Sender muss
wissen, dass der Empfänger existiert. Genau diese Kopplung soll asynchrone
Kommunikation auflösen.

EventBridge entscheidet die Frage. Seine Rules sind Inhaltsfilter, die der
Consumer definiert. Legt man ein Command auf den gemeinsamen Bus, wird aus „wer
führt das aus“ ein „wer auf das Pattern passt“. Die Garantie auf genau einen
Handler ist weg.

Teams brauchen trotzdem asynchrone Punkt-zu-Punkt-Kommunikation. Fast immer
wollen sie Lastausgleich, Retries und Dauerhaftigkeit, nicht Routing. Dafür gibt
es ein Terraform-Modul mit Queue: SQS und eine Dead-Letter-Queue, ohne Bus und
ohne Rule. Arbeit, die eine Antwort braucht, bleibt ein synchroner HTTP-Aufruf.

Wir setzen die Trennung über Benennung durch, nicht über Werkzeuge. Events
stehen in der Vergangenheit, `OrderCreated`. Commands stehen im Imperativ,
`ShipOrder`. Ein Pull Request, der `SendEmail` auf den Bus legt, fällt damit im
Review auf.

### 2.4 Event-Schema und Envelope

Jedes Event trägt einen Plattform-Envelope um die fachliche Nutzlast. Der
Envelope enthält mindestens:

| Feld | Zweck |
|---|---|
| `id` | Unsere eigene ID, nicht die von EventBridge. Für Tracing und Idempotenz. |
| `version` | Erlaubt einem Consumer, eine Nutzlast zu lesen, für die er nicht gebaut wurde. |
| `timestamp` | Wann der Producer veröffentlicht hat, nicht wann EventBridge empfangen hat. |
| `domain` | Der Problemraum, zum Beispiel `orders`. |
| `service` | Der produzierende Service. |
| `type` | Der Event-Typ, zum Beispiel `OrderCreated`. |

Wir nutzen eine eigene ID, weil EventBridge bei einem Replay und bei einem
SDK-Retry eine neue ID vergibt. Dieselbe Tatsache kann also zweimal mit zwei
EventBridge-IDs ankommen. Unsere ID bleibt stabil, deshalb kann ein Consumer
darauf deduplizieren.

Der Envelope ist unabhängig vom Transport. Derselbe Leser arbeitet für SQS, SNS
und Kinesis. Ein späterer Wechsel des Transports schreibt den Consumer-Code
nicht neu.

Eine gemeinsame Bibliothek schreibt und liest den Envelope. Handgebaute
Envelopes heben den Zweck auf.

**Verhältnis zu den EventBridge-Feldern.** `Source`, `DetailType` und `Detail`
sind Pflichtfelder: EventBridge weist einen Eintrag ohne sie zurück. Sie
existieren also ohnehin, und die Bibliothek leitet sie aus dem Envelope ab,
damit sie nicht auseinanderlaufen:

```
Source     = <Präfix>.<domain>      com.example.orders
DetailType = <type>                 OrderCreated
Detail     = { ...Envelope, payload }
```

Die Identität eines Events routet damit über `Source` und `DetailType`.
Zusätzliche Bedingungen dürfen auf Felder in `Detail` matchen, zum Beispiel auf
einen Mandanten oder eine Region. Sie ersetzen die Identität aber nicht. Zwei
Wege für dieselbe Bedingung machen einen Rule-Diff im Review unlesbar.

### 2.5 Fehlerbehandlung: Retries, Dead-Letter-Queues, Idempotenz

Es gibt zwei unabhängige Fehlerfälle, und jeder braucht seine eigene
Dead-Letter-Queue. Sie zu verwechseln ist der häufigste Weg, ein Event zu
verlieren.

**EventBridge kann nicht an die Queue zustellen.** Die Queue Policy ist falsch,
oder das Target drosselt. EventBridge wiederholt 24 Stunden lang und bis zu
185-mal, mit exponentiellem Backoff und Jitter. Danach verwirft es das Event,
außer das Target hat eine Dead-Letter-Queue. Diese DLQ gehört zur Rule und liegt
im Plattform-Account.

**Der Consumer kann die Message nicht verarbeiten.** Die Message kehrt nach dem
Visibility Timeout in die Queue zurück. Nach `maxReceiveCount` Empfängen schiebt
die Redrive Policy sie in die Dead-Letter-Queue im Account des Consumers.

Idempotenz ist Aufgabe des Consumers, weil die Zustellung mindestens einmal
erfolgt. Der Consumer speichert die `id` aus dem Envelope und überspringt eine
Wiederholung. Die gemeinsame Bibliothek liefert das mit.

Jede Dead-Letter-Queue wird auf ihre Füllhöhe alarmiert. Eine Message in einer
DLQ ist ein Incident, keine Statistik. Siehe 5.3.

### 2.6 Zugang, Security und Isolation

An jeder Account-Grenze müssen beide Seiten zustimmen. Keine einzelne Policy
gewährt den Zugriff allein.

**Veröffentlichen.** Die Resource Policy des Bus nennt den Producer-Account. Das
produzierende Team erlaubt seiner eigenen Identität `events:PutEvents` auf genau
diese Bus-ARN. Beide Seiten müssen den Aufruf zulassen.

**Zustellen.** EventBridge nimmt eine Execution Role im Plattform-Account an.
Die Identity Policy dieser Rolle erlaubt `sqs:SendMessage` auf genau eine
Queue-ARN. Die Queue Policy im Consumer-Account nennt diese Rolle als einzigen
zugelassenen Absender.

Die Isolation folgt der Account-Grenze. Die Queue eines Consumers liegt im
Account des Consumers. Ein lauter oder defekter Consumer kann deshalb kein
anderes Team beeinträchtigen. Der gemeinsame Bus ist die einzige geteilte
Komponente, und nur das Plattformteam schreibt darauf.

## 3. Terraform-Prototyp

Der Prototyp ist ein lauffähiges Repository, keine Skizze. Er ist deployt, und
ein Event hat den gesamten Weg von Anfang bis Ende zurückgelegt.

### 3.1 Struktur des Repositories und Ownership

```
terraform/
├── bootstrap/                  einmalig von Hand: State Bucket, Deploy Roles
├── modules/
│   ├── event-platform/         der gemeinsame Bus und seine Resource Policy
│   └── event-consumer/         Subscription: Rule, Target, Queue, DLQ
└── stacks/
    ├── platform/               Plattformteam; producers.tf registriert Producer
    └── consumers/
        └── fulfillment-service/   Produktteam B
packages/
└── events/                     der Envelope: publish() und parse()
apps/
├── order-service/              veröffentlicht OrderCreated
└── fulfillment-service/        konsumiert es
```

Ein Repository, im Besitz des Plattformteams. Ein Produktteam öffnet einen Pull
Request. `CODEOWNERS` verlangt die Freigabe der Plattform, und eine Pipeline
wendet jeden Stack an.

Der State ist je Stack getrennt, nicht je Repository. Ein Apply eines
Produktteams kann den gemeinsamen Bus nicht beschädigen.

Stacks tragen den Namen des Service, dem sie gehören, nie den des AWS Accounts.
Ein Account ist ein Ziel für ein Deployment. Der Consumer-Stack zeigt das: er
deployt in zwei Accounts, denn eine EventBridge Rule muss dem Account gehören,
dem auch der Bus gehört.

### 3.2 Defaults und Wiederverwendbarkeit

Das Modul `event-consumer` ist die gesamte Schnittstelle für Entwickler. Eine
Subscription ist ein Modulblock mit einem Event Pattern, einem Namen für die
Queue und einem Namen für die Rule. Den Rest setzt das Modul: Redrive Policy,
`maxReceiveCount`, Retention, die Execution Role und beide Resource Policies.

Das Modul deklariert zwei Provider-Aliase, `aws.platform` und `aws.consumer`. Es
konfiguriert keine Credentials, keine Region und kein Assume Role. Das Root
liefert diese, deshalb arbeitet dasselbe Modul für jeden Consumer-Account.

Stacks lösen den Bus über seinen Namen mit einer Data Source auf. Kein Stack
liest den State eines anderen Stacks, und niemand kopiert eine ARN.

### 3.3 Was der Prototyp zeigt und was er auslässt

Mit einem Testevent gegen die deployte Infrastruktur nachgewiesen:

- ein Event läuft über Bus, Rule, Execution Role und Queue bis zum Consumer;
- ein Event, das nicht auf das Pattern passt, wird an der Rule verworfen. Es
  wird nicht zugestellt und landet auch nicht in der Dead-Letter-Queue;
- das Berechtigungsmodell trägt: Rolle und Queue Policy nennen einander, und
  enger geht es nicht;
- der Envelope überlebt den Transport. Producer und Consumer sehen dieselbe
  `id`, und sie ist eine andere als die von EventBridge vergebene. Genau darauf
  dedupliziert ein Consumer.

Der Testlauf lief in einem einzigen AWS Account, weil nur ein Sandbox-Account
zur Verfügung stand. Die Trennung ist im Code vollständig angelegt: das Modul
kennt zwei Provider, und die Zustellung nutzt den Weg über Execution Role und
Queue Policy, den ein echter Account-Wechsel verlangt. Nachgewiesen ist der
Mechanismus, nicht der Account-Wechsel selbst.

Die Bibliothek liegt als `file:`-Abhängigkeit im Repository,
ohne Registry und ohne Build-Schritt. Für zwölf Teams ist ein privates Registry
der nächste Schritt.

Bewusst ausgelassen:

- Schema-Validierung und ein Speicher für die Deduplizierung; die Bibliothek
  legt `id` offen, entscheiden muss der Consumer;
- die Dead-Letter-Queue an der Rule aus 2.5, die erste Lücke, die zu schließen
  ist;
- Least Privilege beim Deployment; die Pipeline nutzt je Account eine
  administrative Rolle;
- Alarme, Dashboards und Tracing.

## 4. Developer Experience und Golden Path

Der Golden Path hat genau zwei Berührungspunkte mit der Plattform: ein Eintrag
in `producers.tf`, wenn ein Team veröffentlichen will, oder ein Stack-Verzeichnis,
wenn es abonnieren will. Beides ist ein Pull Request.

### 4.1 Ein Event veröffentlichen

Einmalig: das Team trägt seinen Account in `producers.tf` ein. Eine Zeile, ein
Pull Request, Freigabe durch das Plattformteam.

```hcl
locals {
  producers = {
    "order-service" = { account_id = "841162690095" }
  }
}
```

Danach ohne weitere Plattform-Beteiligung, für jedes weitere Event:

```ts
import { publish } from "@platform/events";

await publish({
  domain: "orders",
  service: "order-service",
  type: "OrderCreated",
  payload: { orderId },
});
```

Das Team gibt seiner eigenen Runtime-Rolle `events:PutEvents` auf die Bus-ARN.
Die Bibliothek setzt Envelope, `Source` und `DetailType` und wirft, wenn
`FailedEntryCount` gesetzt ist.

Ein neuer Event-Typ braucht keinen Pull Request in der Plattform. Wer niemanden
hat, der zuhört, stört auch niemanden.

### 4.2 Ein Event abonnieren

Das Team legt ein Verzeichnis unter `stacks/consumers/` an. Der ganze Inhalt ist
ein Modulblock:

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

Queue, Dead-Letter-Queue, Redrive Policy, Rule, Target, Execution Role und beide
Resource Policies entstehen daraus. Nach dem Merge wendet die Pipeline den Stack
an.

Der Consumer liest die Queue und bekommt den Envelope getypt zurück:

```ts
const envelope = parse<{ orderId: string }>(message.Body);
```

Eine spätere Änderung am Abonnement ist ein Ein-Zeilen-Diff am `event_pattern`.
Genau das ist die Absicht: ein Reviewer liest ein Pattern, nicht Terraform.

### 4.3 Abstraktionen: SDK, Terraform-Modul, Templates

Drei, mehr nicht:

| Abstraktion | Was sie abnimmt |
|---|---|
| `@platform/events` | Envelope, Ableitung der Routing-Felder, Fehlerprüfung bei `PutEvents` |
| `event-consumer` (Terraform) | die gesamte Subscription mit Queue, DLQ, Rollen und Policies |
| Die Beispiele in `apps/` | Vorlage zum Kopieren für Producer und Consumer |

Bewusst keine Abstraktion sind ein Portal, ein CLI und Codegenerierung. Jede
davon ist eine eigene Software mit eigenem Betrieb. Ein Team von fünf Personen
betreibt bereits eine Plattform.

### 4.4 Onboarding und Adoption

Neue Events zuerst. Bestehende Queues, Cronjobs und Worker werden nicht
migriert, solange sie halten. Eine Migration ohne neuen Nutzen kostet Vertrauen.

Das Plattformteam begleitet das erste Abonnement je Team gemeinsam, danach nicht
mehr. Wer den zweiten Pull Request allein schafft, hat den Golden Path
verstanden.

Als Maß taugt die Zahl der Teams mit mindestens einem Abonnement, nicht die Zahl
der Events pro Sekunde. Das zweite misst Last, das erste Adoption.

Der Engpass ist das Review. Solange das Plattformteam jeden Pull Request von
Hand prüft, steht es im kritischen Pfad jeder Produktänderung. Genau das soll
eine Plattform beseitigen. Der nächste Schritt steht in Abschnitt 6.

## 5. Betrieb und Stabilität

### 5.1 Monitoring und Alarmierung

Drei Alarme je Subscription, einer für jeden Weg, auf dem ein Event stehen
bleibt. Sie gehören in das Modul `event-consumer`, damit ein Team sie nicht
vergessen kann. Im Prototyp fehlen sie noch, siehe 3.3.

| Alarm | Metrik | Was er bedeutet |
|---|---|---|
| Tiefe der Dead-Letter-Queues | `ApproximateNumberOfMessagesVisible` > 0 | Ein Event ist geparkt. Beide DLQs aus 2.5 sind gemeint. |
| Fehlgeschlagene Zustellung | `FailedInvocations` der Rule | EventBridge hat endgültig aufgegeben. Retries und DLQ-Fälle zählt die Metrik nicht mit, deshalb ist jeder Wert echt. |
| Alter der ältesten Message | `ApproximateAgeOfOldestMessage` | Nichts schlägt fehl, aber nichts kommt voran. Der Consumer steht oder ist zu langsam. |

Der dritte ist der wichtigste. Die ersten beiden melden Fehler, der dritte
meldet Stillstand. Stillstand fällt sonst erst auf, wenn jemand ein Ergebnis
vermisst.

Schwellen setzt das konsumierende Team. Es kennt seine Verarbeitungszeit; das
Plattformteam kennt sie nicht.

### 5.2 Debugging eines Event-Flows

Der Einstieg ist die Dead-Letter-Queue. Sie enthält das vollständige Event mit
dem Envelope, also `id`, `correlationId`, `timestamp` und den produzierenden
Service. Damit steht fest, was ankam und von wem.

Die `correlationId` verbindet eine Kette. Wenn jeder Service sie bei jedem Log
mitschreibt, lässt sich eine Choreografie über mehrere Teams hinweg verfolgen,
ohne verteiltes Tracing zu betreiben.

Wurde ein Event gar nicht zugestellt, hilft das Archive des Bus. Ein Replay
stellt es erneut zu. Das ist möglich, weil Consumer idempotent sind: eine
zweite Zustellung derselben `id` ist folgenlos.

### 5.3 Fehler und Incidents

Ein Event in einer Dead-Letter-Queue ist ein Incident, kein Zähler. Er gehört
dem **Team des Consumers**. Es besitzt das Abonnement, die Queue und den Code,
der die Message nicht verarbeiten konnte.

Das gilt auch für die Rule und die Execution Role, obwohl beide im
Plattform-Account liegen. Der Ort einer Ressource entscheidet nicht über die
Zuständigkeit, das Abonnement tut es.

Beim Plattformteam liegt ein Incident nur, wenn er nicht einer Subscription
gehört: der Bus ist nicht erreichbar, oder die Rules mehrerer Teams schlagen
gleichzeitig fehl.

Nach der Behebung schiebt ein Redrive die Messages aus der DLQ zurück in die
Queue. Auch das trägt die Idempotenz aus 2.5.

## 6. Vision und Weiterentwicklung

Vier Schritte, in dieser Reihenfolge. Jeder schließt eine benannte Lücke, keiner
fügt eine Fähigkeit hinzu, die noch niemand verlangt hat.

1. **Dead-Letter-Queue an der Rule.** Heute geht ein Event verloren, das
   EventBridge nicht zustellen kann. Der billigste Schritt, und der einzige, der
   Datenverlust schließt.
2. **Privates Registry für die Envelope-Bibliothek.** Zwölf Teams können sie
   nicht über einen Dateipfad einbinden.
3. **Automatische Freigabe für Routine-Abonnements.** Ein Policy-Check gibt ein
   Abonnement ohne Menschen frei. Review bleibt für einen neuen Producer, eine
   domänenübergreifende Subscription oder ein Pattern ohne Event-Typ. Erst
   danach steht das Plattformteam nicht mehr im kritischen Pfad.
4. **Least Privilege beim Deployment.** Eine eng gefasste Rolle je Stack statt
   einer administrativen je Account.

Eine Schema Registry kommt, wenn der Katalog den Envelope und das Review
übersteigt. Vorher wäre sie Werkzeug ohne Problem.
