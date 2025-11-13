# Home Assistant 1.1 - Integrations and Sensors Reference
This guide lists the live entities and services that power the Home Assistant 1.1 setup so the documentation keeps pace with the active configuration.

---

## Live Inventory Snapshot (.storage/core.entity_registry)
Pulled 2025-11-09 from `.storage/core.entity_registry` (total entities: **2,335**). Use this snapshot when reconciling documentation with the running Home Assistant instance so every sensor, switch and helper referenced below is traceable to live data.

### Entity domain counts
| Domain | Count |
| --- | --- |
| sensor | 1,295 |
| binary_sensor | 303 |
| switch | 161 |
| automation | 82 |
| button | 54 |
| light | 53 |
| media_player | 52 |
| update | 46 |
| script | 36 |
| scene | 36 |
| number | 31 |
| input_number | 22 |
| input_boolean | 20 |
| select | 20 |

### Integration / platform coverage
| Platform | Entities | Notes |
| --- | --- | --- |
| mobile_app | 701 | Companion app trackers, sensors and notify targets for every phone/tablet. |
| huawei_solar | 146 | Huawei inverter + Luna2000 battery metrics and controls. |
| tado | 134 | All heating zones, climate sensors and timers. |
| eufy_security | 122 | Cameras, locks and motion entities from the Eufy bridge. |
| zha | 89 | Native Zigbee network (Tuya, Aqara, IKEA, etc.). |
| hue | 87 | Philips Hue bridge lights, sensors and groups. |
| easee | 51 | Easee charger + equalizer telemetry and controls. |
| volkswagencarnet | 73 | Volkswagen ID.4 Pro sensors and device tracker. |
| synology_dsm | 48 | NAS health, disks and volume statistics. |
| roborock | 40 | Roborock vacuum entities (segments, battery, diagnostics). |
| verisure | 22 | Alarm panel, door lock and plug sensors. |
| nordpool | 4 | SEK/EUR market price feeds (with today/tomorrow attributes). |
| template | 70 | Custom helpers declared in `/packages` (see section below). |

---

## Huawei Solar & Luna2000 Battery
**Domains:** `sensor`, `number`, `select`, `switch`  
**Purpose:** Monitor and control the inverter, battery and grid interaction.  
**Entity footprint:** 146 `huawei_solar` entities available (per the snapshot above).

| Entity | Description | Unit / Notes |
| --- | --- | --- |
| sensor.inverter_input_power | Instant PV production | W |
| sensor.inverter_total_yield | Lifetime PV energy | kWh (state class `total`) |
| sensor.battery_state_of_capacity | Battery state of charge | % (used in automations) |
| sensor.battery_1_day_charge | Energy charged today | kWh |
| sensor.battery_1_day_discharge | Energy discharged today | kWh |
| sensor.batteries_maximum_charge_power | Allowed charge power | W |
| sensor.batteries_maximum_discharge_power | Allowed discharge power | W |
| number.battery_maximum_charging_power | Limit for charging from inverter | W |
| number.battery_maximum_discharging_power | Limit for discharging to load | W |
| number.battery_grid_charge_maximum_power | Max grid charge draw | W |
| select.battery_working_mode | Operating profile (adaptive, maximise self consumption, etc) |  |
| switch.battery_charge_from_grid | Enable charging from grid |  |

**Key services (integration `huawei_solar`):**
- `huawei_solar.forcible_charge` / `huawei_solar.forcible_discharge` - Force charge or discharge at fixed power for a set duration.
- `huawei_solar.forcible_charge_soc` / `huawei_solar.forcible_discharge_soc` - Force charge or discharge until a target state of charge.
- `huawei_solar.stop_forcible_charge` - Exit manual mode started by the force commands.
- `huawei_solar.set_maximum_feed_grid_power` and `_percent` - Cap export to grid, used together with peak management.
- `huawei_solar.set_tou_periods`, `set_capacity_control_periods`, `set_fixed_charge_periods`, `set_zero_power_grid_connection`, `reset_maximum_feed_grid_power` - Schedule or reset inverter behaviour when TOU optimisation is active.

---

## Easee Charger & Equalizer
**Domains:** `sensor`, `binary_sensor`, `switch`, `button`, `select`  
**Purpose:** Supervise the Easee charger and its equalizer, coordinate load control and remote commands.  
**Entity footprint:** 51 live `easee` entities (charger, equalizer, switches and diagnostics).

