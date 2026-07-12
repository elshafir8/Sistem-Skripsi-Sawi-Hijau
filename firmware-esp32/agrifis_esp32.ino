#include <Wire.h>
#include <WiFi.h>
#include <FirebaseESP32.h>
#include <Fuzzy.h>
#include <DHT.h>

// --- KREDENSIAL WIFI & FIREBASE ---
const char* ssid = "bayardong";
const char* password = "baik1004";
#define FIREBASE_HOST "sawi-hijau-ai-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "lbT9iGdhVDkR1zTTIvFMccryx9XorwxURnLQiYX1"

// --- KONFIGURASI PIN SENSOR & AKTUATOR ---
#define DHTPIN 15
#define DHTTYPE DHT11
#define SOIL_PIN 34
#define RAINDROP_PIN 35
#define RAINDROP_THRESHOLD 3500
#define PUMP_RELAY_PIN 13     // Pompa Penyiraman
#define SPRAYER_RELAY_PIN 32  // Sprayer Penyemprotan
#define RE 4
#define DE 4

// --- INISIALISASI SENSOR ---
DHT dht(DHTPIN, DHTTYPE);
FirebaseData firebaseData;
FirebaseData firebaseStream;
FirebaseAuth auth;
FirebaseConfig config;
Fuzzy *fuzzy = new Fuzzy();

// --- VARIABEL KONTROL ---
unsigned long pumpStartTime = 0;
float pumpDurationMs = 0;
bool isPumpingAuto = false;
bool isPumpingManual = false;
bool isSprayingManual = false;
String modeSistem = "Otomatis"; // "Otomatis" atau "Manual"
String statusTerakhir = "Kondisi Normal";

unsigned long lastSensorRead = 0;
const long readInterval = 5000;

// --- RELIABILITY / QUALITY STATE ---
const uint8_t MODBUS_MAX_RETRIES = 3;
const unsigned long MODBUS_TIMEOUT_MS = 500;
const unsigned long SENSOR_STALE_MS = 30000;

struct RsSensorState {
  float moisture = 0.0;
  float temperature = 0.0;
  float ph = 0.0;
  float nitrogen = 0.0;
  float phosphorus = 0.0;
  float potassium = 0.0;
  bool hasValid = false;
  bool validMoisture = false;
  bool validTemperature = false;
  bool validPh = false;
  bool validN = false;
  bool validP = false;
  bool validK = false;
  unsigned long lastValidMs = 0;
  uint32_t errorCount = 0;
} rsState;

float lastAirTemp = 0.0;
float lastAirHum = 0.0;
bool hasValidAirTemp = false;
bool hasValidAirHum = false;

// --- RUMUS AI (Dari logika-sensor.ino) ---
float intercept = 0.8992260008509227;
float b1_pH     = -0.018885834688324443;
float b2_Kelembaban = 0.002306144386974732;
float b3_Suhu   = -0.005514103115447958;
float b4_N      = 0.0010876113462135657;
float b5_P      = -0.0006999957241407682;
float b6_K      = 0.0002373835637035221;

// --- MODBUS UTILS ---
#define DEVICE_ADDRESS 0x01
#define READ_HOLDING_REGISTERS 0x03

uint16_t calculateCRC(uint8_t *data, uint8_t length) {
  uint16_t crc = 0xFFFF;
  for (uint8_t pos = 0; pos < length; pos++) {
    crc ^= (uint16_t)data[pos];
    for (uint8_t i = 8; i != 0; i--) {
      if ((crc & 0x0001) != 0) { crc >>= 1; crc ^= 0xA001; }
      else { crc >>= 1; }
    }
  }
  return crc;
}

