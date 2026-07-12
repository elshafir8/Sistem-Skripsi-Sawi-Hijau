#include <Fuzzy.h>
#include <DHT.h>

// --- KONFIGURASI PIN ---
#define DHTPIN 5              // Pin Data DHT
#define DHTTYPE DHT11         // Ganti menjadi DHT22 jika Anda menggunakan sensor DHT22
#define SOIL_PIN 34           // Pin Analog Soil Moisture
#define RAINDROP_PIN 35       // Pin Analog Raindrop Sensor
#define PUMP_RELAY_PIN 23      // Pin Relay Pompa

DHT dht(DHTPIN, DHTTYPE);

// Inisialisasi Objek Fuzzy
Fuzzy *fuzzy = new Fuzzy();

// Variabel Non-blocking Delay (Timer Pompa)
unsigned long pumpStartTime = 0;
float pumpDurationMs = 0;
bool isPumping = false;

// Variabel Interval Baca Sensor
unsigned long lastSensorRead = 0;
const long readInterval = 5000; // Baca sensor setiap 5 detik saat sedang standby

void setup() {
  Serial.begin(115200);
  dht.begin();
  
  pinMode(PUMP_RELAY_PIN, OUTPUT);
  digitalWrite(PUMP_RELAY_PIN, HIGH); // Asumsi Relay Active LOW (HIGH = MATI)

  setupFuzzyLogic();
  Serial.println("=== SISTEM PENYIRAMAN FUZZY (STANDALONE ESP32) DIMULAI ===");
}

void loop() {
  // 1. KONTROL TIMER POMPA (Non-blocking)
  // Jika pompa sedang menyala, blokir pembacaan sensor dan tunggu durasi habis
  if (isPumping) {
    if (millis() - pumpStartTime >= pumpDurationMs) {
      digitalWrite(PUMP_RELAY_PIN, HIGH); // Matikan pompa
      isPumping = false;
      Serial.println("STATUS: Pompa MATI. Siklus penyiraman selesai.");
      Serial.println("Menunggu siklus pembacaan berikutnya...\n");
      delay(5000); // Jeda transisi
    }
    return; // Keluar dari loop() sementara agar fokus pada timer pompa
  }

  // 2. BACA SENSOR & LOGIKA KEPUTUSAN (Setiap 5 detik)
  if (millis() - lastSensorRead >= readInterval) {
    lastSensorRead = millis();

    // A. Baca Sensor Suhu (DHT)
    float suhu = dht.readTemperature();
    if (isnan(suhu)) {
      Serial.println("[Error] Gagal membaca sensor DHT!");
      return;
    }

    // B. Baca & Kalibrasi Sensor Kelembaban Tanah
    int analogSoil = analogRead(SOIL_PIN);
    // Asumsi: 4095 = Kering Total, 1500 = Basah Total. Sesuaikan dengan nilai sensor fisik Anda!
    float kelembabanTanah = map(analogSoil, 4095, 1500, 0, 100);
    kelembabanTanah = constrain(kelembabanTanah, 0, 100);

    // C. Baca Sensor Hujan
    int analogRain = analogRead(RAINDROP_PIN);
    // Asumsi: < 2500 berarti plat terkena rintik hujan/basah
    bool isRaining = (analogRain > 2500); 

    Serial.println("----------------------------------------");
    Serial.print("Data -> Tanah: "); Serial.print(kelembabanTanah); Serial.print("% | ");
    Serial.print("Suhu: "); Serial.print(suhu); Serial.print("°C | ");
    Serial.print("Raindrop ADC: "); Serial.println(analogRain);

    // D. LOGIKA PENGAMBILAN KEPUTUSAN
    if (isRaining) {
      Serial.println("KONDISI: CUACA HUJAN TERDETEKSI!");
      Serial.println("AKSI   : Membatalkan Fuzzy Logic, Pompa tidak dinyalakan.");
    } 
    else {
      Serial.println("KONDISI: CUACA CERAH / TIDAK HUJAN");
      Serial.println("AKSI   : Menjalankan Fuzzy Logic...");

      // Masukkan nilai ke Fuzzy
      fuzzy->setInput(1, kelembabanTanah);
      fuzzy->setInput(2, suhu);
      fuzzy->fuzzify();

      // Ambil hasil Fuzzy
      float durasiMenit = fuzzy->defuzzify(1);
      
      Serial.print("HASIL  : Siram selama "); Serial.print(durasiMenit); Serial.println(" Menit");

      // E. EKSEKUSI POMPA
      if (durasiMenit > 0.5) { // Threshold minimal durasi agar pompa menyala
        // Konversi durasi ke Milidetik
        // TIPS: Untuk uji coba cepat agar tidak menunggu lama, ubah * 60.0 jadi * 1.0 (hitungan detik)
        pumpDurationMs = durasiMenit * 60.0 * 1000.0; 
        
        digitalWrite(PUMP_RELAY_PIN, LOW); // Nyalakan Pompa (Relay Active LOW)
        pumpStartTime = millis();
        isPumping = true;
        Serial.println("STATUS: Pompa MENYALA...");
      } else {
        Serial.println("STATUS: Tanah masih cukup basah, pompa standby.");
      }
    }
    Serial.println("----------------------------------------\n");
  }
}

// =========================================================
// FUNGSI INISIALISASI ATURAN FUZZY LOGIC (Sama dengan Python)
// =========================================================
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