| Entity | Description | Unit / Notes |
| --- | --- | --- |
| sensor.ehxdyl83_power | Live charger power | W |
| sensor.ehxdyl83_session_energy | Energy delivered this session | kWh |
| sensor.ehxdyl83_voltage | Charger phase voltage | V |
| sensor.ehxdyl83_dynamic_charger_limit | Dynamic current limit applied by Easee | A |
| sensor.ehxdyl83_status | Charger state (ready, charging, error, etc) | Text |
| sensor.qp57qz4q_import_power | Grid import reported by equalizer | W |
| sensor.qp57qz4q_export_power | Grid export reported by equalizer | W |
| sensor.qp57qz4q_import_energy | Imported energy | kWh |
| sensor.qp57qz4q_export_energy | Exported energy | kWh |
| binary_sensor.ehxdyl83_online | Charger connection status |  |
| binary_sensor.qp57qz4q_online | Equalizer connection status |  |
| switch.ehxdyl83_charger_enabled | Enable or disable charging output |  |
| switch.ehxdyl83_smart_charging | Toggle Easee smart charging |  |
| switch.ehxdyl83_weekly_schedule | Activate weekly schedule |  |
| button.ehxdyl83_override_schedule | Immediate override of the active schedule |  |

**Service example:**
```yaml
service: easee.action_command
data:
  device_id: f0e8850e90d3ff8ce4e4c2870ec4de6d
  action_command: start        # start, stop, pause, resume, toggle
```

---

## Volkswagen ID.4 Pro (WeConnect)
**Domains:** `sensor`, `device_tracker`  
**Purpose:** Track EV battery, charging and position data for scheduling and automations.  
**Entity footprint:** 73 `volkswagencarnet` entities (SoC, timers, position, diagnostics).

| Entity | Description | Unit / Notes |
| --- | --- | --- |
| sensor.id4pro_battery_level | Traction battery state of charge | % |
| sensor.id4pro_charging_power | Live charging power | kW |
| sensor.id4pro_charging_time_left | Estimated time to target SoC | Minutes |
| sensor.id4pro_electric_range | Estimated driving range | km |
| sensor.id4pro_last_data_refresh | Timestamp of last poll from WeConnect | UTC timestamp |
| sensor.id4pro_parking_time | Time parked at current location | Timestamp |
| sensor.id4pro_charger_max_ac_setting | Configured AC current limit | A |
| device_tracker.id4pro_position | Vehicle position used for presence and charging rules |  |

---

## Nordpool Pricing & Cheapest Hours
**Domains:** `sensor`, `input_boolean`, `calendar`  
**Purpose:** Provide energy price forecasts and schedule automations for the cheapest windows.  
**Entity footprint:** 4 `nordpool` price sensors plus the helpers listed below.

| Entity | Description | Unit / Notes |
| --- | --- | --- |
| sensor.nordpool_kwh_se3_sek_2_095_025 | Primary hourly price feed | SEK/kWh |
| sensor.nordpool_kwh_se3_eur_2_095_025 | Hourly price converted to EUR | EUR/kWh |
| sensor.cheapest_hours_energy_1 | Timestamp for the next cheap slot (attributes show duration) | device_class `timestamp` |
| sensor.cheapest_hours_energy_2 | Backup window for cheap slot scheduling | device_class `timestamp` |
| input_boolean.cheapest_hours_set | Helper to avoid duplicate calendar entries |  |
| calendar.electricity | Calendar where the automation books cheap-hour events |  |

---

## Currency & Export Revenue Helpers
**Domains:** `sensor`, `template`  
**Purpose:** Keep energy-economy calculations current by mirroring the Fixer FX feed and folding the SEK forecast into an export revenue helper.

| Entity | Description | Unit / Notes |
| --- | --- | --- |
| sensor.exchange_rate | Fixer API sensor providing the base-to-SEK conversion used in energy forecasts | SEK per base currency |
| sensor.electric_export_revenue | Template sensor that offsets the Nordpool EUR price with `input_number.el_export_revenue` for export planning | EUR/kWh |
| input_number.el_export_revenue | Margin (in EUR/kWh) added to export planning to cover fees/taxes | Numeric helper |