bool readRegisterValidated(uint16_t reg, uint16_t &outValue) {
  uint8_t frame[8] = {
    DEVICE_ADDRESS,
    READ_HOLDING_REGISTERS,
    (uint8_t)(reg >> 8),
    (uint8_t)(reg & 0xFF),
    0x00,
    0x01
  };
  uint16_t crc = calculateCRC(frame, 6);
  frame[6] = crc & 0xFF;
  frame[7] = (crc >> 8) & 0xFF;

  for (uint8_t attempt = 0; attempt < MODBUS_MAX_RETRIES; attempt++) {
    while (Serial2.available()) {
      Serial2.read(); // flush stale bytes
    }

    digitalWrite(DE, HIGH);
    digitalWrite(RE, HIGH);
    delay(3);

    Serial2.write(frame, 8);
    Serial2.flush();

    delayMicroseconds(800);
    digitalWrite(DE, LOW);
    digitalWrite(RE, LOW);

    uint8_t res[7];
    uint8_t idx = 0;
    unsigned long st = millis();
    while (millis() - st < MODBUS_TIMEOUT_MS && idx < 7) {
      if (Serial2.available()) {
        res[idx++] = Serial2.read();
      }
    }

    if (idx != 7) {
      continue;
    }

    if (res[0] != DEVICE_ADDRESS || res[1] != READ_HOLDING_REGISTERS || res[2] != 0x02) {
      continue;
    }

    uint16_t crcResp = (uint16_t)res[6] << 8 | res[5];
    uint16_t crcCalc = calculateCRC(res, 5);
    if (crcResp != crcCalc) {
      continue;
    }

    outValue = (uint16_t)res[3] << 8 | res[4];
    return true;
  }

  return false;
}

bool readAllRsSensors() {
  uint16_t m_raw, t_raw, p_raw, n_raw, phos_raw, k_raw;
  bool okM = readRegisterValidated(0x0000, m_raw);
  bool okT = readRegisterValidated(0x0001, t_raw);
  bool okPH = readRegisterValidated(0x0003, p_raw);
  bool okN = readRegisterValidated(0x0004, n_raw);
  bool okP = readRegisterValidated(0x0005, phos_raw);
  bool okK = readRegisterValidated(0x0006, k_raw);

  rsState.validMoisture = okM;
  rsState.validTemperature = okT;
  rsState.validPh = okPH;
  rsState.validN = okN;
  rsState.validP = okP;
  rsState.validK = okK;

  if (okM) rsState.moisture = m_raw / 10.0;
  if (okT) rsState.temperature = (int16_t)t_raw / 10.0;
  if (okPH) rsState.ph = p_raw / 10.0;
  if (okN) rsState.nitrogen = (float)n_raw;
  if (okP) rsState.phosphorus = (float)phos_raw;
  if (okK) rsState.potassium = (float)k_raw;

  bool allValid = okM && okT && okPH && okN && okP && okK;
  if (allValid) {
    rsState.hasValid = true;
    rsState.lastValidMs = millis();
  } else {
    rsState.errorCount++;
  }

  return allValid;
}

