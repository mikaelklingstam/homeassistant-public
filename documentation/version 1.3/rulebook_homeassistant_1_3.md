Last updated: 2025-11-15 02:58 (CET) — Authorized by ChatGPT

# 🧭 HomeAssistant 1.3 – Rulebook

## 📘 General Info (Priority 1)

Installation method  
Home Assistant OS  
Core 2025.11.1  
Supervisor 2025.11.1  
Operating System 16.3  
Frontend 20251105.0  

Installed on Proxmox via https://github.com/tteck/Proxmox  
Config directory: \\192.168.2.130\config  

This rulebook describes **HomeAssistant 1.3**, built from a stable configuration snapshot (~3 months old) to avoid legacy broken helpers, automations, and integrations from versions 1.0–1.2.

All dashboards and UI text must be written in **English**.

---

## 🧭 Mission (Priority 1)

Create an intelligent, self-learning, and fully integrated home system where energy optimization, safety, and comfort work together automatically. The system continuously adapts to electricity prices, peak charges, availability, weather, and presence to minimize cost, maximize efficiency, and improve quality of life — without manual control. With clearly defined boundaries, it functions like a self-playing piano that learns from historical data and version 1.x experiences.

---

## 📦 Versioning & Scope

- **Version:** HomeAssistant 1.3  
- **Baseline:** Clean configuration from ~3 months ago (before broken helpers/automations accumulated).  
- **Goal:** Reach the same functional end state as the 1.2 design, but:
  - With only active, used helpers and automations.
  - With clearer structure for documentation, Git, and public/private separation.
  - With all decisions and contradictions logged in this rulebook.

1.0 and 1.1 act as knowledge/reference; 1.2 acts as the **design target**. 1.3 is the implementation that reaches that target cleanly.

---

## ⚙️ Structure of HomeAssistant 1.3

Configuration and documentation are organized by the following layers (which will also shape this rulebook):

1. **Integrations**  
2. **Sensors & Helpers**  
3. **GUI / Dashboards**  
4. **YAML Scripts**  
5. **Automations & Logic**

Each layer will be documented with:
- Purpose  
- Entities (inputs/outputs)  
- Dependencies  
- Known limitations / TODOs  

---

## ⚙️ Integrations (Overview – Priority 1)

> Detailed entity lists will live in `HA_Integrations_and_Sensors_1_3.md`.  
> This section will later summarize the *role* of each integration in the 1.3 system (Huawei, Easee, Verisure, Nordpool, etc.).

- **Nordpool Electricity Prices — SE3, SEK, incl. VAT**
  - Status: Active & verified for HomeAssistant 1.3
  - Method: GUI integration only
  - Notes: All previous YAML planners and cheapest-hours logic removed in Task 7.
- **Huawei Solar & LUNA2000 (PV + Battery)**
  - Status: Canonical PV + battery integration for 1.3
  - Provides inverter power, battery SOC, charge/discharge power, and Huawei power meter values.
  - All downstream logic consumes the normalized HA1 layer (kW, %, unified sign conventions) exposed by `packages/huawei_solar_1_3.yaml`.
- **Grid Meter / Import–Export (Integration #2)**
  - Canonical grid source: Easee P1 meter (`QP57QZ4Q`)
  - Net power sensor: `sensor.grid_import_export_power`
  - Sign: **+ import, – export** (kW)
  - Huawei power meter kept as diagnostic source only.
- **Verisure – Alarm, Security & Smart Plugs (Integration #5)**
  - Provides the primary alarm panel state, front-door Lockguard control, perimeter door/window sensors, selected temperature/humidity feeds, and several Verisure smart plugs (touch display, bedroom, hallway, office, etc.).
  - These entities support safety (alarm notifications, auto-lock/unlock), comfort automations (lighting scenes, display power), and environmental monitoring.

**Global sign conventions (applies system-wide):**
- Grid power: `+` = importing from grid, `-` = exporting to grid (kW).
- Huawei battery power: `+` = charging, `-` = discharging (kW).
- All HA1 power sensors report **kW**; HA1 energy sensors report **kWh**.

---

## 🧪 Sensors & Helpers (Overview)

> Template sensors, utility meters, forecast sensors, and AI/planning helpers.

*(To be filled in later tasks.)*

---

## 🎨 GUI / Dashboards (Overview)

> Visual & Control philosophy, energy flow view, control panels, and settings/config views.

*(To be filled in later tasks.)*

---

## 📜 YAML Scripts (Overview)

> Home Assistant scripts (scripts.yaml) and external PowerShell helpers (scripts folder).

*(To be filled in later tasks.)*

---

## 🤖 Automations & Logic (Overview)

> Core automations for:  
> - Peak shaving  
> - Battery charge/discharge  
> - EV charging (including `sensor.id4pro_charging_time_left`)  
> - Comfort overrides  
> - Export logic and price-driven strategies  

*(To be filled in later tasks.)*

---

## 📚 Documentation & Public Repo

- This file (`rulebook_homeassistant_1_3.md`) is the **authoritative rulebook** for HomeAssistant 1.3.  
- The **public repo README** will mirror this file (content-wise) so external viewers see the same information as here, but without any secrets.

Further documentation for 1.3 will be placed in:
- `documentation/version 1.3/action_plan_homeassistant_1_3.md`  
- `documentation/version 1.3/HA_Integrations_and_Sensors_1_3.md`  
- `documentation/version 1.3/Functions_And_Settings_1_3.md`  

If you edit this file again yourself, remember: update the **Last updated:** line at the top.
