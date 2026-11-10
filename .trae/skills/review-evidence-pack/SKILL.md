---
name: review-evidence-pack
description: Turn a reviewer's finding into a committed evidence doc in testing/. Use when the user pastes a review item and wants a test plan or evidence pack. Do not use for general coding.
---

# Review Evidence Pack

Turn a reviewer's finding into a durable, review-proof document committed under `testing/`.

## Before writing anything

1. Read the implementation the finding concerns. Never write expected behaviour from assumption — search and read the relevant services, repositories and migrations first.
2. Break the finding into its clauses. Reviewers often pack several separate checks into one item; each becomes its own numbered test.
3. If the finding cannot be verified at all — no artefact, no environment — say so plainly instead of inventing evidence.

## Document structure

Write Markdown inside a `.txt` file named `testing/<topic>_test_plan.txt`, or `testing/<topic>_evidence.txt` when the artefact already exists and only needs recording.

Skeleton:

1. **Header** — review item, status (`PLAN` or `EXECUTED`), date, artefact under test, and for a built artefact its version and commit.
2. **Purpose** — one short paragraph on what this document is and how to read it.
3. **Scope** — what is in, what is out, and why. Naming the exclusions stops a reviewer filing them as gaps.
4. **Implementation facts** — a numbered table (`F1`, `F2`, …) each with its source file. Every later expected result cites one.
5. **Test method** — how evidence is produced, with exact commands or API routes.
6. **Test cases** — `S1`, `B1`, … each with Steps / Expected / Evidence. State each expectation as a consequence of a fact id.
7. **Results table** — blank, with case ids pre-filled.
8. **Known limitations** — stated up front and numbered.
9. **Evidence index** — a naming convention that lines up with the results table.
10. **Sign-off** — tester, date, accounts or devices used, overall result, findings raised.

## House style

- British English.
- Tables for facts, results and sign-off.
- Plainest possible wording for what was verified.
- Include a SHA-256 and the commit hash when the artefact is a file, so the result is tied to that exact build.
- For missing captures, insert an obvious placeholder rather than a fabricated image.

## Pre-empt the review

Put the things a reviewer would otherwise file as findings into Known limitations, framed as considered trade-offs. Cover at least:

- what the control does not do — a lock that is a UI gate, not encryption; a token in plain preferences, not the keychain
- behaviour that looks like a bug but is deliberate — grace periods, deliberately ignored lifecycle states, resets on reinstall
- anything device-local that does not survive reinstall or device change
- gaps the plan itself will surface, written as a test alongside the planned response

Where a test is likely to find something real, say so and name the cheap fix.

## Finish

1. Commit with a multi-line message explaining why, then push.
2. Report the file path, the case count, and the two or three findings most likely to attract attention.
3. Flag unrelated modified files in the working tree without touching them.

## Do not

- Write expected results not traced to code.
- Claim a test passed — the plan is for the user to execute.
- Fabricate screenshots, logs or HTTP status codes.