// --- SETUP FUZZY (Dari punya-dimas.ino) ---
void setupFuzzyLogic() {
  // 1. INPUT 1: Kelembaban Tanah (0 - 100%)
  FuzzyInput *fuzzyKelembaban = new FuzzyInput(1);
  FuzzySet *kering = new FuzzySet(0, 0, 0, 50);
  FuzzySet *lembab = new FuzzySet(45, 65, 65, 85);
  FuzzySet *sangat_lembab = new FuzzySet(75, 100, 100, 100);
  fuzzyKelembaban->addFuzzySet(kering);
  fuzzyKelembaban->addFuzzySet(lembab);
  fuzzyKelembaban->addFuzzySet(sangat_lembab);
  fuzzy->addFuzzyInput(fuzzyKelembaban);

  // 2. INPUT 2: Suhu Udara (0 - 40°C)
  FuzzyInput *fuzzySuhu = new FuzzyInput(2);
  FuzzySet *dingin = new FuzzySet(0, 0, 0, 26);
  FuzzySet *sedangSuhu = new FuzzySet(20, 25, 25, 30);
  FuzzySet *panas = new FuzzySet(28, 35, 35, 40);
  fuzzySuhu->addFuzzySet(dingin);
  fuzzySuhu->addFuzzySet(sedangSuhu);
  fuzzySuhu->addFuzzySet(panas);
  fuzzy->addFuzzyInput(fuzzySuhu);

  // 3. OUTPUT: Durasi Pompa (0 - 30 Menit)
  FuzzyOutput *fuzzyDurasi = new FuzzyOutput(1);
  FuzzySet *singkat = new FuzzySet(0, 0, 0, 10);
  FuzzySet *sedangDurasi = new FuzzySet(10, 15, 15, 20);
  FuzzySet *lama = new FuzzySet(20, 30, 30, 30);
  fuzzyDurasi->addFuzzySet(singkat);
  fuzzyDurasi->addFuzzySet(sedangDurasi);
  fuzzyDurasi->addFuzzySet(lama);
  fuzzy->addFuzzyOutput(fuzzyDurasi);

  // 4. RULE BASE (9 Aturan)
  // R1: Kering & Dingin -> Sedang
  FuzzyRuleAntecedent *ifKerAndDin = new FuzzyRuleAntecedent();
  ifKerAndDin->joinWithAND(kering, dingin);
  FuzzyRuleConsequent *thenSedang1 = new FuzzyRuleConsequent();
  thenSedang1->addOutput(sedangDurasi);
  fuzzy->addFuzzyRule(new FuzzyRule(1, ifKerAndDin, thenSedang1));

  // R2: Kering & Sedang -> Lama
  FuzzyRuleAntecedent *ifKerAndSed = new FuzzyRuleAntecedent();
  ifKerAndSed->joinWithAND(kering, sedangSuhu);
  FuzzyRuleConsequent *thenLama1 = new FuzzyRuleConsequent();
  thenLama1->addOutput(lama);
  fuzzy->addFuzzyRule(new FuzzyRule(2, ifKerAndSed, thenLama1));

  // R3: Kering & Panas -> Lama
  FuzzyRuleAntecedent *ifKerAndPan = new FuzzyRuleAntecedent();
  ifKerAndPan->joinWithAND(kering, panas);
  FuzzyRuleConsequent *thenLama2 = new FuzzyRuleConsequent();
  thenLama2->addOutput(lama);
  fuzzy->addFuzzyRule(new FuzzyRule(3, ifKerAndPan, thenLama2));

  // R4: Lembab & Dingin -> Singkat
  FuzzyRuleAntecedent *ifLemAndDin = new FuzzyRuleAntecedent();
  ifLemAndDin->joinWithAND(lembab, dingin);
  FuzzyRuleConsequent *thenSingkat1 = new FuzzyRuleConsequent();
  thenSingkat1->addOutput(singkat);
  fuzzy->addFuzzyRule(new FuzzyRule(4, ifLemAndDin, thenSingkat1));

  // R5: Lembab & Sedang -> Sedang
  FuzzyRuleAntecedent *ifLemAndSed = new FuzzyRuleAntecedent();
  ifLemAndSed->joinWithAND(lembab, sedangSuhu);
  FuzzyRuleConsequent *thenSedang2 = new FuzzyRuleConsequent();
  thenSedang2->addOutput(sedangDurasi);
  fuzzy->addFuzzyRule(new FuzzyRule(5, ifLemAndSed, thenSedang2));

  // R6: Lembab & Panas -> Sedang
  FuzzyRuleAntecedent *ifLemAndPan = new FuzzyRuleAntecedent();
  ifLemAndPan->joinWithAND(lembab, panas);
  FuzzyRuleConsequent *thenSedang3 = new FuzzyRuleConsequent();
  thenSedang3->addOutput(sedangDurasi);
  fuzzy->addFuzzyRule(new FuzzyRule(6, ifLemAndPan, thenSedang3));

  // R7: Sangat Lembab & Dingin -> Singkat
  FuzzyRuleAntecedent *ifSLemAndDin = new FuzzyRuleAntecedent();
  ifSLemAndDin->joinWithAND(sangat_lembab, dingin);
  FuzzyRuleConsequent *thenSingkat2 = new FuzzyRuleConsequent();
  thenSingkat2->addOutput(singkat);
  fuzzy->addFuzzyRule(new FuzzyRule(7, ifSLemAndDin, thenSingkat2));

  // R8: Sangat Lembab & Sedang -> Singkat
  FuzzyRuleAntecedent *ifSLemAndSed = new FuzzyRuleAntecedent();
  ifSLemAndSed->joinWithAND(sangat_lembab, sedangSuhu);
  FuzzyRuleConsequent *thenSingkat3 = new FuzzyRuleConsequent();
  thenSingkat3->addOutput(singkat);
  fuzzy->addFuzzyRule(new FuzzyRule(8, ifSLemAndSed, thenSingkat3));

  // R9: Sangat Lembab & Panas -> Singkat
  FuzzyRuleAntecedent *ifSLemAndPan = new FuzzyRuleAntecedent();
  ifSLemAndPan->joinWithAND(sangat_lembab, panas);
  FuzzyRuleConsequent *thenSingkat4 = new FuzzyRuleConsequent();
  thenSingkat4->addOutput(singkat);
  fuzzy->addFuzzyRule(new FuzzyRule(9, ifSLemAndPan, thenSingkat4));
}

void streamCallback(StreamData data) {
  String path = data.dataPath();
  if (path == "/pompa") {
    isPumpingManual = data.boolData();
    if (modeSistem == "Manual") {
      digitalWrite(PUMP_RELAY_PIN, isPumpingManual ? LOW : HIGH);
    }
  } else if (path == "/sprayer") {
    isSprayingManual = data.boolData();
    digitalWrite(SPRAYER_RELAY_PIN, isSprayingManual ? LOW : HIGH);
  } else if (path == "/mode_sistem") {
    String newMode = data.stringData();
    if (newMode != modeSistem) {
      modeSistem = newMode;
      // Pembersihan state/data ketika berganti mode (Cleaning data)
      digitalWrite(PUMP_RELAY_PIN, HIGH);
      digitalWrite(SPRAYER_RELAY_PIN, HIGH);
      isPumpingAuto = false;
      isPumpingManual = false;
      isSprayingManual = false;

      // Sinkronisasi status di Firebase
      Firebase.setBool(firebaseData, "/controls/pompa", false);
      Firebase.setBool(firebaseData, "/controls/sprayer", false);
      Serial.println("TRANSISI MODE: Sistem beralih ke " + modeSistem + ". Seluruh perangkat dimatikan & state dibersihkan!");
    }
  }
}

void setup() {
  Serial.begin(115200);
  Serial2.begin(4800, SERIAL_8N1, 16, 17);
  dht.begin();

  pinMode(RE, OUTPUT); pinMode(DE, OUTPUT);
  pinMode(PUMP_RELAY_PIN, OUTPUT);
  pinMode(SPRAYER_RELAY_PIN, OUTPUT);
  digitalWrite(PUMP_RELAY_PIN, HIGH);
  digitalWrite(SPRAYER_RELAY_PIN, HIGH);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }

  config.host = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Setup Stream for real-time control
  if (!Firebase.beginStream(firebaseStream, "/controls")) {
    Serial.println("Stream begin error: " + firebaseStream.errorReason());
  }
  Firebase.setStreamCallback(firebaseStream, streamCallback, [](bool timeout){});

  setupFuzzyLogic();

  // Persiapan data bersih awal (Boot-up Data Preparation)
  Firebase.setBool(firebaseData, "/controls/pompa", false);
  Firebase.setBool(firebaseData, "/controls/sprayer", false);
  Serial.println("=== SMART AGRIFIS UNIFIED FIRMWARE STARTED (DATA PREPARED) ===");
}

void loop() {
  // 1. KONTROL OTOMATIS POMPA (Fuzzy)
  if (modeSistem == "Otomatis" && isPumpingAuto) {
    if (millis() - pumpStartTime >= pumpDurationMs) {
      digitalWrite(PUMP_RELAY_PIN, HIGH);
      isPumpingAuto = false;
      // Pembersihan state kontrol pompa di Firebase
      Firebase.setBool(firebaseData, "/controls/pompa", false);
      Serial.println("AUTO: Pompa MATI (Durasi selesai). State dibersihkan.");
    }
  }

  // 2. BACA SENSOR & UPDATE FIREBASE
  if (millis() - lastSensorRead >= readInterval) {
    lastSensorRead = millis();

    // A. Read Modbus RS sensor with reliability layer
    bool rsAllValidNow = readAllRsSensors();
    bool sensorDataFresh = rsState.hasValid && (millis() - rsState.lastValidMs <= SENSOR_STALE_MS);

    float moisture = rsState.moisture;
    float temperature = rsState.temperature;
    float ph = rsState.ph;
    float nitrogen = rsState.nitrogen;
    float phosphorus = rsState.phosphorus;
    float potassium = rsState.potassium;

    // B. Read Air Sensors (with last-valid fallback)
    float airTempRead = dht.readTemperature();
    float airHumRead = dht.readHumidity();

    bool airTempValidNow = !isnan(airTempRead);
    bool airHumValidNow = !isnan(airHumRead);

    if (airTempValidNow) {
      lastAirTemp = airTempRead;
      hasValidAirTemp = true;
    }
    if (airHumValidNow) {
      lastAirHum = airHumRead;
      hasValidAirHum = true;
    }

    float airTemp = hasValidAirTemp ? lastAirTemp : 0.0;
    float airHum = hasValidAirHum ? lastAirHum : 0.0;

    int analogRain = analogRead(RAINDROP_PIN);
    bool isRaining = analogRain < RAINDROP_THRESHOLD;
    float durasiMenit = 0.0;

    // Jika ada hujan, hentikan pompa bila sedang hidup
    if (isRaining && (isPumpingAuto || isPumpingManual)) {
      digitalWrite(PUMP_RELAY_PIN, HIGH);
      isPumpingAuto = false;
      isPumpingManual = false;
      Firebase.setBool(firebaseData, "/controls/pompa", false);
      Serial.println("RAIN CUTOFF: Hujan terdeteksi, pompa dimatikan paksa.");
    }

    // C. AI Logic (only trusted if RS data is fresh)
    float indeksFinal = 0.0;
    float persentase = 0.0;
    String status = "DATA SENSOR TIDAK VALID";
    if (sensorDataFresh) {
      float indeksRaw = intercept + (b1_pH * ph) + (b2_Kelembaban * moisture) + (b3_Suhu * temperature) + (b4_N * nitrogen) + (b5_P * phosphorus) + (b6_K * potassium);
      indeksFinal = constrain(indeksRaw, 0.0, 1.0);
      persentase = indeksFinal * 100.0;
      status = (indeksFinal >= 0.75) ? "LAYAK" : (indeksFinal >= 0.50 ? "KURANG LAYAK" : "TIDAK LAYAK");
    }

    // --- LOGIKA REKOMENDASI & NOTIFIKASI ---
    String waspada = "Kondisi Normal";
    String rekomendasi = "Pertahankan kualitas tanah.";

    if (ph < 6.0) {
      waspada = "pH Terlalu Asam!";
      rekomendasi = "Tambahkan kapur dolomit untuk menaikkan pH.";
    } else if (ph > 7.0) {
      waspada = "pH Terlalu Basa!";
      rekomendasi = "Tambahkan belerang atau bahan organik.";
    } else if (nitrogen < 50) {
      waspada = "Nitrogen Rendah!";
      rekomendasi = "Berikan pupuk Urea atau NPK tinggi Nitrogen.";
    } else if (nitrogen > 125) {
      waspada = "Nitrogen Berlebih!";
      rekomendasi = "Kurangi pemupukan Nitrogen, siram dengan air bersih.";
    } else if (moisture < 50.0) {
      waspada = "Tanah Kering!";
      rekomendasi = "Lakukan penyiraman segera.";
    } else if (moisture > 70.0) {
      waspada = "Tanah Terlalu Basah!";
      rekomendasi = "Perbaiki drainase agar akar tidak busuk.";
    }

    if (waspada != "Kondisi Normal" && waspada != statusTerakhir) {
      FirebaseJson notif;
      notif.set("title", waspada);
      notif.set("message", rekomendasi);
      notif.set("timestamp", (double)millis());
      if (Firebase.pushJSON(firebaseData, "/notifications", notif)) {
        statusTerakhir = waspada;
        Serial.println("NOTIFIKASI: Berhasil dikirim ke Firebase.");
      }
    } else if (waspada == "Kondisi Normal") {
      statusTerakhir = "Kondisi Normal";
    }

    // D. Fuzzy Execution (Hanya jika Auto, tidak hujan, dan data RS fresh)
    if (modeSistem == "Otomatis" && !isRaining && sensorDataFresh) {
      if (moisture >= 70.0) {
        // Safety Cutoff: Jika tanah terdeteksi basah (>= 70%), matikan pompa seketika dan bersihkan data
        if (isPumpingAuto) {
          digitalWrite(PUMP_RELAY_PIN, HIGH);
          isPumpingAuto = false;
          Firebase.setBool(firebaseData, "/controls/pompa", false);
          Serial.println("AUTO CUTOFF: Tanah BASAH (>= 70.0%). Pompa dimatikan paksa & state dibersihkan.");
        }
      } else if (!isPumpingAuto) {
        // Hanya jalankan fuzzy jika tanah kering (< 70.0%) dan pompa sedang tidak aktif
        fuzzy->setInput(1, moisture);
        fuzzy->setInput(2, airTemp);
        fuzzy->fuzzify();
        durasiMenit = fuzzy->defuzzify(1);

        if (durasiMenit > 0.5) {
          pumpDurationMs = durasiMenit * 60.0 * 1000.0;
          digitalWrite(PUMP_RELAY_PIN, LOW);
          pumpStartTime = millis();
          isPumpingAuto = true;
          Serial.println("AUTO START: Pompa menyala via Fuzzy. Durasi (menit): " + String(durasiMenit));
        }
      }
    }

    // Fail-safe jika data sensor stale/invalid saat mode otomatis
    if (modeSistem == "Otomatis" && !sensorDataFresh && (isPumpingAuto || isPumpingManual)) {
      digitalWrite(PUMP_RELAY_PIN, HIGH);
      isPumpingAuto = false;
      isPumpingManual = false;
      Firebase.setBool(firebaseData, "/controls/pompa", false);
      Serial.println("FAILSAFE: Data RS stale/invalid, pompa dimatikan demi keamanan.");
    }

    // E. Push to Firebase
    FirebaseJson data;
    data.set("ph", ph);
    data.set("kelembaban", moisture);
    data.set("suhu", temperature);
    data.set("suhu_udara", airTemp);
    data.set("kelembaban_udara", airHum);
    data.set("n", nitrogen);
    data.set("p", phosphorus);
    data.set("k", potassium);
    data.set("indeks", indeksFinal);
    data.set("persentase", persentase);
    data.set("status", status);
    data.set("waspada", waspada);
    data.set("rekomendasi", rekomendasi);
    data.set("raindrop_adc", analogRain);
    data.set("raindrop_threshold", RAINDROP_THRESHOLD);
    data.set("is_raining", isRaining);
    data.set("rain_status", isRaining ? "Hujan" : "Tidak Hujan");
    data.set("fuzzy_duration", durasiMenit);
    data.set("fuzzy_enabled", modeSistem == "Otomatis" && !isRaining && sensorDataFresh);
    data.set("sensor_rs_valid", rsAllValidNow);
    data.set("sensor_data_fresh", sensorDataFresh);
    data.set("sensor_rs_error_count", (int)rsState.errorCount);
    data.set("moisture_valid", rsState.validMoisture);
    data.set("soil_temp_valid", rsState.validTemperature);
    data.set("ph_valid", rsState.validPh);
    data.set("n_valid", rsState.validN);
    data.set("p_valid", rsState.validP);
    data.set("k_valid", rsState.validK);
    data.set("air_temp_valid", hasValidAirTemp);
    data.set("air_hum_valid", hasValidAirHum);
    data.set("mode_sistem", modeSistem);
    data.set("pompa_aktif", isPumpingAuto || isPumpingManual);
    data.set("sprayer_aktif", isSprayingManual);

    // Audit log sensor dan status untuk Serial Monitor
    Serial.println("--- SENSOR AUDIT ---");
    Serial.printf("moisture=%.1f temp=%.1f airTemp=%.1f airHum=%.1f pH=%.1f N=%.1f P=%.1f K=%.1f\n", moisture, temperature, airTemp, airHum, ph, nitrogen, phosphorus, potassium);
    Serial.printf("rainADC=%d threshold=%d isRaining=%s rain_status=%s\n", analogRain, RAINDROP_THRESHOLD, isRaining ? "YES" : "NO", isRaining ? "HUJAN" : "TIDAK HUJAN");
    Serial.printf("fuzzyEnabled=%s fuzzyDuration=%.2f mode=%s pompaAuto=%s pompaManual=%s\n", (modeSistem == "Otomatis" && !isRaining && sensorDataFresh) ? "YES" : "NO", durasiMenit, modeSistem.c_str(), isPumpingAuto ? "YES" : "NO", isPumpingManual ? "YES" : "NO");
    Serial.printf("rsValidNow=%s fresh=%s errCount=%lu\n", rsAllValidNow ? "YES" : "NO", sensorDataFresh ? "YES" : "NO", (unsigned long)rsState.errorCount);
    Serial.printf("indeks=%.3f persentase=%.1f status=%s waspada=%s\n", indeksFinal, persentase, status.c_str(), waspada.c_str());

    if (Firebase.setJSON(firebaseData, "/monitoring_sawi", data)) {
      Serial.println("BERHASIL: Data masuk ke Firebase!");
    } else {
      Serial.println("GAGAL: " + firebaseData.errorReason());
    }

    // F. Log History if needed (Simplified for now)
    if (millis() % 3600000 < readInterval) { // Once an hour roughly
      if(Firebase.pushJSON(firebaseData, "/riwayat_harian", data)) {
        Serial.println("BERHASIL: History harian tersimpan!");
      } else {
        Serial.println("GAGAL HISTORY: " + firebaseData.errorReason());
      }
    }
  } // Penutup blok 'if (millis() - lastSensorRead >= readInterval)'
} // Penutup 'void loop()'