**Integration notes:**  
- `sensor.exchange_rate` is created by the `fixer` integration with API key auth and `target: SEK`.  
- `sensor.electric_export_revenue` stays in sync with Nordpool by referencing `sensor.nordpool_kwh_se3_eur_2_095_025`.

---

## Solar Geometry & Grid Flow Helpers
**Domains:** `sensor`, `time_date`  
**Purpose:** Provide deterministic context (sun elevation, grid balance and timestamp) for automations that react to light levels or import/export swings.

| Entity | Description | Unit / Notes |
| --- | --- | --- |
| sensor.solar_angle | Sun elevation in degrees sourced from `sun.sun` | degrees |
| sensor.import_export_power | Template sensor that subtracts Easee import from export to indicate live flow (+ export / - import) | kW (rounded to 2 decimals) |
| sensor.energy_net_consumption_raw | Net import prior to utility-meter processing (feeds monthly/weekly utility meters) | kWh |
| sensor.date_time | Time/Date helper generated by the `time_date` integration (display option `date_time`) | Text timestamp |

---

## Utility Meter & Energy Dashboard
**Domains:** `sensor`  
**Purpose:** Feed the Home Assistant Energy dashboard and peak analysis.

| Entity | Description | Unit / Notes |
| --- | --- | --- |
| sensor.energy_net_consumption_2 | Real-time net grid power mirrored from `sensor.import_export_power` (import = negative, export = positive) | kW |
| sensor.house_net_power_excl_ev | House net power (grid flow + EV offset) so the value reflects non-EV consumption only | kW |
| sensor.weekly_el_consumption | Rolling weekly consumption helper | kWh |

---

## Tado Heating & Boost Automation
**Domains:** `climate`, `binary_sensor`, `switch`  
**Purpose:** Control zoned heating and provide quick boost helpers during cold periods.

| Entity | Description | Unit / Notes |
| --- | --- | --- |
| climate.allroom / climate.bedroom / climate.diningroom / climate.livingroom / climate.office / climate.hallway / climate.hallway_entrance / climate.upper_hallway | Tado climate zones with mode and target temperature |  |
| binary_sensor.<zone>_open_window | Tado open window detection per zone | Bool |
| switch.boost_allroom / switch.boost_bedroom / switch.boost_livingroom / switch.boost_house | Template switches calling `tado.set_climate_timer` scripts for 2h boost |  |

---

## Sure Petcare Cat Flaps
**Domains:** `lock`, `binary_sensor`, `sensor`  
**Purpose:** Manage cat flap lock states and monitor battery health for the Sure Petcare hub.

| Entity | Description | Unit / Notes |
| --- | --- | --- |
| lock.lucka1_locked_all / lock.lucka1_locked_in / lock.lucka1_locked_out | Flap 1 lock state controls |  |
| lock.lucka2_locked_all / lock.lucka2_locked_in / lock.lucka2_locked_out | Flap 2 lock controls |  |
| binary_sensor.lucka1_connectivity / binary_sensor.lucka2_connectivity | Hub connectivity for each flap |  |
| binary_sensor.helge | Pet presence derived from Sure Petcare |  |
| sensor.lucka1_battery_level / sensor.lucka2_battery_level | Battery level per flap | % |

---

## Verisure Alarm, Door Lock and Smart Plugs
**Domains:** `alarm_control_panel`, `lock`, `sensor`, `switch`  
**Purpose:** Integrate the Verisure alarm system, smart plugs and environmental sensors.

| Entity | Description | Unit / Notes |
| --- | --- | --- |
| alarm_control_panel.verisure_alarm | Master Verisure alarm panel |  |
| lock.entre | Front door lock control |  |
| switch.allroom_corner / switch.hallen / switch.kontor / switch.skarm | Verisure smart plugs used in scenes and automations |  |
| sensor.kallartrapp_temperature / sensor.koket_temperature / sensor.overvaningen_temperature | Verisure temperature readings | degC |
| sensor.kallartrapp_humidity / sensor.overvaningen_humidity | Verisure humidity sensors | % RH |

---

## Presence, Locations and Helpers
**Domains:** `person`, `device_tracker`, `binary_sensor`, `input_boolean`  
**Purpose:** Drive automations that react to household, vehicle and pet presence.

