#include <Wire.h>
#include <WiFi.h>
#include <FirebaseESP32.h>

// --- KREDENSIAL ---
const char* ssid = "asistenaja"; 
const char* password = "digidawpalingcool";
#define FIREBASE_HOST "sawi-hijau-ai-default-rtdb.asia-southeast1.firebasedatabase.app" 
#define FIREBASE_AUTH "lbT9iGdhVDkR1zTTIvFMccryx9XorwxURnLQiYX1"

// --- RUMUS AI ---
float intercept = 1.3540661768439446;
float b1_pH     = -0.10018997638481783;
float b2_Kelembaban = 0.003114008062571186;
float b3_Suhu   = -0.021093610481366976;
float b4_N      = 0.002340050368814537;
float b5_P      = -0.0006617458686423139;
float b6_K      = 0.0014593174684289696;

#define RE 4 
#define DE 4 
#define DEVICE_ADDRESS 0x01
#define READ_HOLDING_REGISTERS 0x03

FirebaseData firebaseData;
FirebaseAuth auth;
FirebaseConfig config;

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

uint16_t readRegister(uint16_t reg) {
  uint8_t frame[8] = {DEVICE_ADDRESS, READ_HOLDING_REGISTERS, (uint8_t)(reg >> 8), (uint8_t)(reg & 0xFF), 0x00, 0x01};
  uint16_t crc = calculateCRC(frame, 6);
  frame[6] = crc & 0xFF; frame[7] = (crc >> 8) & 0xFF;

  digitalWrite(DE, HIGH); digitalWrite(RE, HIGH);
  delay(5); // Ditambah sedikit untuk kestabilan chip MAX485
  Serial2.write(frame, 8);
  Serial2.flush();
  delayMicroseconds(500);
  digitalWrite(DE, LOW); digitalWrite(RE, LOW);

  uint8_t res[20]; uint8_t idx = 0; 
  unsigned long st = millis();
  while (millis() - st < 500 && idx < 7) { // Timeout dipercepat ke 500ms
    if (Serial2.available()) res[idx++] = Serial2.read();
  }
  return (idx >= 7) ? (res[3] << 8) | res[4] : 0xFFFF;
}

