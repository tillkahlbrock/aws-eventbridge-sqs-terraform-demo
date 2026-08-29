# MOIA ADR Template

- **Status:** Indicates the current state of the ADR. This helps stakeholders quickly understand if the decision is still under consideration, has been agreed upon. A `DECLINED` or `REJECTED` state are no longer suggested. If we decide to do nothing about the problem described in the ADR we can always make this an option in the ADR.
  Possible statuses are: 
  - `DRAFT`: initial status after creation
  - `IN REVIEW` the ADR is mature enough to be announced in the Tech Biweekly, i.e., authors have gathered feedback by people they know to be affected or having expertise in the area.
  - `ACCEPTED`: the ADR has been accepted. After this the document is generally immutable with the exemption of changing the state to `SUPERSEDED`.
  - `SUPERSEDED`: the grounds on which the ADR was `ACCEPTED` have changed, resulting in a new architecture decision documented by another ADR. The link to the superseding ADR should be added to the status. The superseded ADR is kept for documentation purposes.
- **Date:** The date when the ADR was created or last updated. This helps in tracking the decision-making timeline. An ADR is immutable after it has been `ACCEPTED`. (the only exception might be changing the `ACCEPTED` state to `SUPERSEEDED` with a reference to the follow-up ADR.)
- **Affected Service(s) / Component(s):** Specifies which parts of the system are impacted by this decision. For example, specific services or components such as 'Lambda Fanout' or 'Fleet.API'.
- **Authors:** List the authors of the ADR.
- **Technical Story:** Provides a link (e.g., to a JIRA ticket) that gives background information or the narrative that led to this ADR.

## Decision

A summary of your decision in a few lines.

The decision is the first section in the ADR because it is the section that future readers are interested in most. It can stay empty in `DRAFT` and `IN REVIEW` states.

Consider changing the title of the ADR after the decision has been taken. This is convenient for readers who just want to know the outcome of the ADR. 

Each ADR which touches an architectural significant decision should be presented shortly in the Tech BiWeekly before making the decision.

The Tech BiWeekly is our [Architecture Advice Forum](https://moia-dev.atlassian.net/wiki/x/HIBbMwE).
In this forum no decisions are taken - the initiators of the ADR are solely responsible and accountable for the decision.
The focus is on the conversation. 
Even if the discussion is just affecting a smaller circle, many can listen and learn.
This improves architecture skill development and knowledge sharing.
Not all the discussions must happen in the Architecture Advice Forum. 
The discussion in the big round can lead to more in-depth 1-1 conversations.

An ADR should be already mature when presented in the Architecture Advice Forum. 
Prior to the presentation, the ADR should be added to [the list of this page](https://moia-dev.atlassian.net/wiki/x/ZQDR5)). 
The item should also be added to the [agenda of the Tech BiWeekly](https://moia-dev.atlassian.net/wiki/x/BIAOHQ).
After the decision has been taken, the status of the ADR in the list should be updated. The decision should also shortly be shared in the Tech BiWeekly.

## Context

The context of your decision - the surrounding environment in which it was taken (including any constraints), the relevant steps which took you to this point, and the forces which made it necessary.
This section should provide enough background for someone unfamiliar with the details to understand the decision’s basis.

## Options

Enumerates the different approaches or solutions that were considered to address the problem statement.
This section demonstrates that various possibilities were evaluated before arriving at the final decision.

Having only a single option is considered a flaw - there is always the "do nothing" or "not yet" option.
Three to five options are ideal.

Once you decided for an option move it to the first item in the list and mark it as `(SELECTED)`.

- Option 1 (Selected): [Selected option]
- Option 2: [Option]


### Option 1 (SELECTED): [Selected option]
[A few lines describing this option.]

 * Adopted because: [A benefit of this option]
 * Adopted despite: [A drawback of this option]
 * [Continue adding benefits and drawbacks as required.]

### Option 2: [OPTION]
[A few lines describing this option.]

 * Rejected because: [A drawback of this option]
 * Rejected despite: [A benefit of this option]
 * [Continue adding benefits and drawbacks as required.]

For the non-selected options focus on why the option was rejected.

### Option N: [OPTION]
...

## Advice

It can be useful to document a list of persons/roles whose advice is needed and to collect advice proactively from this group. 
Advice can be given by anyone - it is not limited to the group - e.g. after the presentation in the Tech Biweekly more colleages can chime in.
Advice can be of any form which improves the decision making. It can help opening your perspective to blind spots, adding missing information to the document, additional people to seek advice from or other angles you did not so far consider.

Document the advice that was collected from the colleagues who are affected by this change or who have expertise in the area.

- who gave the advice and when
- if the advice was not followed when taking the decision, document why

Note that statements like "I prefer Option 2" or "Option 1 is performing best" are not advice but opinions.

## Additional Links

Includes references to any additional documents, resources, or external content that provide more context or information related to the decision.
This can be links to research papers, technical documentation, or other relevant ADRs.

* [Sample ADR using this template](https://github.com/andrewharmellaw/facilitating-software-architecture/blob/main/adr/ADR002-Shorten-inventory-ids-with-naonoid.md)
