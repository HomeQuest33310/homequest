# ADR-005 — Event-driven game engine

## Status
Accepted — MVP direction.

## Decision
HomeQuest will use an event-driven game engine. User actions create domain events, and independent systems react to those events.

Example:

```text
QuestCompleted
├── XP Engine
├── Gold Engine
├── Skills Engine
├── Boss Engine
├── Chronicle Engine
└── Kingdom Engine
```

## Why
This keeps the game extensible. Achievements, buildings, pets, seasonal campaigns, and community packs can react to existing events without rewriting quest validation logic.

## MVP Events
- UserSignedUp
- FamilyCreated
- QuestCreated
- QuestCompleted
- QuestApproved
- SkillProgressed
- BossDamaged
- BossDefeated
- RewardClaimed

## Rule
Flutter may optimistically display UI changes, but authoritative game state changes must be performed server-side.
