import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // Wajib ditambahkan
import 'package:firebase_core/firebase_core.dart';
import '../main.dart' show kFirebaseDatabaseUrl;

class PenyemprotanScreen extends StatefulWidget {
  const PenyemprotanScreen({super.key});

  @override
  State<PenyemprotanScreen> createState() => _PenyemprotanScreenState();
}

class _PenyemprotanScreenState extends State<PenyemprotanScreen> {
  int selectedDuration = 5;

  @override
  Widget build(BuildContext context) {
    const Color greenTheme = Color(0xFF2D5A27);

    return Scaffold(
      backgroundColor: const Color.fromARGB(190, 91, 126, 60),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFE0E0E0),
              radius: 18,
              backgroundImage: AssetImage('assets/petani.jpg'),
            ),
            const SizedBox(width: 10),
            const Text(
              'Smart AgriFIS',
              style: TextStyle(color: greenTheme, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),

      // BUNGKUS BODY DENGAN STREAM BUILDER AGAR BISA MEMBACA SUHU REAL-TIME
      body: StreamBuilder(
        stream: FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: kFirebaseDatabaseUrl,
        ).ref('monitoring_sawi').onValue,
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          // 2. Ambil data
          double valSuhuUdara = 0.0;
          bool sprayerAktif = false;
          String modeSistem = "Otomatis";
          bool sensorRsValid = false;
          bool sensorDataFresh = false;
          bool airTempValid = false;

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = Map<String, dynamic>.from(
              snapshot.data!.snapshot.value as Map,
            );
            valSuhuUdara = (data['suhu_udara'] ?? 0).toDouble();
            sprayerAktif = data['sprayer_aktif'] == true;
            modeSistem = data['mode_sistem']?.toString() ?? "Otomatis";
            sensorRsValid = data['sensor_rs_valid'] == true;
            sensorDataFresh = data['sensor_data_fresh'] == true;
            airTempValid = data['air_temp_valid'] == true;
          }

          final bool dataAndal =
              sensorRsValid && sensorDataFresh && airTempValid;

          // 3. Logika Ambang Batas Suhu untuk Penyemprotan (pakai suhu udara)
          bool isHot = valSuhuUdara > 30.0;
          Color alertColor = isHot ? Colors.red : Colors.blue;
          String saranTeks = !dataAndal
              ? "Data sensor belum andal (stale/invalid). Periksa koneksi RS sensor."
              : isHot
              ? "Suhu udara terlalu panas (${valSuhuUdara.toStringAsFixed(1)}°C), tunda penyemprotan agar tidak membakar daun."
              : "Suhu udara ideal (${valSuhuUdara.toStringAsFixed(1)}°C). Waktu yang baik untuk pemberian nutrisi cair.";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Penyemprotan",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  "Manajemen hama dan kontrol pestisida otomatis",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),