| Entity | Description | Notes |
| --- | --- | --- |
| person.micke / person.jeannine | Primary residents | Source for away/home automations |
| input_boolean.micke_home / input_boolean.jeannine_home | Manual override of presence state | Synced with entry and exit automations |
| device_tracker.id4pro_position | Vehicle position used for EV logic | Provided by Volkswagen integration |
| binary_sensor.helge | Pet location signal | Works together with input_boolean.helge_location |
| input_boolean.helge_location | Manual override for cat presence | Toggled by Sure Petcare automations |

---

## Tasker Automation Bridge
**Domains:** `rest_command`, `sensor`, `event`  
**Purpose:** Exchange state and commands with Android phones running Tasker without exposing the Companion app directly to the internet.

| Entity / Service | Description | Notes |
| --- | --- | --- |
| rest_command.tasker | Generic POST endpoint used by Tasker scenes to call HA with `ip_address`, `port` and `path` placeholders | Disabled SSL verification because traffic stays on the LAN |
| sensor.tasker_state | Event-driven template sensor updated from `tasker_event` payloads to reflect the latest Tasker state string | Lets automations branch on Tasker context |
| event.tasker_event | Fired by Tasker webhooks; used as the trigger for the template sensor above | Include `state` in the JSON body to feed `sensor.tasker_state` |

---

## Media, TTS and Notifications
**Domains:** `media_player`, `script`, `notify`  
**Purpose:** Provide audio feedback and announcements throughout the house.

| Entity | Description | Notes |
| --- | --- | --- |
| media_player.hallway | Google Nest in hallway, primary TTS target | Part of `media_player.all_players` group |
| media_player.hallway_2 | Music Assistant virtual player | Used for multi-room playback |
| media_player.koket / media_player.bedroom / media_player.sonos / media_player.hela_huset | Cast and Sonos players grouped in automations |  |
| script.navimow_h500_send_command | Sends voice commands through Google Assistant SDK for the mower | Invoked via automations |
| notify.mobile_app_sm_s911b / notify.mobile_app_sm_s921b | Mobile app notifiers | Used for alerts on charging and security |

---

## Weather and Environment
**Domains:** `weather`, `sensor`, `binary_sensor`  
**Purpose:** Feed environmental data to energy and comfort automations.

| Entity | Description | Unit / Notes |
| --- | --- | --- |
| weather.smhi_home | SMHI forecast entity | Supports hourly and daily forecasts |
| sensor.klingstam_outdoor_temperature | Outdoor temperature from external sensor | degC |
| sensor.home_total_cloud_coverage / sensor.home_thunder_probability / sensor.home_precipitation_category | Forecast metadata from SMHI | % or category |
| sensor.hue_carport_motion_sensor_light_level | Lux level by the Hue carport sensor | lx |
| binary_sensor.hue_carport_motion_sensor_motion | Motion detection for carport | Triggers lighting automations |
| sensor.navimow_h500_battery_level / sensor.navimow_h500_state | Lawn mower telemetry collected via event sensor | %, state text |

---

## Wind Energy Correlation (Forecast Sensor Logic)
**Domains:** `sensor`, `rest`, `statistics`  
**Purpose:** Estimate and log wind-based influence on electricity prices for next-day planning using SMHI (Sweden) and Open-Meteo (Germany proxy).  
**Source:** `/config/packages/weather_energy.yaml`

| Entity | Description | Unit / Notes |
| --- | --- | --- |
| sensor.germany_forecast_wind | Forecasted wind in Berlin (Germany proxy) | m/s |
| sensor.wind_energy_correlation_index | Estimated price impact based on wind | % |
| sensor.wind_average_24h | Rolling 24-hour mean of wind speed | m/s |
| sensor.wind_price_correlation_observed | Observed correlation between wind index and Nordpool prices | % |

**Computation principle:**  
- Average wind > 8 m/s -> expect roughly -10% price impact  
- Average wind between 5 and 8 m/s -> expect roughly -5% price impact  
- Average wind < 5 m/s -> no adjustment  

**Usage:**  
```yaml
adjusted_forecast_price = forecast_price * (1 + (states('sensor.wind_energy_correlation_index') | float(0) / 100))
```

---

## Package-defined Helpers & Automations
Every helper, sensor and automation declared inside `/packages` is enumerated here so the documentation matches the live YAML.

### `packages/advanced_cheapest_hours.yaml`
**Input helper**
- `input_boolean.cheapest_hours_set` – Prevents duplicate bookings by recording whether tomorrow's cheap-window events already exist.

