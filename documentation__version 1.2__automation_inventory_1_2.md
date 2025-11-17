# Energy Automations Inventory – Version 1.2 Migration
This document collects every automation that touches energy, pricing, battery or EV logic so we can audit what still depends on the legacy entities before reworking them for the HA1.2 aliases. The goal of this stage is pure discovery—no behavior changes yet.

## Summary
- **Total energy-related automations found:** 16 (see tables below).
- **Version breakdown:** 7 labeled `version 1.1` (packages/version 1.1/*) vs. 9 that look like earlier/“unknown” material (root automations, advanced helper packages, nordpool-most-expensive, etc.).
- **HA1 usage:** 0 of the current automations reference any `sensor.ha1_*` alias; they still rely on the legacy integration sensors such as `sensor.battery_state_of_capacity`, `sensor.nordpool_kwh_*`, `sensor.ehxdyl83_status`, `sensor.id4pro_battery_level`, and a handful of derived/nordpool helpers.

## Automations by Version

### Version 1.1
| Automation ID | Alias | File / Approx. Line | Uses `ha1_*`? | Notes |
| --- | --- | --- | --- | --- |
| `battery_start_grid_charge_in_cheap_hours` | Battery – Start grid charging in cheap hours | `packages/version 1.1/battery_optimization.yaml` (≈219) | No | Triggers on `binary_sensor.battery_can_grid_charge_now`, `binary_sensor.electricity_cheapest_now`, `sensor.nordpool_kwh_se3_sek_2_095_025`; variables/readings use `sensor.battery_state_of_capacity` and the input_number thresholds before calling `huawei_solar.forcible_charge_soc`. |
| `battery_stop_grid_charge_when_done_or_not_cheap` | Battery – Stop grid charging when done / not cheap | Same file (≈279) | No | Mirrors the same binary sensors/`sensor.battery_state_of_capacity`; stops the Huawei forcible charge once cheapest window closes, SoC target reached, or a peak risk sensor flips. |
| `battery_discharge_for_peak_and_high_price` | Battery – Discharge for peak shaving / high price | Same file (≈344) | No | Triggers on the expensive-price window (`binary_sensor.battery_in_expensive_price_window`), `sensor.total_power_usage`, `sensor.nordpool_kwh_se3_sek_2_095_025` and the SoC/binary helper sensors; calls `huawei_solar.forcible_discharge_soc` while protecting reserve SoC. |
| `battery_stop_discharge_when_safe` | Battery – Stop forcible discharge when safe | Same file (≈385) | No | Listens to the same binary sensors and `sensor.battery_state_of_capacity` to stop the discharge run when the peak/price events pass. |
| `ev_start_charging_during_cheapest_hours` | EV – Start charging during cheapest electricity hours | `packages/version 1.1/calendar_cheapest_hours_automations.yaml` (≈48) | No | Uses `binary_sensor.electricity_cheapest_now`, `input_boolean.ev_home`, `sensor.id4pro_battery_level`, `binary_sensor.ehxdyl83_online` before calling `easee.action_command: start`. |
| `battery_charge_during_cheapest_hours` | Battery – Forcible charge during cheapest electricity hours | Same file (≈75) | No | Triggered by `binary_sensor.electricity_cheapest_now`; charges via `huawei_solar.forcible_charge_soc` when `sensor.battery_state_of_capacity` is below the target `input_number`. |
| `ev_stop_charging_after_cheapest_hours` | EV – Stop charging when cheapest electricity hours end | Same file (≈105) | No | Switches the Easee action to `stop` once the cheapest window closes. |

### Unknown / Generic
| Automation ID | Alias | File / Approx. Line | Uses `ha1_*`? | Notes |
| --- | --- | --- | --- | --- |
| `cheapest_hours_calendar_entry_1` | Cheapest hours: Calendar trigger (1) | `packages/advanced_cheapest_hours.yaml` (≈93) | No | Starts/stops `input_boolean.cheap_electricity_simulated_switch` when `calendar.electricity` events hit the `sensor.cheapest_hours_energy_1` entry. |
| `cheapest_hours_calendar_entry_2` | Cheapest hours: Calendar trigger (2) | Same file (≈120) | No | Same as above but bound to `sensor.cheapest_hours_energy_2`. |
| `nordpool_reset_cheapest_hours_flag_daily` | Nordpool – reset cheapest hours flag daily | `packages/nordpool_cheapest_hours.yaml` (≈31) | No | Clears `input_boolean.cheapest_hours_set` at 00:10 so cheapest-hour calendars can rebook. |
| `1663398488822` | Set Exp device/end start time | `nordpool_most_expensive_hours.yaml` (≈50) | No | Populates `input_datetime.device_exp_start_time` / `_end_time` from `sensor.expensive_hours_energy_tomorrow` once per day, giving downstream automations their “expensive window” bounds. |
| `Pool pump On` | Pool pump On | `automations.yaml` (≈660) | No | Turns on `switch.pool_pump` when `sensor.nordpool_kwh_se3_sek_3_095_025` drops below 2 SEK. |
| `Pool pump Off` | Pool pump Off | `automations.yaml` (≈672) | No | Turns the pump off when the same Nordpool sensor climbs above 2 SEK. |
| `Battery charge when low price` | Battery charge when low price | `automations.yaml` (≈894) | No | When `sensor.nordpool_kwh_se3_sek_2_095_025` current price dips below 1.2 and `sensor.battery_state_of_capacity` is under 85 %, calls `huawei_solar.forcible_charge_soc`. |
| `Charge start in 4 hrs` | Charge start in 4 hrs | `automations.yaml` (≈966) | No | Delays 4 hours before launching `script.charge_battery_forced`, allowing timed out-of-hours charges to kick in. |
| `Charger Auth Reminder` | Charger Auth Reminder | `automations.yaml` (≈1101) | No | Sends repeated TTS reminders while `sensor.ehxdyl83_status` reports `awaiting_authorization`; toggles `input_boolean.charge_reminder`. |

## Entities Used
| Entity ID | Automations referencing it | Example automation aliases |
| --- | --- | --- |
| `sensor.nordpool_kwh_se3_sek_2_095_025` | 4 | Battery – Start grid charging in cheap hours; Battery – Discharge for peak shaving / high price; Battery charge when low price; Battery – Stop grid charging when done / not cheap |
| `sensor.nordpool_kwh_se3_sek_3_095_025` | 2 | Pool pump On; Pool pump Off |
| `sensor.battery_state_of_capacity` | 6 | Battery – Start grid charging in cheap hours; Battery – Stop grid charging when done / not cheap; Battery – Discharge for peak shaving / high price; Battery – Stop forcible discharge when safe; Battery – Forcible charge during cheapest electricity hours; Battery charge when low price |
| `sensor.total_power_usage` | 1 | Battery – Discharge for peak shaving / high price |
| `sensor.id4pro_battery_level` | 1 | EV – Start charging during cheapest electricity hours |
| `sensor.ehxdyl83_status` | 1 | Charger Auth Reminder |
| `sensor.cheapest_hours_energy_1` / `_2` | 2 | Cheapest hours: Calendar trigger (1/2) |

For now none of the automations reference the HA1 aliases such as `sensor.ha1_solar_power`, `sensor.ha1_house_power`, or `sensor.ha1_flow_*`; migrations will need to swap the legacy sensors shown above for their HA1 counterparts before we can retire the older sources.

## 1.2 Candidate Automations (ha1_*)
- New HA1-aware clones exist in:
  - `packages/version 1.2/battery_optimization_1_2.yaml`
  - `packages/version 1.2/calendar_cheapest_hours_automations_1_2.yaml`
- Each automation mirrors the 1.1 logic but uses `sensor.ha1_*` aliases and flow sensors from `packages/energy_core.yaml`. They are created with `initial_state: false` so they remain disabled until you explicitly enable and test them alongside the legacy 1.1 versions.
- As you enable these, disable the corresponding 1.1 automation to avoid duplicate actions. Keep an eye on the new IDs (they carry `_1_2`) and update your automation references if you expose them elsewhere.

## Debugging the HA1 Energy Model
- There is now a dedicated Lovelace dashboard at `dashboards/energy_debug_1_2.yaml` (registered as “Energy 1.2 Debug” in the UI) that reflects the health of the new HA1 data layer.
- The dashboard juxtaposes the raw Huawei integration sensors (grid, inverter, battery) against their `ha1_*` aliases and the main HA1 flow sensors, making it easy to spot mismatches.
- It also lists the `[1.2]` automations with their disabled-by-default state so you can toggle them on/off while verifying the new HA1 signals before you retire the legacy automations.