                // --- BAGIAN STATUS PERANGKAT ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "STATUS PERANGKAT",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              "AKTIF",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSquareStatus(
                            Icons.shower_outlined,
                            "SPRAYER",
                            sprayerAktif ? "ON" : "OFF",
                            sprayerAktif ? Colors.green : Colors.grey,
                          ),
                          _buildSquareStatus(
                            Icons.settings_input_component,
                            "MODE",
                            modeSistem,
                            Colors.green,
                          ),
                          _buildSquareStatus(
                            Icons.bug_report_outlined,
                            "HAMA",
                            "Ada",
                            Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- DETEKSI HAMA REAL-TIME ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Deteksi Hama Real-time",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: const [
                        CircleAvatar(radius: 3, backgroundColor: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          "Live Update",
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // KARTU ALERT MERAH (KRITIS)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Kumbang Daun Terdeteksi",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const Text(
                              "Sektor B-04 menunjukkan aktivitas kumbang tinggi pada 14:20 WIB.",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                "KRITIS: Disarankan segera semprot",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // DUA KOTAK STATUS KECIL (KUMBANG & ULAT DAUN)
                Row(
                  children: [
                    Expanded(
                      child: _buildSmallInfoCard(
                        Icons.bug_report,
                        "Kumbang",
                        "Populasi Rendah",
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSmallInfoCard(
                        Icons.pest_control,
                        "Ulat Daun",
                        "Deteksi: 12",
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (!dataAndal)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.sensors_off_outlined, color: Colors.orange),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Peringatan: Data RS sensor tidak valid atau tidak fresh. Rekomendasi penyemprotan bisa tidak akurat.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // --- SARAN SISTEM DINAMIS (BERDASARKAN SUHU UDARA) ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isHot ? const Color(0xFFFFF5F5) : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: alertColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isHot
                            ? Icons.warning_amber_rounded
                            : Icons.lightbulb_outline,
                        color: alertColor,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SARAN SISTEM",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: alertColor,
                              ),
                            ),
                            Text(
                              saranTeks,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- JADWAL PENYEMPROTAN ---
                const JadwalCard(),
                const SizedBox(height: 24),

                // --- KONTROL MANUAL ---
                const Text(
                  "DURASI PENYEMPROTAN",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildDurationBtn(
                      "3s",
                      isSelected: selectedDuration == 3,
                      onTap: () => setState(() => selectedDuration = 3),
                    ),
                    const SizedBox(width: 8),
                    _buildDurationBtn(
                      "5s",
                      isSelected: selectedDuration == 5,
                      onTap: () => setState(() => selectedDuration = 5),
                    ),
                    const SizedBox(width: 8),
                    _buildDurationBtn(
                      "10s",
                      isSelected: selectedDuration == 10,
                      onTap: () => setState(() => selectedDuration = 10),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (modeSistem == "Manual" && dataAndal)
                        ? () {
                            FirebaseDatabase.instanceFor(
                              app: Firebase.app(),
                              databaseURL: kFirebaseDatabaseUrl,
                            ).ref('controls/sprayer').set(true);
                          }
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      (modeSistem == "Manual" && dataAndal)
                          ? "Mulai Penyemprotan"
                          : "Mulai Penyemprotan (nonaktif)",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B3A13),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      FirebaseDatabase.instanceFor(
                        app: Firebase.app(),
                        databaseURL: kFirebaseDatabaseUrl,
                      ).ref('controls/sprayer').set(false);
                    },
                    icon: const Icon(
                      Icons.stop_circle_outlined,
                      color: Colors.red,
                    ),
                    label: const Text(
                      "Hentikan Penyemprotan",
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- RIWAYAT DETEKSI DENGAN TANGGAL ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      "Riwayat Deteksi",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "LIHAT SEMUA",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRiwayatItem(
                  "Kumbang Daun terdeteksi (Sektor B)",
                  "14:20",
                  "Kamis, 07 Mei 2026",
                  Colors.red,
                ),
                _buildRiwayatItem(
                  "Ulat Daun terdeteksi (Sektor A)",
                  "09:15",
                  "Kamis, 07 Mei 2026",
                  Colors.orange,
                ),
                _buildRiwayatItem(
                  "Kondisi tanaman sehat & aman",
                  "07:30",
                  "Rabu, 06 Mei 2026",
                  Colors.green,
                ),

                const SizedBox(
                  height: 100,
                ), // Spasi bawah agar tidak terpotong navbar
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET PENDUKUNG ---

  Widget _buildSquareStatus(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfoCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildDurationBtn(
    String label, {
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B3A13) : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRiwayatItem(
    String title,
    String time,
    String date,
    Color dotColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: dotColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D5A27),
                ),
              ),
              Text(
                date,
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- WIDGET JADWAL CARD ---
class JadwalCard extends StatelessWidget {
  const JadwalCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "JADWAL PENYEMPROTAN",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimeSlot("Pagi", "07:00 WIB", true),
              _buildTimeSlot("Sore", "16:00 WIB", true),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "*Penyemprotan sore disarankan jika suhu < 30°C",
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlot(String label, String time, bool isActive) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          time,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D5A27),
          ),
        ),
        // Ditambahkan nilai onChanged sederhana agar switch tidak error
        Switch(
          value: isActive,
          onChanged: (v) {},
          activeThumbColor: Colors.green,
        ),
      ],
    );
  }
}