**Template sensors**
- `sensor.cheapest_hours_energy_1` (`unique_id: cheapest_hours_energy_1`) – Primary timestamp for the next window of sequential cheap hours (attributes describe length, search window and fallback).
- `sensor.cheapest_hours_energy_2` (`unique_id: cheapest_hours_energy_2`) – Backup/offset cheap-window timestamp so EV and battery logic can stage two runs per day.

**Automations**
- `automation.cheapest_hours_calendar_trigger_1` (id `cheapest_hours_calendar_entry_1`) – Books the first cheap-hour block into `calendar.electricity` once Nordpool exposes valid data.
- `automation.cheapest_hours_calendar_trigger_2` (id `cheapest_hours_calendar_entry_2`) – Books the second cheap-hour block (for multi-stage runs).
- `automation.cheapest_hours_set_next_cheapest_sequence` (id `cheapest_hours_set_sequence`) – Polls the Nordpool attributes hourly and writes the next cheapest sequence whenever no calendar entry exists.
- `automation.cheapest_hours_failsafe` (id `cheapest_hours_failsafe`) – Inserts a fallback slot using the `fail_safe_starting` attribute if Nordpool data never arrived.
- `automation.cheapest_hours_reset_the_set_helper_for_the_next_day` (id `cheapest_hours_clear_set_flag`) – Resets `input_boolean.cheapest_hours_set` after midnight so the next day's bookings run.

### `packages/battery_optimization.yaml`
**Input numbers**
- `input_number.battery_low_price_threshold` – SEK/kWh ceiling that enables cheap grid-charging logic.
- `input_number.battery_high_price_threshold` – SEK/kWh floor that enables discharge/export logic.
- `input_number.battery_reserve_threshold` – Minimum SoC the automation must preserve.
- `input_number.battery_max_grid_charge_soc` – Upper SoC limit for grid charging during cheap windows.
- `input_number.battery_max_grid_charge_power_kw` – Max grid-charging power (kW) applied to Huawei forcible charge commands.

**Input booleans**
- `input_boolean.battery_automation_enabled` – Global enable/disable switch for the package.
- `input_boolean.battery_ai_mode` – Turns on adaptive tuning/learning behaviours.
- `input_boolean.battery_allow_grid_charge` – Allows forced grid charge (otherwise solar-only).
- `input_boolean.battery_peak_helper_enabled` – Lets the package assist the peak-shaving automations.

**Template sensors**
- `sensor.battery_effective_peak_limit` (`unique_id: battery_effective_peak_limit`) – Calculates the current peak limit after applying the 22:00-06:00 half-factor rule.
- `sensor.battery_current_price_sek` (`unique_id: battery_current_price_sek`) – Mirrors the live Nordpool SEK price for quick comparisons.
- `sensor.battery_estimated_available_discharge_power` (`unique_id: battery_estimated_available_discharge_power`) – Estimates discharge headroom vs. peak and reserve limits.

**Template binary sensors**
- `binary_sensor.battery_in_cheap_price_window` (`unique_id: battery_in_cheap_price_window`) – True when the current price or cheapest-hours calendar allows grid charging.
- `binary_sensor.battery_in_expensive_price_window` (`unique_id: battery_in_expensive_price_window`) – True when price exceeds the high-price threshold.
- `binary_sensor.battery_peak_risk_now` (`unique_id: battery_peak_risk_now`) – Flags peak risk using power sensors + helpers.
- `binary_sensor.battery_solar_surplus_now` (`unique_id: battery_solar_surplus_now`) – Indicates that PV production exceeds house+EV demand.
- `binary_sensor.battery_can_grid_charge_now` (`unique_id: battery_can_grid_charge_now`) – Aggregates automation enable, cheap price and SoC checks.
- `binary_sensor.battery_should_discharge_now` (`unique_id: battery_should_discharge_now`) – Ties together price/peak triggers to start discharging.

**Automations**
- `automation.battery_start_grid_charging_in_cheap_hours` (id `battery_start_grid_charge_in_cheap_hours`) – Enables Huawei forcible charging when the cheap window is active and SoC < target.
- `automation.battery_stop_grid_charging_when_done_not_cheap` (id `battery_stop_grid_charge_when_done_or_not_cheap`) – Turns off grid charging when the target SoC or window end is reached.
- `automation.battery_discharge_for_peak_shaving_high_price` (id `battery_discharge_for_peak_and_high_price`) – Starts forcible discharge to shave peaks or support high-price hours.
- `automation.battery_stop_forcible_discharge_when_safe` (id `battery_stop_discharge_when_safe`) – Stops discharge when reserve/peak conditions clear.

