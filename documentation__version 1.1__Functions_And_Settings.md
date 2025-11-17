# ⚙️ Functions & Settings
### *HomeAssistant 1.1 – System Rules & Control Logic*  

Detta dokument definierar de grundläggande reglerna och funktionerna som styr hur hela energisystemet beter sig i HomeAssistant 1.1.  
Syftet är att skapa ett intelligent, självlärande och automatiserat energiflöde där elpris, väder, närvaro och effektavgifter beaktas för att minimera kostnader och maximera effektivitet.

---

## 🔌 EV Charger – Rules & Logic  
**Goal:**  
Ensure vehicle is fully charged before required departure time while minimizing cost and avoiding peak-power penalties.

**Conditions:**  
- **Weekdays:** Charging complete by 06:00  
- **Weekends:** Charging complete by 10:00  
- **Calculation basis:**  
  - Needed energy = (100 % − current SoC) × battery capacity (kWh)  
  - Evaluate Nordpool price forecast for upcoming hours  
  - Schedule charging during cheapest possible hours while staying below `input_number.peak_power_limit`  

**Additional logic:**  
- Estimate charge time = needed kWh / charger power (kW)  
- Dynamically adjust if new price data arrives, car status changes or load rises  

**Inputs / Entities:**  
`sensor.easee_status`, `sensor.easee_power`, `sensor.id4_battery_level`,  
`sensor.nordpool_kwh_se3_sek_2_095_025`, `input_number.peak_power_limit`,  
`input_boolean.ev_home`  
Service → `easee.action_command` (start/stop/toggle/pause/resume)

**Outputs / Actions:**  
- Start only under favorable price and load conditions  
- Stop or pause when thresholds exceeded  
- Ensure SoC ≥ target before deadline  

---

## 🔋 Huawei Battery – Rules & Logic  
**Goal:**  
Act as dynamic energy balancer – charge when cheap/available, discharge when prices or load peak – without depleting reserves.

**Behavior:**  
- **Charge priorities:**  
  1. Solar surplus (always first)  
  2. Grid charging when price ≤ `input_number.battery_low_price_threshold` and peak risk is low  
- **Discharge when:**  
  - Price ≥ high threshold or load > `input_number.peak_power_limit`  
  - But preserve reserve before known peak/expensive periods  
- **Avoid powering EV alone**, but may assist briefly to avoid peak  
- **Temporal awareness:**  
  - Weekday mornings (05–09) and evenings (16–22) are typically expensive → maintain SoC reserve  
- **Adaptive learning:** create time-based profiles of peak risk and price  

**Inputs / Entities:**  
`sensor.battery_state_of_capacity`, `sensor.huawei_battery_power`,  
`sensor.huawei_battery_import_export`, `sensor.nordpool_kwh_se3_sek_2_095_025`,  
`sensor.solar_power_production`, `input_number.peak_power_limit`,  
`input_number.battery_low_price_threshold`, `input_number.battery_high_price_threshold`,  
`input_number.battery_reserve_threshold`, service `huawei_solar.set_operation_mode`

**Outputs / Actions:**  
- Charge from solar → grid → cheap hours  
- Discharge during expensive or peak risk  
- Preserve strategic reserve  
- Learn patterns for next-day planning  

---

## ☀️ Huawei Solar – Rules & Logic  
**Goal:**  
Maximize local solar usage, prioritize house and EV before export, and plan using weather and price forecast.

**Behavior:**  
- Priority: House → EV → Battery → Grid (export only if high price and full SoC)  
- Use weather forecast to predict solar yield and adjust plans  
- Export only if battery SoC ≥ reserve and price ≥ high export threshold  
- Learn daily solar patterns for adaptive planning  

**Inputs / Entities:**  
`sensor.solar_power_production`, `sensor.weather_forecast_solar_radiation`,  
`sensor.nordpool_kwh_se3_sek_2_095_025`, `sensor.battery_state_of_capacity`,  
`sensor.easee_status`, `input_number.peak_power_limit`,  
`input_number.solar_export_high_price_threshold`, `input_boolean.ev_home`

**Outputs / Actions:**  
- Prioritize local consumption  
- Dynamically allocate solar between house, EV and battery  
- Export only when beneficial  
- Feed forecast into other modules  

---

