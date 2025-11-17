Last updated: 2025-11-17 15:59 (CET) — Authorized by ChatGPT

# 📘 HomeAssistant 1.3 – Task Execution Procedure
A structured workflow for running tasks, Codex updates, and documentation syncs.

## 🧩 Overview
This workflow keeps configuration, documentation, and Git repos always in sync.  
All HA 1.3 tasks follow this procedure.

## 📂 Where Everything Runs

**Main Chat (`_Project 1.3 tasks`)**
- Get next task
- Mark tasks done
- Never do YAML work here

**Branched Task Chats (`HA 1.3 – Task N (…)`)**
- All design, reasoning, and YAML generation
- Creation of Codex prompts

**Codex (VS Code)**
- Apply YAML updates
- Run validation
- Apply documentation sync
- Commit + push private/public repos

------------------------------------------------------------
# 🧭 Full Workflow Per Task

## Step 1 — Get Task N (main chat)
ChatGPT provides:
- Breakout prompt
- Documentation sync reminder
- Codex stub for next task

## Step 2 — Create a new branch chat
Name: `HA 1.3 – Task N (task name)`
Paste the breakout prompt.

## Step 3 — Do the task (branch chat)
- Design YAML
- Work through logic
- Produce Codex prompts
- No documentation updates yet

## Step 4 — Use Codex to apply YAML changes
- Update config files
- Remove legacy/zombie files if needed
- Run config validation (`ha core check` or `hass --script check_config`)
- Fix everything until green

## Step 5 — Run the Task N Documentation Sync (Codex)
This is mandatory.
It updates:
- All documentation timestamps
- Rulebook sections
- Functions & Settings
- Integrations & Sensors
- Task tracker in `_index.md`
- References to canonical helper/sensor files
- Commits and pushes changes
- Syncs to public repo

## Step 6 — Return to main chat
Say:
  “Task N done — give me Task N+1”
ChatGPT then provides:
- Task N+1 breakout prompt
- Task N+2 Codex stub

------------------------------------------------------------
# 🧩 Important Notes

## About Codex Stubs
- Each task provides a Codex stub for *next* task.
- You DO NOT run it immediately.
- You run it only inside the branch chat for the next task.

## Documentation Sync Rule
**Every task ends with a documentation sync.**
This prevents drift between configuration and documentation.

## Only Codex modifies YAML
- Never write YAML manually in the chat; only Codex applies it.
- Documentation changes also happen via Codex.

## Config Must Validate After Each Task
- No broken entities
- No YAML errors
- No duplicate IDs

## Branch Chats Keep Tasks Isolated
Main chat = project manager  
Branch chat = work area

------------------------------------------------------------
# 📌 End-to-End Example

1. Main chat: “Give me Task 16”
2. ChatGPT gives Task 16 + Task 17 stub
3. New chat: `HA 1.3 – Task 16 (…)`
4. Do the work; generate Codex prompt
5. Codex applies YAML; config passes
6. Codex runs documentation sync
7. Return to main chat: “Task 16 done — give me Task 17”
8. Repeat

------------------------------------------------------------
