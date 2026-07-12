import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'notification_screen.dart';
import 'history_screen.dart';
import '../main.dart' show kFirebaseDatabaseUrl;
// Baris 3 tetap biarkan jika kamu berencana menambahkan Firebase.initializeApp()
// di sini, tapi idealnya inisialisasi ada di main.dart.

// ==========================================
// 1. FUNGSI LOGIKA AMBANG BATAS (THRESHOLD)
// ==========================================
// ... (Fungsi cekPH, cekKelembapan, dll tetap sama seperti kode kamu) ...

Map<String, dynamic> cekPH(double nilai) {
  if (nilai >= 6.0 && nilai <= 7.0) {
    return {"status": "NORMAL", "color": Colors.green};
  }
  return {"status": "TIDAK IDEAL", "color": Colors.red};
}

Map<String, dynamic> cekKelembapan(double nilai) {
  if (nilai >= 50 && nilai <= 70) {
    return {"status": "OPTIMAL", "color": Colors.green};
  }
  if (nilai < 50) return {"status": "KERING", "color": Colors.red};
  return {"status": "BASAH", "color": Colors.blue};
}

Map<String, dynamic> cekSuhu(double nilai) {
  if (nilai >= 15 && nilai <= 30) {
    return {"status": "STABIL", "color": Colors.green};
  }
  if (nilai < 15) return {"status": "RENDAH", "color": Colors.blue};
  return {"status": "TINGGI", "color": Colors.red};
}

Map<String, dynamic> cekN(double nilai) {
  if (nilai >= 50 && nilai <= 125) {
    return {"status": "IDEAL", "color": Colors.green};
  }
  if (nilai < 50) return {"status": "RENDAH", "color": Colors.red};
  return {"status": "TINGGI", "color": Colors.orange};
}

Map<String, dynamic> cekP(double nilai) {
  if (nilai >= 15 && nilai <= 30) {
    return {"status": "IDEAL", "color": Colors.green};
  }
  if (nilai < 15) return {"status": "RENDAH", "color": Colors.red};
  return {"status": "TINGGI", "color": Colors.orange};
}

Map<String, dynamic> cekK(double nilai) {
  if (nilai >= 80 && nilai <= 200) {
    return {"status": "IDEAL", "color": Colors.green};
  }
  if (nilai < 80) return {"status": "RENDAH", "color": Colors.red};
  return {"status": "TINGGI", "color": Colors.orange};
}

Map<String, dynamic> cekIndeks(double nilai) {
  if (nilai >= 0.75) return {"status": "LAYAK", "color": Colors.green};
  if (nilai >= 0.50) return {"status": "KURANG", "color": Colors.orange};
  return {"status": "TIDAK LAYAK", "color": Colors.red};
}

Map<String, dynamic> cekSuhuUdara(double nilai) {
  if (nilai >= 22 && nilai <= 30) {
    return {"status": "NORMAL", "color": Colors.green};
  }
  if (nilai < 22) return {"status": "SEJUK", "color": Colors.blue};
  return {"status": "PANAS", "color": Colors.orange};
}

Map<String, dynamic> cekKelembabanUdara(double nilai) {
  if (nilai >= 50 && nilai <= 80) {
    return {"status": "IDEAL", "color": Colors.green};
  }
  if (nilai < 50) return {"status": "KERING", "color": Colors.orange};
  return {"status": "LEMBAB", "color": Colors.blue};
}

