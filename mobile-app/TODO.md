# Task TODO - RS Sensor Reliability Fix

- [x] Harden Arduino Modbus RS read reliability in `unified_agrifis/unified_agrifis.ino`
  - [x] Add strict Modbus response validation (address, function, byte count, CRC)
  - [x] Add retry mechanism and timeout handling
  - [x] Add last-valid cache for RS sensor values
  - [x] Add validity/freshness flags and publish to Firebase
  - [x] Prevent invalid reads from being pushed as misleading zeroes
  - [x] Improve DHT NaN handling with last-valid fallback
  - [x] Add fail-safe behavior when sensor data is stale/invalid

- [x] Fix app data consumption in `lib/screens/penyemprotan_screen.dart`
  - [x] Use `suhu_udara` for spray recommendation
  - [x] Read reliability flags from Firebase
  - [x] Show warning UI when sensor data is stale/invalid
  - [x] Guard manual spraying action based on mode/data reliability

- [x] Fix app data consumption in `lib/screens/penyiraman_screen.dart`
  - [x] Read reliability flags from Firebase
  - [x] Show stale/invalid sensor warning state
  - [x] Avoid misleading condition/progress when data is not fresh/valid

- [ ] Run validation
  - [ ] `flutter analyze`

- [x] Update TODO completion state