## 🏠 House – Major Consumers  
**Goal:**  
Include and control large loads (spis, tvätt, tork, golvvärme m.fl.) to avoid high prices and peak loads.

**Behavior:**  
- Monitor price and total load  
- If price > high threshold or load ≥ `input_number.peak_power_limit`:  
  - Temporarily turn off/reduce controllable devices  
  - Notify user for manual actions if no automation exists  
- Learn usage patterns for each device  
- Coordinate with peak and battery modules  

**Inputs / Entities:**  
`sensor.total_power_usage`, `sensor.floor_heating_toilet_power`,  
`switch.floor_heating_toilet`, `sensor.nordpool_kwh_se3_sek_2_095_025`,  
`input_number.peak_power_limit`, `input_number.high_price_threshold`

**Outputs / Actions:**  
- Reduce load automatically  
- Send manual advice notifications  
- Log events for adaptive learning  
- Restore when safe  

---

## 📉 Peak Shaving – Rules & Logic  
**Goal:**  
Minimize monthly peak fee by smoothing power usage and coordinating all major systems.

**Behavior:**  
- Fee based on highest 15-min/hourly power of the month  
- **Night-time rule:** Between 22:00 – 06:00 only **50 %** of power counts toward peak.  
  - System allows higher loads ( EV / battery charging ) in that window  
  - Forecast and learning weight nighttime consumption × 0.5  
- Base limit set by `input_number.peak_power_limit`, auto-adjust over time  
- Use forecasts and weather to plan distribution  
- Coordinate across: EV 🔌, Battery 🔋, Solar ☀️, House 🏠  
- Predict future peaks and suggest adjustments  
- Manual override always possible  

**Inputs / Entities:**  
`sensor.total_power_usage`, `sensor.total_power_peak_month`,  
`sensor.nordpool_kwh_se3_sek_2_095_025`, `sensor.weather_forecast_solar_radiation`,  
`input_number.peak_power_limit`, `input_boolean.peak_auto_adjust`,  
`input_number.peak_margin_warning`, `input_datetime.peak_night_start`,  
`input_datetime.peak_night_end`  
Services → `notify.mobile_app_micke`, `tts.hallway_speaker`

**Outputs / Actions:**  
- Adjust threshold automatically (learning mode)  
- Warn when load ≥ (limit − margin)  
- Apply 0.5× weight at night  
- Limit loads or discharge battery during risk  
- Log and analyze peak events  

---

## 💰 Electricity Price (Nordpool) – Rules & Logic  
**Goal:**  
Provide forecast and trend learning for dynamic price-based automation across the system.

**Behavior:**  
- Source = `sensor.nordpool_kwh_se3_sek_2_095_025` (+ forecast entity)  
- Learn recurring patterns: cheaper at night, weekends, holidays  
- Combine with weather forecast (wind + solar radiation) → predict price trends  
- Feed into EV, Battery, Solar and Peak planning  
- Keep rolling 30-day dataset for trend accuracy  
- Auto-adjust `input_number.battery_low_price_threshold` and `high_price_threshold`  
- Generate advisories like “Expected low price 02–05 tomorrow”  

**Inputs / Entities:**  
`sensor.nordpool_kwh_se3_sek_2_095_025`, `sensor.nordpool_next_day_forecast`,  
`sensor.weather_forecast_wind_speed`, `sensor.weather_forecast_solar_radiation`,  
`input_number.battery_low_price_threshold`, `input_number.battery_high_price_threshold`

**Outputs / Actions:**  
- Supply forecast data to all modules  
- Adjust thresholds automatically  
- Notify of price windows  
- Feed learning data to adaptive AI  

---

### 🔄 Summary of Inter-Function Dependencies  
| Function | Uses Price Data | Uses Forecast | Peak Aware | Learns Over Time |  
|:--|:--:|:--:|:--:|:--:|  
| EV Charger | ✅ | ✅ | ✅ | ⚙️ |  
| Huawei Battery | ✅ | ✅ | ✅ | ✅ |  
| Huawei Solar | ✅ | ✅ | ✅ | ✅ |  
| House Consumers | ✅ | ⚙️ | ✅ | ✅ |  
| Peak Shaving | ✅ | ✅ | ✅ | ✅ |  
| Electricity Price | — | ✅ | — | ✅ |  
