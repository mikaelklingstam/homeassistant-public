Last updated: 2025-02-12 16:32 (CET) — Authorized by ChatGPT

# 🧭 HomeAssistant 1.3 – Documentation Index

Central index of all documentation, dashboards, and automation files.

---

## 📘 Core Documents
- [Rulebook – HomeAssistant 1.3](rulebook_homeassistant_1_3.md)
- [Action Plan – Implementation Phases](action_plan_homeassistant_1_3.md)
- [Functions & Settings](Functions_And_Settings_1_3.md)
- [Integrations & Sensors Reference](HA_Integrations_and_Sensors_1_3.md)
- [Task Procedure – HA1.3](Task_Procedure_HA1.3.md)
- [Comfort Overrides & Exceptions – Phase 1](Functions_And_Settings_1_3.md#comfort-overrides--exceptions--phase-1-ha-13)

---

## 🧩 Key Sections
- [Peak Shaving Automations – Phase 1](#peak-shaving-automations--phase-1)

---

## Peak Shaving Automations – Phase 1

**Purpose:**  
Prevent monthly peak overruns by coordinating EV charging and battery grid-charging behavior when net grid power approaches the configured limit.

**Inputs / Helpers:**
- `input_number.ha1_peak_limit_kw` – hard monthly peak limit (kW)
- `input_number.ha1_peak_warning_margin_kw` – warning zone margin (kW)
- `sensor.ha1_net_grid_power` – net grid import (W, positive = import)
- Guardrails:
  - `input_boolean.ha1_automations_master_enable`
  - `input_boolean.ha1_peak_shaving_enabled`
  - `input_boolean.ha1_ev_automation_enabled`
  - (later) `input_boolean.ha1_battery_automation_enabled`

**Zones & thresholds:**
- **Warning threshold:** `(peak_limit_kw - margin_kw)`
- **Hard limit:** `peak_limit_kw`
- All thresholds are internally converted to watts.

**Dwell times:**
- Warning zone: above warning threshold for **1 minute**
- Hard breach: above hard limit for **1 minute**
- Recovery: below warning threshold for **5 minutes**

**Behavior Model:**
1. **Normal zone**  
   - No peak intervention.  
   - EV/battery follow normal automation rules.

2. **Warning zone**  
   - EV charging is paused to slow the climb toward peak (soft protection).  
   - Battery grid-charging suppression planned but not forced in Phase 1.

3. **Hard breach**  
   - EV charging must be paused.  
   - Battery grid-charging OFF hook included (script id to be wired in once confirmed).

4. **Recovery**  
   - Once grid power remains below the warning threshold for 5 minutes, protection lifts.  
   - EV/battery optimization is allowed to resume when their own logic permits.

**Logging & Observability:**
- Every intervention writes a log entry via `logbook.log` with name `"HA1 Peak"`.  
- Messages include actual grid power and configured peak limit.

**Phase Status:**  
Phase 1 provides a robust and safe foundation for peak shaving using EV control as the primary lever.  
Battery grid-charge suppression will be fully implemented in Phase 2.