### `packages/calendar_cheapest_hours_automations.yaml`
**Helpers & sensors**
- `input_number.battery_cheapest_hours_target_soc` – Target SoC used when the cheapest-hours slot triggers.
- `binary_sensor.electricity_cheapest_now` (`unique_id: electricity_cheapest_now`) – True while the current time is inside an active cheap-hour calendar event.

**Automations**
- `automation.ev_start_charging_during_cheapest_electricity_hours` (id `ev_start_charging_during_cheapest_hours`) – Starts Easee charging when a cheap event begins and `input_boolean.ev_home` is on.
- `automation.battery_forcible_charge_during_cheapest_electricity_hours` (id `battery_charge_during_cheapest_hours`) – Bumps the battery to the configured SoC while the cheap window is active.
- `automation.ev_stop_charging_when_cheapest_electricity_hours_end` (id `ev_stop_charging_after_cheapest_hours`) – Stops EV charging when the slot finishes (and clears overrides).

### `packages/currency_export_helpers.yaml`
**Helpers & sensors**
- `input_number.el_export_revenue` – Margin (EUR/kWh) applied to export planning so taxes/fees are covered.
- `sensor.electric_export_revenue` (`unique_id: electric_export_revenue`) – Combines Nordpool EUR price with the margin helper (referenced throughout the docs above).

### `packages/grid_energy_helpers.yaml`
**Template sensors**
- `sensor.solar_angle` (`unique_id: solar_angle`) – Mirrors sun elevation for automation conditions.
- `sensor.import_export_power` (`unique_id: import_export_power`) – Combines equalizer import/export data into a signed kW flow.
- `sensor.energy_net_consumption_raw` (`unique_id: energy_net_consumption_raw`) – Net import measurement (kWh) that feeds the Energy dashboard utility meters.
- `sensor.energy_net_consumption_2` (`unique_id: energy_net_consumption_power`) – Live net grid power (equivalent to `sensor.import_export_power`, rounded to 2 decimals).
- `sensor.house_net_power_excl_ev` (`unique_id: house_net_power`) – Live house load that subtracts EV charging power so dashboards show non-EV consumption.

### `packages/nordpool_cheapest_hours.yaml`
**Automation**
- `automation.nordpool_reset_cheapest_hours_flag_daily` (id `nordpool_reset_cheapest_hours_flag_daily`) – Clears the cheapest-hours helper boolean each day so bookings restart cleanly.

### `packages/weather_energy.yaml`
**Template sensors**
- `sensor.wind_average_24h` (`unique_id: wind_average_24h`) – Rolling 24-hour wind average.
- `sensor.wind_energy_correlation_index` (`unique_id: wind_energy_correlation_index`) – Derived metric estimating how wind affects price.
- `sensor.wind_price_correlation_observed` (`unique_id: wind_price_correlation_observed`) – Historical correlation used for tuning/visualisation.

---

## Automations Inventory (.storage/core.entity_registry)
The automation entity list below is generated from `.storage/core.entity_registry` (refresh: 2025-11-09). Use it to confirm that every automation referenced elsewhere actually exists on the running system.

| Entity ID | Friendly name |
| --- | --- |
| automation.aircondition_stop | AirCondition Stop |
| automation.alarm_notification | Alarm notification |
| automation.arm_leaving_home | Arm Leaving Home |
| automation.basement_ceiling_follow_stairs | Basement Ceiling follow Stairs |
| automation.bathroom_floor_heater_on | Bathroom floor heating on |
| automation.bathroom_floor_heating_control | Bathroom floor heating off |
| automation.battery_charge_when_low_price | Battery charge when low price |
| automation.battery_discharge_for_peak_shaving_high_price | Battery - Discharge for peak shaving / high price |
| automation.battery_forcible_charge_during_cheapest_electricity_hours | Battery - Forcible charge during cheapest electricity hours |
| automation.battery_start_grid_charging_in_cheap_hours | Battery - Start grid charging in cheap hours |
| automation.battery_stop_forcible_discharge_when_safe | Battery - Stop forcible discharge when safe |
| automation.battery_stop_grid_charging_when_done_not_cheap | Battery - Stop grid charging when done / not cheap |
| automation.carport_light_off | Carport light Off |
| automation.carport_light_on | Carport light On |
| automation.carport_light_on_coming_home | Carport light On Coming home |
| automation.cat_set_boolean_state | Cat set boolean state |
| automation.catflap_1_battery_warning | CatFlap 1 Battery warning |
| automation.catflap_1_lock | CatFlap 1 Lock |
| automation.catflap_1_unlock | Catflap 1 Unlock |
| automation.catflap_2_battery_warning | CatFlap 2 Battery warning |
| automation.catflap_2_battery_warning_2 | CatFlap 2 Battery warning |
| automation.catflap_2_disconnected | Catflap 2 Connection Monitor |
| automation.catflap_2_lock | Catflap 2 Lock |
| automation.catflap_2_unlock | Catflap 2 Unlock |
| automation.catflap_locked_notification | Catflap Locked Notification |
| automation.charge_start_in_4_hrs | Charge start in 4 hrs |
| automation.cheapest_hours_calendar_trigger | Cheapest hours: Calendar trigger |
| automation.cheapest_hours_calendar_trigger_1 | Cheapest hours: Calendar trigger (1) |
| automation.cheapest_hours_calendar_trigger_2 | Cheapest hours: Calendar trigger (2) |
| automation.cheapest_hours_failsafe | Cheapest hours: Failsafe |
| automation.cheapest_hours_failsafe_1 | Cheapest hours: Failsafe 1 |
| automation.cheapest_hours_failsafe_2 | Cheapest hours: Failsafe 2 |
| automation.cheapest_hours_reset_the_set_helper_for_the_next_day | Cheapest hours: Reset the set helper for the next day |
| automation.cheapest_hours_set_next_cheapest_sequence | Cheapest hours: Set next cheapest sequence |
| automation.cheapest_hours_set_next_cheapest_sequence_1 | Cheapest hours: Set next cheapest sequence 1 |
| automation.cheapest_hours_set_next_cheapest_sequence_2 | Cheapest hours: Set next cheapest sequence 2 |
| automation.day_light | Day light |
| automation.ev_start_charging_during_cheapest_electricity_hours | EV - Start charging during cheapest electricity hours |
| automation.ev_stop_charging_when_cheapest_electricity_hours_end | EV - Stop charging when cheapest electricity hours end |
| automation.evening_light | Evening light |
| automation.evening_light_home | Evening at home |
| automation.feeding_the_cat | Feeding the cat |
| automation.hallway_fan_off | Hallway Fan Off |
| automation.hallway_fan_on | Hallway Fan On |
| automation.helge_set_location | Helge set location |
| automation.jeannine_home | Jeannine Home |
| automation.jeannine_not_home | Jeannine not Home |
| automation.message_to_cheap | Message to cheap |
| automation.message_to_expensive | Message to expensive |
| automation.micke_home | Micke Home |
| automation.micke_not_home | Micke not Home |
| automation.morning_light | Morning Light |
| automation.navimow_h500_get_state | Navimow h500: Get state |
| automation.new_automation | Carport Motion |
| automation.night_light | Night light random |
| automation.nordpool_book_cheapest_hours_in_electricity_calendar | Nordpool - book cheapest hours in electricity calendar |
| automation.nordpool_reset_cheapest_hours_flag_daily | Nordpool - reset cheapest hours flag daily |
| automation.peak_shaving_med_batteri_och_bil_soc | Peak-shaving med batteri och bil-SOC |
| automation.peaks_monthly_rollover_save_reset | Peaks - Monthly rollover (save & reset) |
| automation.peaks_monthly_rollover_save_reset_weighted | Peaks - Monthly rollover (save & reset, weighted) |
| automation.peaks_seed_current_peaks_on_ha_start | Peaks - Seed current peaks on HA start |
| automation.peaks_update_top3_on_grid_power_change | Peaks - Update Top3 on grid power change |
| automation.peaks_update_top3_weighted | Peaks - Update Top3 (weighted) |
| automation.pool_pump_off | Pool pump Off |
| automation.pool_pump_on | Pool pump On |
| automation.set_device_end_start_time | Set device/end start time |
| automation.smartcharge_reminder | Charger Auth Reminder |
| automation.start_air_conditioner | AirCondition Start |
| automation.startup_timer | Startup timer |
| automation.tag_goodnight_is_scanned_2 | Tag GoodNight is scanned |
| automation.tag_hemkomst_is_scanned | Tag Hemkomst is scanned |
| automation.touch_display_off | Touch Display Off |
| automation.touch_display_on | Touch Display On |
| automation.turn_off_away_mode | Away mode Turn off |
| automation.turn_off_device_after_cheapest_hours | Turn off device after cheapest hours |
| automation.turn_on_away_mode | Away mode Turn on |
| automation.turn_on_device_for_cheapest_hours | Turn on device for cheapest hours |
| automation.unlock_coming_home | UnLock coming Home |
| automation.vacuum_notify_on_error | Vacuum: Notify on Error |
| automation.verisure_armed_home | Verisure Armed Home |
| automation.wake_up | Wake Up Micke |
| automation.workprofile_changes | Workprofile changes |

