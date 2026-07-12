import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../main.dart' show kFirebaseDatabaseUrl;

class PenyiramanScreen extends StatelessWidget {
  const PenyiramanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(190, 91, 126, 60),
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
      ),
      body: StreamBuilder(
        stream: FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: kFirebaseDatabaseUrl,
        ).ref('monitoring_sawi').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          double valKelembaban = 0.0;
          double valSuhu = 0.0;
          double valRainADC = 4095.0;
          int rainThreshold = 3500;
          bool isRaining = false;
          double fuzzyDuration = 0.0;
          bool fuzzyEnabled = false;
          String modeSistem = "Otomatis";
          bool pompaAktif = false;
          bool sensorRsValid = false;
          bool sensorDataFresh = false;
          bool moistureValid = false;

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data = Map<String, dynamic>.from(
              snapshot.data!.snapshot.value as Map,
            );
            valKelembaban = (data['kelembaban'] ?? 0).toDouble();
            valSuhu = (data['suhu'] ?? 0).toDouble();
            valRainADC = (data['raindrop_adc'] ?? 4095).toDouble();
            rainThreshold = (data['raindrop_threshold'] ?? 3500).toInt();
            isRaining = data['is_raining'] == true;
            fuzzyDuration = (data['fuzzy_duration'] ?? 0.0).toDouble();
            fuzzyEnabled = data['fuzzy_enabled'] == true;
            modeSistem = data['mode_sistem']?.toString() ?? "Otomatis";
            pompaAktif = data['pompa_aktif'] == true;
            sensorRsValid = data['sensor_rs_valid'] == true;
            sensorDataFresh = data['sensor_data_fresh'] == true;
            moistureValid = data['moisture_valid'] == true;
          }

          final bool dataAndal =
              sensorRsValid && sensorDataFresh && moistureValid;

          Color warnaBar = Colors.green;
          String statusKondisi = "Ideal";
          Color warnaKondisi = Colors.green;

          if (!dataAndal) {
            warnaBar = Colors.grey;
            statusKondisi = "Data Tidak Andal";
            warnaKondisi = Colors.orange;
          } else if (valKelembaban < 50) {
            warnaBar = Colors.red;
            statusKondisi = "Kering";
            warnaKondisi = Colors.red;
          } else if (valKelembaban > 70) {
            warnaBar = Colors.blue;
            statusKondisi = "Basah";
            warnaKondisi = Colors.blue;
          }

          double progressValue = (valKelembaban / 100).clamp(0.0, 1.0);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Penyiraman",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  "Kendali irigasi cerdas untuk lahan Anda.",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.water_drop_outlined,
                                color: Colors.blue,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Status Pompa",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 3,
                                  backgroundColor: pompaAktif
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  pompaAktif ? "Aktif" : "Mati",
                                  style: TextStyle(
                                    color: pompaAktif
                                        ? Colors.green
                                        : Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatusItem(
                            "MODE OPERASI",
                            modeSistem,
                            Colors.black87,
                          ),
                          const Spacer(),
                          _buildStatusItem(
                            "KONDISI TANAH",
                            statusKondisi,
                            warnaKondisi,
                          ),
                        ],
                      ),
                    ],
                  ),
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
                            "Peringatan: Data kelembaban RS sensor tidak valid atau tidak fresh.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Kelembapan Tanah",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            dataAndal
                                ? "${valKelembaban.toStringAsFixed(0)}%"
                                : "--",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: warnaBar,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: dataAndal ? progressValue : 0.0,
                          minHeight: 12,
                          backgroundColor: const Color(0xFFEEEEEE),
                          valueColor: AlwaysStoppedAnimation<Color>(warnaBar),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "KERING (<50%)",
                            style: TextStyle(
                              fontSize: 10,
                              color: dataAndal && valKelembaban < 50
                                  ? Colors.red
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "IDEAL (50-70%)",
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  dataAndal &&
                                      (valKelembaban >= 50 &&
                                          valKelembaban <= 70)
                                  ? Colors.green
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "BASAH (>70%)",
                            style: TextStyle(
                              fontSize: 10,
                              color: dataAndal && valKelembaban > 70
                                  ? Colors.blue
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: modeSistem == "Otomatis"
                            ? Colors.green
                            : Colors.orange,
                        width: 5,
                      ),
                    ),
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Mode $modeSistem",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              modeSistem == "Otomatis"
                                  ? "Penyiraman diatur oleh Fuzzy Logic"
                                  : "Penyiraman diatur secara manual",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: modeSistem == "Otomatis",
                        onChanged: (v) {
                          final databaseRef = FirebaseDatabase.instanceFor(
                            app: Firebase.app(),
                            databaseURL: kFirebaseDatabaseUrl,
                          );
                          // Mengubah mode sistem
                          databaseRef
                              .ref('controls/mode_sistem')
                              .set(v ? "Otomatis" : "Manual");

                          // Pembersihan data ketika berganti mode (Cleaning data & persiapan data bersih)
                          databaseRef.ref('controls/pompa').set(false);
                          databaseRef.ref('controls/sprayer').set(false);
                        },
                        activeThumbColor: Colors.green,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (modeSistem == "Manual")
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: dataAndal
                          ? () {
                              FirebaseDatabase.instanceFor(
                                app: Firebase.app(),
                                databaseURL: kFirebaseDatabaseUrl,
                              ).ref('controls/pompa').set(!pompaAktif);
                            }
                          : null,
                      icon: Icon(pompaAktif ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        pompaAktif
                            ? "Matikan Pompa"
                            : "Siram Sekarang (Manual)",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pompaAktif
                            ? Colors.red
                            : const Color(0xFF1B3A13),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      "Riwayat Penyiraman",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "TERBARU",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder(
                  stream: FirebaseDatabase.instanceFor(
                    app: Firebase.app(),
                    databaseURL: kFirebaseDatabaseUrl,
                  ).ref('riwayat_penyiraman').limitToLast(5).onValue,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData ||
                        snapshot.data!.snapshot.value == null) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text(
                            "Belum ada riwayat penyiraman.",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    }
                    final data = Map<String, dynamic>.from(
                      snapshot.data!.snapshot.value as Map,
                    );
                    var sortedKeys = data.keys.toList()
                      ..sort((a, b) => b.compareTo(a));
                    return Column(
                      children: sortedKeys.map((key) {
                        var item = data[key];
                        return _buildRiwayatItem(
                          item['tipe'] ?? "Otomatis",
                          "${item['kelembaban']}% • Selesai",
                          item['waktu'] ?? "--:--",
                          item['tanggal_lengkap'] ?? "",
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  "Grafik Fuzzy Logic",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                LiveFuzzyGraphCard(
                  moisture: valKelembaban,
                  temperature: valSuhu,
                  rainADC: valRainADC,
                  rainThreshold: rainThreshold,
                  fuzzyDuration: fuzzyDuration,
                  isRaining: isRaining,
                  fuzzyEnabled: fuzzyEnabled,
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStatus(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
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

  Widget _buildRiwayatItem(
    String type,
    String desc,
    String time,
    String fullDate,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFF5F5F5),
            child: Icon(
              type == "Otomatis" ? Icons.refresh : Icons.touch_app_outlined,
              color: Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF2D5A27),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                fullDate,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FuzzyGraphCard extends StatelessWidget {
  const FuzzyGraphCard({super.key});

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
            "Membership Functions",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _buildGraphHeader("Kelembaban Tanah (%)"),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: FuzzyPainter(
                sets: [
                  FuzzySetData("Kering", [0, 0, 50], Colors.red),
                  FuzzySetData("Lembab", [45, 65, 85], Colors.green),
                  FuzzySetData("S.Lembab", [75, 100, 100], Colors.blue),
                ],
                maxX: 100,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildGraphHeader("Suhu Udara (°C)"),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: FuzzyPainter(
                sets: [
                  FuzzySetData("Dingin", [0, 0, 26], Colors.blue),
                  FuzzySetData("Sedang", [20, 25, 30], Colors.green),
                  FuzzySetData("Panas", [28, 35, 40], Colors.orange),
                ],
                maxX: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Grafik di atas menunjukkan bagaimana sistem menentukan kondisi tanah dan udara berdasarkan teori Fuzzy Logic.",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}

class FuzzySetData {
  final String label;
  final List<double> points;
  final Color color;
  FuzzySetData(this.label, this.points, this.color);
}

class FuzzyPainter extends CustomPainter {
  final List<FuzzySetData> sets;
  final double maxX;
  FuzzyPainter({required this.sets, required this.maxX});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), axisPaint);

    for (var set in sets) {
      final path = Path();
      paint.color = set.color;
      fillPaint.color = set.color.withOpacity(0.1);
      double x1 = (set.points[0] / maxX) * size.width;
      double x2 = (set.points[1] / maxX) * size.width;
      double x3 = (set.points[2] / maxX) * size.width;
      path.moveTo(x1, size.height);
      path.lineTo(x2, 0);
      path.lineTo(x3, size.height);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, paint);
      textPainter.text = TextSpan(
        text: set.label,
        style: TextStyle(
          color: set.color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x2 - textPainter.width / 2, -15));
    }

    for (int i = 0; i <= 4; i++) {
      double val = (maxX / 4) * i;
      double x = (val / maxX) * size.width;
      textPainter.text = TextSpan(
        text: val.toStringAsFixed(0),
        style: const TextStyle(color: Colors.grey, fontSize: 8),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height + 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LiveFuzzyGraphCard extends StatelessWidget {
  final double moisture;
  final double temperature;
  final double rainADC;
  final int rainThreshold;
  final double fuzzyDuration;
  final bool isRaining;
  final bool fuzzyEnabled;

  const LiveFuzzyGraphCard({
    super.key,
    required this.moisture,
    required this.temperature,
    required this.rainADC,
    required this.rainThreshold,
    required this.fuzzyDuration,
    required this.isRaining,
    required this.fuzzyEnabled,
  });

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
            "Live Sensor + Fuzzy Pipeline",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: CustomPaint(
              painter: LiveFuzzyPainter(
                moisture: moisture,
                temperature: temperature,
                rainADC: rainADC,
                rainThreshold: rainThreshold,
                fuzzyDuration: fuzzyDuration,
                isRaining: isRaining,
                fuzzyEnabled: fuzzyEnabled,
              ),
              child: Container(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildLegend(Colors.green, "Kelembaban"),
              const SizedBox(width: 12),
              _buildLegend(Colors.orange, "Suhu"),
              const SizedBox(width: 12),
              _buildLegend(Colors.blue, "Raindrop"),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isRaining
                ? "Hujan terdeteksi: pompa OFF."
                : "Tidak hujan: fuzzy aktif.",
            style: TextStyle(
              color: isRaining ? Colors.blue : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Fuzzy output durasi: ${fuzzyDuration.toStringAsFixed(1)} menit",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

class LiveFuzzyPainter extends CustomPainter {
  final double moisture;
  final double temperature;
  final double rainADC;
  final int rainThreshold;
  final double fuzzyDuration;
  final bool isRaining;
  final bool fuzzyEnabled;

  LiveFuzzyPainter({
    required this.moisture,
    required this.temperature,
    required this.rainADC,
    required this.rainThreshold,
    required this.fuzzyDuration,
    required this.isRaining,
    required this.fuzzyEnabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFF6F7FA);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;
    for (int i = 1; i <= 4; i++) {
      final y = size.height / 5 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final border = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      border,
    );

    final moisturePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final tempPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final rainPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final thresholdPaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double maxMoisture = 100;
    double maxTemp = 40;
    double maxRain = 4095;

    double xMoisture = size.width * 0.2;
    double xTemp = size.width * 0.5;
    double xRain = size.width * 0.8;
    double yMoisture =
        size.height -
        (moisture.clamp(0, maxMoisture) / maxMoisture) * size.height;
    double yTemp =
        size.height - (temperature.clamp(0, maxTemp) / maxTemp) * size.height;
    double yRain =
        size.height - (rainADC.clamp(0, maxRain) / maxRain) * size.height;

    final path = Path()
      ..moveTo(xMoisture, yMoisture)
      ..lineTo(xTemp, yTemp)
      ..lineTo(xRain, yRain);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(xMoisture, yMoisture), 5, moisturePaint);
    canvas.drawCircle(Offset(xTemp, yTemp), 5, tempPaint);
    canvas.drawCircle(Offset(xRain, yRain), 5, rainPaint);

    final textStyle = TextStyle(color: Colors.black87, fontSize: 10);
    _drawLabel(
      canvas,
      "Moisture ${moisture.toStringAsFixed(0)}%",
      Offset(xMoisture - 34, yMoisture - 18),
      textStyle,
    );
    _drawLabel(
      canvas,
      "Suhu ${temperature.toStringAsFixed(1)}°C",
      Offset(xTemp - 34, yTemp - 18),
      textStyle,
    );
    _drawLabel(
      canvas,
      "Raindrop ${rainADC.toStringAsFixed(0)}",
      Offset(xRain - 42, yRain - 18),
      textStyle,
    );

    double yThreshold = size.height - (rainThreshold / maxRain) * size.height;
    canvas.drawLine(
      Offset(0, yThreshold),
      Offset(size.width, yThreshold),
      thresholdPaint,
    );
    _drawLabel(
      canvas,
      "Threshold: $rainThreshold",
      Offset(8, yThreshold - 16),
      TextStyle(color: Colors.blue.shade700, fontSize: 10),
    );

    final activeColor = fuzzyEnabled ? Colors.green : Colors.grey;
    canvas.drawCircle(
      Offset(size.width - 24, 18),
      6,
      Paint()
        ..color = activeColor
        ..style = PaintingStyle.fill,
    );
    _drawLabel(
      canvas,
      fuzzyEnabled ? "Fuzzy ON" : "Fuzzy OFF",
      Offset(size.width - 82, 10),
      TextStyle(color: activeColor, fontSize: 10),
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant LiveFuzzyPainter oldDelegate) {
    return moisture != oldDelegate.moisture ||
        temperature != oldDelegate.temperature ||
        rainADC != oldDelegate.rainADC ||
        rainThreshold != oldDelegate.rainThreshold ||
        fuzzyDuration != oldDelegate.fuzzyDuration ||
        isRaining != oldDelegate.isRaining ||
        fuzzyEnabled != oldDelegate.fuzzyEnabled;
  }
}