// ==========================================
// 2. KELAS UTAMA DASHBOARD
// ==========================================
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color.fromARGB(190, 91, 126, 60);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
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
              style: TextStyle(
                color: Color(0xFF2D5A27),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.green),
            onPressed: () {
              // Navigasi ke halaman daftar notifikasi
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: StreamBuilder(
        stream: FirebaseDatabase.instance.ref('monitoring_sawi').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          double valPH = 0.0;
          double valKelembaban = 0.0;
          double valSuhu = 0.0;
          double valN = 0.0;
          double valP = 0.0;
          double valK = 0.0;
          double valSuhuUdara = 0.0;
          double valKelembabanUdara = 0.0;
          double valIndeks = 0.0;

          // PENYESUAIAN: Status Sensor & Mode Dinamis
          String statusSensor = "Offline";
          Color warnaSensor = Colors.red;
          String modeSistem = "Otomatis";

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = Map<String, dynamic>.from(
              snapshot.data!.snapshot.value as Map,
            );
            double rawIndeks = (data['indeks'] ?? 0).toDouble();
            valPH = (data['ph'] ?? 0).toDouble();
            valKelembaban = (data['kelembaban'] ?? 0).toDouble();
            valSuhu = (data['suhu'] ?? 0).toDouble();
            valN = (data['n'] ?? 0).toDouble();
            valP = (data['p'] ?? 0).toDouble();
            valK = (data['k'] ?? 0).toDouble();
            valSuhuUdara = (data['suhu_udara'] ?? 0).toDouble();
            valKelembabanUdara = (data['kelembaban_udara'] ?? 0).toDouble();
            valIndeks = rawIndeks.clamp(0.0, 1.0);

            // Jika data masuk, sensor dianggap Aktif
            statusSensor = "Aktif";
            warnaSensor = Colors.green;
            // Ambil mode sistem dari firebase
            modeSistem = data['mode_sistem']?.toString() ?? "Otomatis";

            // Tambahan info cuaca jika ada
            bool isRaining = data['is_raining'] == true;
            if (isRaining) {
              statusSensor = "Aktif (Hujan)";
              warnaSensor = Colors.blue;
            }
          }

          var infoPH = cekPH(valPH);
          var infoKelembaban = cekKelembapan(valKelembaban);
          var infoSuhu = cekSuhu(valSuhu);
          var infoN = cekN(valN);
          var infoP = cekP(valP);
          var infoK = cekK(valK);
          var infoSuhuUdara = cekSuhuUdara(valSuhuUdara);
          var infoKelembabanUdara = cekKelembabanUdara(valKelembabanUdara);
          var infoIndeks = cekIndeks(valIndeks);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 150,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/sawi.jpg'),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black45, bgColor],
                            stops: [0.1, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 30,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Halo, Petani!",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Pantau kondisi lahan pada tanaman sawi hijau saat ini.",
                            style: TextStyle(
                              color: Color.fromARGB(231, 255, 255, 255),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // UPDATE: Sekarang statusnya mengikuti sensor (Aktif/Offline)
                      DeviceStatusCard(
                        title: "SENSOR TANAH",
                        value: statusSensor,
                        icon: Icons.sensors,
                        iconColor: warnaSensor,
                      ),
                      const SizedBox(height: 12),
                      // UPDATE: Mengikuti mode sistem dari Firebase
                      DeviceStatusCard(
                        title: "MODE SISTEM",
                        value: modeSistem,
                        icon: Icons.settings,
                        iconColor: Colors.blueAccent,
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Monitoring Sensor',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: MiniParameterCard(
                              title: "pH TANAH",
                              value: valPH.toStringAsFixed(1),
                              status: infoPH['status'],
                              icon: Icons.science_outlined,
                              color: infoPH['color'],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: MiniParameterCard(
                              title: "LEMBAB TANAH",
                              value: "${valKelembaban.toStringAsFixed(0)}%",
                              status: infoKelembaban['status'],
                              icon: Icons.water_drop_outlined,
                              color: infoKelembaban['color'],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: MiniParameterCard(
                              title: "SUHU TANAH",
                              value: "${valSuhu.toStringAsFixed(1)}°C",
                              status: infoSuhu['status'],
                              icon: Icons.thermostat_outlined,
                              color: infoSuhu['color'],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: MiniParameterCard(
                              title: "SUHU UDARA",
                              value: "${valSuhuUdara.toStringAsFixed(1)}°C",
                              status: infoSuhuUdara['status'],
                              icon: Icons.cloud_outlined,
                              color: infoSuhuUdara['color'],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: MiniParameterCard(
                              title: "LEMBAB UDARA",
                              value:
                                  "${valKelembabanUdara.toStringAsFixed(0)}%",
                              status: infoKelembabanUdara['status'],
                              icon: Icons.air_outlined,
                              color: infoKelembabanUdara['color'],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Text(
                        "Kadar Nutrisi (NPK)",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: NutrisiMiniCard(
                              label: "NITROGEN (N)",
                              value: valN.toStringAsFixed(0),
                              status: infoN['status'],
                              color: infoN['color'],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: NutrisiMiniCard(
                              label: "FOSFOR (P)",
                              value: valP.toStringAsFixed(0),
                              status: infoP['status'],
                              color: infoP['color'],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: NutrisiMiniCard(
                              label: "KALIUM (K)",
                              value: valK.toStringAsFixed(0),
                              status: infoK['status'],
                              color: infoK['color'],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      IndeksKelayakanCard(
                        nilaiIndeks: valIndeks,
                        status: infoIndeks['status'],
                        warna: infoIndeks['color'],
                      ),
                      const SizedBox(height: 24),
                      const TrenKelembabanCard(),
                      const SizedBox(height: 24),
                      const RiwayatMonitoringList(), // <--- Tambahkan baris ini
                      const SizedBox(height: 24),
                      const RekomendasiCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ... (Widget pendukung lainnya tetap sama) ...

// ==========================================
// 3. WIDGET-WIDGET PENDUKUNG
// ==========================================
class IndeksKelayakanCard extends StatelessWidget {
  final double nilaiIndeks;
  final String status;
  final Color warna;

  const IndeksKelayakanCard({
    super.key,
    required this.nilaiIndeks,
    required this.status,
    required this.warna,
  });

  @override
  Widget build(BuildContext context) {
    // Ubah misal 0.85 jadi "85%"
    String persen = "${(nilaiIndeks * 100).toInt()}%";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 255, 255),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.grass, color: Color(0xFF2D5A27), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Indeks Kelayakan Tanah pada Sawi Hijau",
                  style: TextStyle(
                    color: Color(0xFF1E3A1A),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: nilaiIndeks, // <-- Nilai Dinamis (Maksimal 1.0)
                    strokeWidth: 12,
                    color: warna, // <-- Warna Dinamis
                    backgroundColor: const Color(0xFFF0F0F0),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      persen,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        color: warna,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ), // <-- Status Dinamis
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Berdasarkan parameter saat ini, pantau warna indikator untuk mengetahui kelayakan tanah Sawi.',
            style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class MiniParameterCard extends StatelessWidget {
  final String title, value, status;
  final IconData icon;
  final Color color; // Parameter warna ditambahkan

  const MiniParameterCard({
    super.key,
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28), // Menggunakan warna dinamis
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ), // Teks warna dinamis
        ],
      ),
    );
  }
}

class NutrisiMiniCard extends StatelessWidget {
  final String label, value, status;
  final Color color;
  const NutrisiMiniCard({
    super.key,
    required this.label,
    required this.value,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              const Text(
                "mg/kg",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class DeviceStatusCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color iconColor;
  const DeviceStatusCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ],
      ),
    );
  }
}

class TrenKelembabanCard extends StatelessWidget {
  const TrenKelembabanCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Tren Kelembaban",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Text(
            "Data 5 hari terakhir",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 30),

          // Mengambil data riwayat dari Firebase
          StreamBuilder(
            stream: FirebaseDatabase.instance
                .ref('riwayat_harian')
                .limitToLast(5)
                .onValue,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                // Tampilan default jika data riwayat belum ada di Firebase
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildBar("H-4", 0.1),
                    _buildBar("H-3", 0.1),
                    _buildBar("H-2", 0.1),
                    _buildBar("H-1", 0.1),
                    _buildBar("Hari Ini", 0.1),
                  ],
                );
              }

              final dataRiwayat = Map<String, dynamic>.from(
                snapshot.data!.snapshot.value as Map,
              );
              var tanggalList = dataRiwayat.keys.toList()..sort();

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: tanggalList.map((tgl) {
                  double nilai = (dataRiwayat[tgl]['kelembaban'] ?? 0)
                      .toDouble();
                  // Label mengambil tanggal (misal 08, 09)
                  String label = tgl.split('-').last;
                  return _buildBar(label, nilai / 100);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // Fungsi buildBar tetap sama seperti milikmu, hanya warnanya saya sesuaikan ke tema AgriFIS
  Widget _buildBar(String day, double heightFactor) {
    return Column(
      children: [
        Container(
          height: 120 * heightFactor.clamp(0.05, 1.0),
          width: 35,
          decoration: BoxDecoration(
            color: const Color(0xFF2D5A27),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          day,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class RiwayatMonitoringList extends StatelessWidget {
  const RiwayatMonitoringList({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Riwayat Monitoring",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryScreen(),
                    ),
                  );
                },
                child: const Text(
                  "LIHAT SEMUA",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // StreamBuilder untuk mengambil daftar riwayat dari Firebase
          StreamBuilder(
            stream: FirebaseDatabase.instance
                .ref('riwayat_harian')
                .limitToLast(3)
                .onValue,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return const Center(child: Text("Belum ada riwayat harian."));
              }

              final data = Map<String, dynamic>.from(
                snapshot.data!.snapshot.value as Map,
              );
              // Mengurutkan dari yang terbaru di atas
              var sortedKeys = data.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              return Column(
                children: sortedKeys.map((key) {
                  return RiwayatItem(
                    tanggal: key,
                    kelembaban: data[key]['kelembaban'].toString(),
                    ph: data[key]['ph']?.toString() ?? "-",
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class RiwayatItem extends StatelessWidget {
  final String tanggal, kelembaban, ph;
  const RiwayatItem({
    super.key,
    required this.tanggal,
    required this.kelembaban,
    required this.ph,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.1),
                child: const Icon(Icons.history, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pengecekan Rutin",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "Lembap: $kelembaban%  •  pH: $ph",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tanggal,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Text(
                    "SELESAI",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RekomendasiCard extends StatelessWidget {
  const RekomendasiCard({super.key});

  List<Map<String, String>> _generateRekomendasi(Map<String, dynamic> data) {
    final rekomendasi = <Map<String, String>>[];

    double kelembaban = (data['kelembaban'] ?? 60).toDouble();
    double ph = (data['ph'] ?? 6.5).toDouble();
    double suhu = (data['suhu'] ?? 60).toDouble();
    double n = (data['n'] ?? 80).toDouble();
    double p = (data['p'] ?? 20).toDouble();
    double k = (data['k'] ?? 120).toDouble();

    if (kelembaban < 50) {
      rekomendasi.add({
        "icon": "💧",
        "text": "Kelembaban sangat rendah. Lakukan Penyiraman.",
      });
    }
    if (kelembaban > 70) {
      rekomendasi.add({
        "icon": "🌊",
        "text": "Kelembaban terlalu tinggi. Kurangi penyiraman.",
      });
    }
    if (ph < 6.0) {
      rekomendasi.add({
        "icon": "🧪",
        "text": "pH terlalu asam. Tindakan pengapuran diperlukan.",
      });
    }
    if (ph > 7.0) {
      rekomendasi.add({
        "icon": "🧪",
        "text": "pH terlalu basa. Tambahkan kompos atau bahan organik.",
      });
    }
    if (suhu < 15) {
      rekomendasi.add({
        "icon": "🌡️",
        "text": "Suhu tanah rendah. Kurangi kadar air penyiraman.",
      });
    }
    if (suhu > 30) {
      rekomendasi.add({
        "icon": "🔥",
        "text": "Suhu tanah tinggi. Tambahkan mulsa jerami.",
      });
    }
    if (n < 50) {
      rekomendasi.add({
        "icon": "🌿",
        "text": "Nitrogen rendah. Tambahkan pupuk nitrogen.",
      });
    }
    if (n > 125) {
      rekomendasi.add({
        "icon": "🌿",
        "text": "Nitrogen tinggi. Kurangi pemberian pupuk nitrogen.",
      });
    }
    if (p < 15) {
      rekomendasi.add({
        "icon": "🪨",
        "text": "Fosfor rendah. Tambahkan pupuk fosfor.",
      });
    }
    if (p > 30) {
      rekomendasi.add({
        "icon": "🪨",
        "text": "Fosfor tinggi. Kurangi pupuk fosfor.",
      });
    }
    if (k < 80) {
      rekomendasi.add({
        "icon": "⚗️",
        "text": "Kalium rendah. Tambahkan pupuk kalium.",
      });
    }
    if (k > 200) {
      rekomendasi.add({
        "icon": "⚗️",
        "text": "Kalium berlebih. Kurangi pupuk kalium.",
      });
    }

    if (rekomendasi.isEmpty) {
      rekomendasi.add({
        "icon": "✅",
        "text":
            "Semua parameter dalam kondisi ideal. Tidak ada tindakan yang diperlukan.",
      });
    }

    return rekomendasi;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseDatabase.instance.ref('monitoring_sawi').onValue,
      builder: (context, snapshot) {
        Map<String, dynamic> data = {};
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          data = Map<String, dynamic>.from(
            snapshot.data!.snapshot.value as Map,
          );
        }
        final rekList = _generateRekomendasi(data);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 67, 94, 63),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.lightbulb_outline, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "REKOMENDASI SISTEM",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Tindakan yang Disarankan",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              ...rekList.map(
                (rek) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rek['icon'] ?? '•',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          rek['text'] ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