---

## Script Inventory (`scripts.yaml`)
Scripts are sourced from `scripts.yaml` (last refresh 2025-11-09). This table keeps alias/description pairs aligned with the live file.

| Script ID | Alias | Description |
| --- | --- | --- |
| script.1637005175553 | verisure arm home |  |
| script.all_flaps_locked_in | All flaps lock in |  |
| script.all_flaps_unlock | All flaps unlock |  |
| script.bedroomlight_left_on | bedroomlight left on |  |
| script.bedroomlight_night_off | bedroomlight night off |  |
| script.bedroomlight_night_on | bedroomlight night on |  |
| script.bedroomlight_right_on | bedroomlight right on |  |
| script.boost_allroom | Boost Allroom | Boost the allroom radiator |
| script.boost_bedroom | Boost Bedroom | Boost the bedroom radiator |
| script.boost_house | Boost House | Boost the all radiators in the house |
| script.boost_livingroom | Boost Livingroom | Boost the livingroom radiator |
| script.charge_battery_forced | Charge battery forced 2,5kW |  |
| script.cleaning_house | cleaning house |  |
| script.daylight | daylight |  |
| script.discharge_battery_forced | Discharge battery forced |  |
| script.evening | evening |  |
| script.eveninglight | eveninglight |  |
| script.eveninglight_home | eveninglight home |  |
| script.goodnighthouse | goodnight house |  |
| script.navimow_h500_send_command | Navimow h500 - Send command |  |
| script.nightlight | nightlight |  |
| script.play_p4_hallway | Play P4 Hallway |  |
| script.play_p4_sonos | Play P4 Sonos |  |
| script.set_tou_12_14 | Set TOU |  |
| script.showoff | ShowOff |  |
| script.vacum_kitchen | Vacuum kitchen |  |
| script.verisure_arm_away | verisure arm away |  |
| script.verisure_disarm | verisure disarm |  |
| script.verisure_lock | verisure lock |  |
| script.verisure_unlock | verisure unlock |  |
| script.wakeup_micke | WakeUp Micke |  |
| script.workprofile_off_notification | Workprofile Off notification |  |
| script.workprofile_on_notification | Workprofile On notification |  |
| script.yeelight_strip_on | yeelight strip on |  |

---

## Service Quick Reference
| Integration | Service | Purpose |
| --- | --- | --- |
| Huawei Solar | `huawei_solar.forcible_charge`, `huawei_solar.forcible_charge_soc` | Force charge sessions (power or target SoC) |
| Huawei Solar | `huawei_solar.forcible_discharge`, `huawei_solar.forcible_discharge_soc` | Force discharge sessions |
| Huawei Solar | `huawei_solar.set_maximum_feed_grid_power(_percent)` | Limit export power for peak shaving |
| Easee | `easee.action_command` | Start, stop, pause, resume or toggle charging |
| Tado | `tado.set_climate_timer` | Temporary boost heating in individual zones |
| Verisure | `alarm_control_panel.alarm_arm_away`, `alarm_control_panel.alarm_disarm`, `lock.lock`, `lock.unlock` | Alarm and lock actions |
| Script | `script.navimow_h500_send_command` | Issue mower voice commands via Assistant SDK |
| Calendar helpers | `calendar.create_event` (automation) | Books cheapest-hour windows in `calendar.electricity` |

---

_Last updated: 9 Nov 2025 (inventory synced from .storage/core.entity_registry and /packages)_
