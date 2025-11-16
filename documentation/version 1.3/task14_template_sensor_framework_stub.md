Last updated: 2025-11-15 18:05 (CET) — Authorized by ChatGPT

# 🧱 HA 1.3 – Task 14 Stub  
Template Sensor Framework & Naming Standard

**Mission:**  
When Task 14 kicks off, Codex must produce a unified template/utility meter/helper structure that mirrors all core energy flows (solar → battery → house → grid → EV) under `packages/`, without duplicating existing logic from Tasks 7–12. This stub captures the design guardrails so implementation can start immediately.

---

## 1. Naming Convention (`ha1_*`)

- **Prefix:** Every canonical template uses `ha1_` + `<domain>_<function>`.  
  - Power sensors: `sensor.ha1_<source>_<target>_power` (kW).  
  - Energy totals: `sensor.ha1_<source>_<target>_energy_today/total` (kWh).  
  - Booleans: `binary_sensor.ha1_<context>_<state>`.  
  - Inputs/helpers: `input_*` keep existing domain but suffix with `_ha1`.
- **Case & separators:**  
  - Lower snake case only, no abbreviations that hide meaning (`grid_import`, not `grid_imp`).  
  - Flow sensors use explicit `from_to` segments (`solar_to_house`, `battery_to_grid`, etc.).
- **Device classes & units:**  
  - Power sensors → `device_class: power`, `state_class: measurement`, `unit_of_measurement: kW`.  
  - Energy sensors → `device_class: energy`, `state_class: total_increasing`, `unit_of_measurement: kWh`.

---

## 2. Flow Coverage

Create one canonical path per interface, referencing raw entities from Tasks 8–10:

1. `solar → battery`  
2. `solar → house`  
3. `battery → house`  
4. `battery → grid`  
5. `house → grid` (import/export)  
6. `grid → house` (import)  
7. `grid → EV` / `EV → house load`  
8. `solar → EV` (if derived via surplus logic)  
9. `house → comfort loads` (HVAC/AC) – optional placeholder

Each template must include:
- Inputs list (raw entity + scaling) in comments.  
- Sign conventions aligned with Rulebook (import/export positive).  
- Availability guard (`| float(0)` + `availability:`) to prevent `unknown`.

---

## 3. Rolling Averages & Peak Helpers

- 5‑min, 15‑min, and 60‑min rolling averages for:
  - `sensor.grid_import_export_power`
  - `sensor.ha1_house_load_power`
  - `sensor.ha1_ev_charger_power`
- Use `statistics` or `utility_meter` + template combos inside `packages/ha1_template_sensors.yaml`.  
- Add `sensor.ha1_peak_tracker_current_month` placeholder referencing future Task 15 logic.

---

## 4. Helper Inputs

- SOC thresholds:
  - `input_number.ha1_battery_soc_min`
  - `input_number.ha1_battery_soc_peak_reserve`
  - `input_number.ha1_battery_soc_emergency`
- Comfort override indicators:
  - `input_boolean.ha1_comfort_override`
  - `input_boolean.ha1_export_block`
  - `input_select.ha1_optimization_mode` (values: `auto`, `eco`, `comfort`).
- EV planning:
  - `input_datetime.ha1_ev_ready_time`
  - `input_number.ha1_ev_required_range`

All defined inside the same package file to keep Git diffs localized.

---

## 5. File / Package Structure

- Single entry point: `packages/ha1_template_framework.yaml`.  
- Sections inside the package:
  1. `template:` → all sensors/binary sensors.  
  2. `utility_meter:` → daily/weekly/monthly energy splits.  
  3. `statistics:` → rolling averages.  
  4. `input_*:` → helper definitions.  
  5. `homeassistant.customize:` (optional) for friendly names/icons.
- No logic in `sensors.yaml` or root-level YAML; everything stays under `packages/`.
- Comments at top documenting dependencies (`includes`, Task references).

---

## 6. Duplicate Prevention Checklist

Before implementing:
1. `rg -n "ha1_" packages` to detect existing templates.  
2. Validate no overlapping names with Task 9 Huawei package or Task 8 grid package.  
3. For each new template, reference the unique upstream entity (no double templating of the same raw sensor).  
4. Document rationale inside this file if a duplicate is unavoidable.

---

## 7. Ready-To-Run TODOs for Task 14

- [ ] Create `packages/ha1_template_framework.yaml` using this stub.  
- [ ] Populate solar/battery/grid flow templates with comments + `availability`.  
- [ ] Wire rolling averages + statistics helper.  
- [ ] Define helper inputs and default values.  
- [ ] Update documentation (`HA_Integrations_and_Sensors_1_3.md` + `Functions_And_Settings_1_3.md`) once templates exist.

Keep this stub updated if preparatory work happens before Task 14 begins.
