Last updated: 2025-11-10 21:10 (CET) — Authorized by ChatGPT

# 🧭 HomeAssistant 1.2 – Rulebook

---

## 📘 General Info (Priority 1)

**Installation**  
- Home Assistant OS  
- Core 2025.11.1 / Supervisor 2025.11.1 / OS 16.3 / Frontend 20251105.0  
- Installed on **Proxmox** using the [tteck/Proxmox Installer](https://github.com/tteck/Proxmox)  
- Config directory: `\\192.168.2.130\config`

**Documentation source repository:**  
[https://github.com/mikaelklingstam/homeassistant-public](https://github.com/mikaelklingstam/homeassistant-public)

All dashboards and UI text must be written in **English**.

---

## 🧭 Mission (Priority 1)

Create an intelligent, self-learning, and fully integrated home system where energy optimization, safety, and comfort work together automatically.  
The system continuously adapts to electricity prices, peak charges, availability, weather, and presence to minimize cost, maximize efficiency, and improve quality of life — without manual control.  
With clearly defined boundaries, it functions like a *self-playing piano* that learns from historical data and experiences from versions 1.0 and 1.1.

---

## ⚙️ Integrations / Sensors Overview (Priority 1)

Includes Huawei Solar & Battery, Easee EV Charger, Nordpool Price Sensors, Utility Meter, Wattson, Verisure, Weather & Forecast correlation, Presence Tracking, Media Players, and Environmental Sensors.  
All entities, services, and data flow mappings are defined in  
`documentation/HA_Integrations_and_Sensors.md`.

---

## 🧩 Contradictions / Resolutions (Priority 2)

1. Battery optimization vs. peak shaving → **peak shaving** has priority.  
2. Peak power counted as 50 % between 22:00–06:00 for cost calculation.  
3. Separate manual and AI thresholds.  
4. Solar energy never exported while battery needs charging.  
5. Nordpool price is definitive; forecast used only for long-term planning.  
6. Centralized Easee charger control script.  
7. Power used for instantaneous logic, energy for meters and history.  
8. 15 minute synchronization of price and weather, max 5 minutes for power data.  
9. Defined, expandable mission boundaries (max peak, min SOC, export hours, comfort exceptions).

---

## 🎨 Visual & Control (Priority 1)

**Purpose:** Define the integrated visual logic and control philosophy of HomeAssistant 1.2.  
All interfaces must present the system as *one coherent unit*, not as separate sub-systems.

### 🔧 Core Principles

1. **Unified Interface**  
   - All dashboards and views are visually and functionally integrated.  
   - Controls may affect multiple systems (e.g., one “Optimize Now” action can trigger both battery and charger).  
   - Functional separation (Battery, EV, Grid, Solar) exists only for settings or diagnostics — not user-facing control.

2. **Flow Visualization (Live Energy Map)**  
   - Central flow diagram shows real-time energy movement between sources and sinks: ☀️ Solar → 🔋 Battery → ⚡ House / 🚗 EV / 🌐 Grid.  
   - Arrows are animated and color-coded by direction and magnitude:  
     Green = Export / Charge Blue = Import / Discharge Orange = Partial / Throttled Red = Overload / Error.  
   - Numeric power values (kW) shown beside each arrow, updated every 2 s.

3. **Modern + Clear Design**  
   - Clean, data-centric aesthetic using Mushroom or custom:button-card.  
   - Rounded corners, soft shadows, clear labels — clarity over decoration.

4. **Control Hierarchy**  
   - **Primary:** User controls + visual dashboard.  
   - **Secondary:** Configuration / threshold / AI tuning views.  
   - **Tertiary:** Backend automation logic.  
   - Each control must indicate target entities, expected outcome, and override status.

5. **Settings / Advanced Views**  
   - Prioritize transparency — user must see *what changes what*.  
   - Use simple inputs and sliders; show cross-references (e.g., “affects battery optimizer thresholds”).

6. **Responsiveness & Scalability**  
   - Adaptive grid layout; flow topology preserved across screen sizes.

---

### 🖼️ Dashboard Scaling and Layer Rules

**Purpose:** Ensure consistent appearance and alignment of dashboard visuals across laptop and mobile.

1. All interactive and visual components (icons, overlays, flows, etc.) must be placed **inside a single `picture-elements` card** tied to the base image.  
2. Every element’s `left`, `top`, and `width` must be defined in **percentages** to ensure correct scaling with the image.  
3. Views using energy flow or layered graphics must be declared with `panel: true` and a fixed `aspect_ratio` (typically 16×9 – 21×9) to avoid vertical scrolling.  
4. All overlay images (e.g., car, arrows, animated lines) must use **identical resolution and alignment** as the base image for pixel-perfect overlaying.  
5. Transitions such as `opacity` or `filter` animations are preferred for state-based visual changes (e.g., car presence, active power flow).  
6. No separate grid-positioned cards may be used for entities tied to the image — these must be `picture-elements` for correct scaling.  
7. Mobile and desktop versions must both be verified for alignment before finalizing layer coordinates.

---

## 🧩 Potential Conflicts – Under Observation (Priority 4)

1. Shared optimization budget coordinating battery, EV, and heating.  
2. Comfort overrides may break peak limits if necessary — visual warning required.  
3. AI-suggested values expire each 15-min interval.  
4. Export stability rule → 1–2 min averaging or ±200 W hysteresis before state change.  
5. Short-term automations use live data; long-term planners use snapshot.  
6. AI training uses normalized peak data (before 0.5 factor).  
7. All dashboard-adjustable thresholds must appear in Settings and be marked **linked control**.

---

## 🌦️ Wind Energy Correlation (Forecast Sensor Logic)

Implements `weather_energy.yaml` package estimating wind-based influence on electricity prices using SMHI and Open-Meteo data.  
Includes sensors for Germany forecast wind, wind energy correlation index, 24 h rolling average wind speed, and observed correlation with Nordpool prices.

---

## 🗂️ Documentation Governance (Priority 2)

Defines how all documentation files under  
`\\192.168.2.130\config\documentation` are synchronized with the GitHub repository [homeassistant-public](https://github.com/mikaelklingstam/homeassistant-public).  
All changes must be previewed as a summary (diff) before being written to local and GitHub files.

### 🕓 Change Tracking and Audit Signature

Each time the rulebook or any associated documentation file is edited, a timestamp line must appear at the very top of the document in this format: