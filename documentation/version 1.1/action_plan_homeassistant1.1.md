# ⚙️ Action Plan – HomeAssistant 1.1

**Purpose:**  
Define a structured build order for implementing, testing, and refining the full Home Assistant 1.1 system — ensuring stability, traceability, and full feature integration.

---

## 🧩 Phase 1 – Foundation
**Goal:** Ensure stable platform, access, and structure.

1. **Install / Verify System**
   - Confirm Home Assistant OS deployment (Core 2025.11.1 / Supervisor 2025.11.1 / OS 16.3 / Frontend 20251105.0) running on the native Home Assistant OS install.  
   - Verify backup routine using Home Assistant OS snapshots (with offsite sync once available).  
   - Mount `\\192.168.2.130\config` and confirm network permissions.

2. **Setup Development Environment**
   - Install VS Code + Codex.  
   - Connect to GitHub (`homeassistant` repo).  
   - Configure `.gitignore`, commit workflow and PowerShell scripts (`push-ha.ps1`, `sync-ha.ps1`).  
   - Verify YAML linting and version tracking.

3. **Base Configuration**
   - Validate `configuration.yaml` and `!include_dir_named packages`.  
   - Enable core integrations: `system_health`, `logger`, `homeassistant: packages:`, `lovelace: dashboards:`.  
   - Test restart + check configuration.

---

## 🔌 Phase 2 – Integrations and Data Sources
**Goal:** Ensure all devices and data inputs are operational.

1. **Energy / Power**
   - Huawei Solar inverter + battery sensors.  
   - Nordpool price integration.  
   - Easee charger (verify device_id and services).  
   - Utility Meter setup for monthly peak / energy tracking.

2. **Environmental and Presence**
   - Weather (SMHI), Verisure, motion and climate sensors.  
   - Presence tracking (phones, Wi-Fi, GPS).

3. **Custom Templates**
   - Codex template sensors for derived values (total flow, peak estimates, AI predictions).  
   - Verify data availability and update frequency.

---

## ⚡ Phase 3 – Energy Optimization Logic
**Goal:** Create and validate the backend automations.

1. **Battery Optimization Package**
   - Place in `/config/packages/battery_optimization.yaml`.  
   - Include charge/discharge thresholds, Nordpool logic, failsafe loops.  
   - Add manual / AI switches and learning thresholds.

2. **EV Charger Automation**
   - Centralized Easee control script.  
   - Include “waiting for authorization” handling + home-check logic.
- ➕ **Implement Alternative 3 – HA override for Greenely Smart Charging.**  
   - Home Assistant shall automatically detect when Greenely pauses charging (`awaiting_start`) and resend `easee.action_command: start` based on `input_boolean.greenely_override`, including multiple retries and status monitoring.

3. **Peak Shaving System**
   - Define input numbers for manual and AI peak limits.  
   - Apply 22:00–06:00 = 50 % rule.  
   - Add monthly summary sensor and visual feedback.

4. **AI and Learning Layer**
   - Historical trend storage (El-price, solar, weather).  
   - AI threshold suggestion logic (expiry after 15 min intervals).

---

## 🧠 Phase 4 – Visualization & Control
**Goal:** Present one unified, live-interactive interface.

1. **Dashboard Structure**
   - Main file: `/config/dashboards/visual_control.yaml`.  
   - Layout based on “Visual & Control” rules.  
   - Use `custom:button-card`, `layout-card`, `svg-graph-card`.

2. **Live Energy Map**
   - Flow diagram ☀️ → 🔋 → ⚡ / 🚗 / 🌐.  
   - Animated arrows (color = direction + power magnitude).  
   - Refresh interval ≤ 2 s.

3. **Settings / Advanced Views**
   - Transparent control sliders and linked helpers.  
   - Show cross-references (“affects battery optimizer thresholds”).

---

## 📘 Phase 5 – Rulebook and Documentation
**Goal:** Keep the system transparent and maintainable.

1. **Rulebook Structure**
   - Sections: Mission | General Info | Integrations | Contradictions / Resolutions | Visual & Control | Action Plan.  
   - Update version and date on major changes.

2. **Export and Backup Automation**
   - Implement `export_all_ha_metadata` script.  
   - Daily snapshot + auto-push to GitHub.

3. **Testing & Validation**
   - Scenario tests: cheap price, high load, no solar, night charging.  
   - Verify no rule conflicts with Contradictions/Resolutions policy.

---

## 🚀 Phase 6 – Optimization & Expansion
**Goal:** Fine-tune and prepare for future extensions.

1. **Fine-Tuning**
   - Adjust AI weights and threshold learning.  
   - Add shared optimization budget sensor.

2. **Future Integrations**
   - Segway Navimow, FTX ventilation, heating systems.  
   - Cross-optimization between comfort and cost.

3. **Performance Monitoring**
   - Diagnostic dashboard for response times and stability.  
   - Monthly export summary and GitHub tag (“2025-Q4 Stable”).

---

### ✅ Final Outcome
A fully integrated, self-optimizing, visually coherent energy-management system operating under the **HomeAssistant 1.1 Rulebook**, with clear documentation, automated backups, and a defined update flow.