void setup() {
  Serial.begin(115200);
  Serial2.begin(4800, SERIAL_8N1, 16, 17); 
  pinMode(RE, OUTPUT); pinMode(DE, OUTPUT);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  
  config.host = FIREBASE_HOST;
  config.signer.tokens.legacy_token = FIREBASE_AUTH;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

String statusTerakhir = "Kondisi Normal"; // Taruh di atas void setup

void loop() {
  // --- A. BACA DATA SENSOR (Ditambah delay antar pembacaan agar sensor tidak hang) ---
  uint16_t m_raw = readRegister(0x0000); delay(200);
  uint16_t t_raw = readRegister(0x0001); delay(200);
  uint16_t p_raw = readRegister(0x0003); delay(200);
  uint16_t n_raw = readRegister(0x0004); delay(200);
  uint16_t phos_raw = readRegister(0x0005); delay(200);
  uint16_t k_raw = readRegister(0x0006); delay(200);

  // --- B. KONVERSI DATA ---
  float moisture = (m_raw != 0xFFFF) ? m_raw / 10.0 : 0.0;
  float temperature = (t_raw != 0xFFFF) ? (int16_t)t_raw / 10.0 : 0.0;
  float ph = (p_raw != 0xFFFF) ? p_raw / 10.0 : 0.0;
  float nitrogen = (n_raw != 0xFFFF) ? (float)n_raw : 0.0;
  float phosphorus = (phos_raw != 0xFFFF) ? (float)phos_raw : 0.0;
  float potassium = (k_raw != 0xFFFF) ? (float)k_raw : 0.0;

  // --- C. LOGIKA AI ---
  float indeksRaw = intercept + (b1_pH * ph) + (b2_Kelembaban * moisture) + (b3_Suhu * temperature) + (b4_N * nitrogen) + (b5_P * phosphorus) + (b6_K * potassium);

  float indeksFinal = constrain(indeksRaw, 0.0, 1.0); 
  float persentase = indeksFinal * 100.0;
  String status = (indeksFinal >= 0.75) ? "LAYAK" : (indeksFinal >= 0.5 ? "KURANG LAYAK" : "TIDAK LAYAK");

 // --- D. LOGIKA REKOMENDASI IDEAL ---
  String waspada = "Kondisi Normal";
  String rekomendasi = "Pertahankan kualitas tanah.";

  // Cek pH (Ideal 6.0 - 7.0)
  if (ph < 6.0) {
    waspada = "pH Terlalu Asam!";
    rekomendasi = "Tambahkan kapur dolomit untuk menaikkan pH.";
  } else if (ph > 7.0) {
    waspada = "pH Terlalu Basa!";
    rekomendasi = "Tambahkan belerang atau bahan organik.";
  } 
  // Cek Nitrogen (Ideal 50 - 125)
  else if (nitrogen < 50) {
    waspada = "Nitrogen Rendah!";
    rekomendasi = "Berikan pupuk Urea atau NPK tinggi Nitrogen.";
  } else if (nitrogen > 125) {
    waspada = "Nitrogen Berlebih!";
    rekomendasi = "Kurangi pemupukan Nitrogen, siram dengan air bersih.";
  }
  // Cek Kelembaban (Ideal 50% - 70%)
  else if (moisture < 50.0) {
    waspada = "Tanah Kering!";
    rekomendasi = "Lakukan penyiraman segera.";
  } else if (moisture > 70.0) {
    waspada = "Tanah Terlalu Basah!";
    rekomendasi = "Perbaiki drainase agar akar tidak busuk.";
  }

  // Kita hanya mengirim notifikasi jika kondisi TIDAK Normal
  if (waspada != "Kondisi Normal") {
    FirebaseJson notif;
    notif.set("title", waspada);           // Mengambil pesan waspada (misal: "Tanah Kering!")
    notif.set("message", rekomendasi);     // Mengambil saran (misal: "Lakukan penyiraman segera.")
    notif.set("date", "09 Mei 2026");      // Kamu bisa ganti dengan fungsi tanggal otomatis nanti
    notif.set("timestamp", millis());      // Gunakan millis atau server timestamp untuk urutan

    // Menggunakan pushJSON agar setiap notifikasi punya ID unik dan tidak menimpa yang lama
    if (Firebase.pushJSON(firebaseData, "/notifications", notif)) {
      Serial.println("Notifikasi Otomatis Terkirim! 🔔");
    }
  }

  if (waspada != "Kondisi Normal" && waspada != statusTerakhir) {
    FirebaseJson notif;
    notif.set("title", waspada);
    notif.set("message", rekomendasi);
    notif.set("date", "09 Mei 2026");
    notif.set("timestamp", millis());

    if (Firebase.pushJSON(firebaseData, "/notifications", notif)) {
      statusTerakhir = waspada; // Simpan status agar tidak kirim terus-menerus
      Serial.println("Notifikasi Baru Terkirim!");
    }
  } else if (waspada == "Kondisi Normal") {
    statusTerakhir = "Kondisi Normal";
  }
  
  // --- E. KIRIM KE FIREBASE ---
  if (WiFi.status() == WL_CONNECTED) {
    FirebaseJson updateData; // Dibuat di dalam loop agar fresh
    updateData.set("ph", ph);
    updateData.set("kelembaban", moisture);
    updateData.set("suhu", temperature);
    updateData.set("n", nitrogen);
    updateData.set("p", phosphorus);
    updateData.set("k", potassium);
    updateData.set("indeks", indeksFinal);
    updateData.set("persentase", persentase);
    updateData.set("status", status);
    updateData.set("waspada", waspada);
    updateData.set("rekomendasi", rekomendasi);

    if (Firebase.setJSON(firebaseData, "/monitoring_sawi", updateData)) {
      Serial.println("Data Terkirim ✅");
    } else {
      Serial.println("Gagal ❌: " + firebaseData.errorReason());
    }
  }

  delay(5000); 
}