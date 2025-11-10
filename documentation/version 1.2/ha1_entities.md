# HA1 Entities – HomeAssistant 1.2
These `ha1_*` sensors are defined in `packages/energy_core.yaml` to present friendly aliases and derived flows on top of the underlying integrations. They exist for dashboards, automations, and flow visualisations; the raw integration sources are summarised in [integration_entities.md](integration_entities.md).

| Entity ID | Friendly Name | Category | Description | Notes |
| --- | --- | --- | --- | --- |
| `sensor.ha1_solar_power` | HA1 Solar Power | Alias | Mirrors `sensor.inverter_input_power` (W). | Base PV input, floored to 0. |
| `sensor.ha1_battery_soc` | HA1 Battery SOC | Alias | Mirrors `sensor.battery_state_of_capacity` (%). | |
| `sensor.ha1_battery_power` | HA1 Battery Power | Alias | kW → W conversion of `sensor.battery_charge_discharge_power` with positive discharge, negative charge. | Positive means battery discharging to house/grid. |
| `sensor.ha1_house_power` | HA1 House Power | Alias | Approximation of house load calculated from `sensor.inverter_active_power` (kW → W) plus the grid contribution; at night it matches grid import. | Used as the primary house demand reference for AC split flows. |
| `sensor.ha1_grid_power` | HA1 Grid Power | Alias | Mirrors `sensor.power_meter_active_power` with the convention that positive = export, negative = import. | Source follows the documented grid sign convention. |
| `sensor.ha1_ev_charger_power` | HA1 EV Charger Power | Alias | kW → W conversion of `sensor.ehxdyl83_power`. | Represents AC-side charger draw. |
| `sensor.ha1_ev_id4_battery_level` | HA1 EV ID4 Battery Level | Alias | Mirrors `sensor.id4pro_battery_level` (%). | |
| `sensor.ha1_ev_id4_charging_power` | HA1 EV ID4 Charging Power | Alias | kW → W conversion of `sensor.id4pro_charging_power`. | |
| `sensor.ha1_flow_solar_total` | HA1 Flow – Solar Total | Raw Flow | Floored PV total (max(inverter_input_power, 0)). | |
| `sensor.ha1_flow_battery_discharge` | HA1 Flow – Battery Discharge | Raw Flow | Positive portion of battery charge/discharge sensor (W). | |
| `sensor.ha1_flow_battery_charge` | HA1 Flow – Battery Charge | Raw Flow | Magnitude of battery charging (when `sensor.battery_charge_discharge_power` < 0). | |
| `sensor.ha1_flow_grid_import` | HA1 Flow – Grid Import | Raw Flow | Positive import when `sensor.power_meter_active_power` is negative. | |
| `sensor.ha1_flow_grid_export` | HA1 Flow – Grid Export | Raw Flow | Positive export when `sensor.power_meter_active_power` is positive. | |
| `sensor.ha1_flow_house_to_ev` | HA1 Flow – House to EV | Raw Flow | Mirrors `sensor.ha1_ev_charger_power`. | Represents the AC-side path from the house bus to the charger. |
| `sensor.ha1_flow_ev_to_id4` | HA1 Flow – EV Charger to ID4 | Raw Flow | Mirrors `sensor.ha1_ev_id4_charging_power`. | |
| `sensor.ha1_flow_solar_to_house_ac` | HA1 Flow – Solar to House AC | AC Split | `min(house load, solar)`, i.e. PV used directly by the house load. | |
| `sensor.ha1_flow_solar_to_grid_ac` | HA1 Flow – Solar to Grid AC | AC Split | Takes the solar surplus (`max(solar − house, 0)`) and limits it to what is exported (`ha1_flow_grid_export`). | |
| `sensor.ha1_flow_battery_to_house_ac` | HA1 Flow – Battery to House AC | AC Split | Battery discharge used to satisfy remaining house demand after solar (`min(battery discharge, max(house − solar_to_house, 0))`). | |
| `sensor.ha1_flow_battery_to_grid_ac` | HA1 Flow – Battery to Grid AC | AC Split | The portion of battery discharge exported to grid after accounting for solar-to-house and solar-to-grid contributions plus grid export headroom. | Represents the battery → grid flow once house + solar loads are satisfied and export headroom remains. |
| `sensor.ha1_flow_battery_to_house` | HA1 Flow – Battery to House | GUI Alias | Alias to `sensor.ha1_flow_battery_to_house_ac` for compatibility with dashboards. | |
| `sensor.ha1_flow_solar_to_battery` | HA1 Flow – Solar to Battery | GUI Alias | Mirrors `sensor.ha1_flow_battery_charge`. | |
| `sensor.ha1_flow_solar_to_house` | HA1 Flow – Solar to House | GUI Alias | Alias to `sensor.ha1_flow_solar_to_house_ac`. | |

### Sign conventions

| Source | Meaning | Notes |
| --- | --- | --- |
| `sensor.power_meter_active_power` / `sensor.ha1_grid_power` | `> 0` → export, `< 0` → import | Grid import/export sensors flip the sign to show positive magnitudes per direction. |
| `sensor.battery_charge_discharge_power` / `sensor.ha1_battery_power` | `> 0` → battery discharging, `< 0` → battery charging | Converted from kW to W for downstream flows. |

