import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../main.dart' show kFirebaseDatabaseUrl;

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color greenTheme = Color(0xFF2D5A27);

    return Scaffold(
      backgroundColor: const Color.fromARGB(190, 91, 126, 60),
      appBar: AppBar(
        title: const Text("Riwayat & Tren", style: TextStyle(color: greenTheme, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: greenTheme),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tren Kelembaban",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const Text(
              "Statistik kelembaban tanah beberapa hari terakhir",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            
            const LargeTrenCard(),
            
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Log Monitoring harian",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showSaveDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Simpan Data", style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: greenTheme,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            const DetailedHistoryList(),
          ],
        ),
      ),
    );
  }

  void _showSaveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Simpan Snapshot?"),
        content: const Text("Apakah Anda ingin menyimpan kondisi sensor saat ini ke dalam riwayat harian?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              await _saveCurrentSnapshot();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Data berhasil disimpan ke riwayat!")),
              );
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCurrentSnapshot() async {
    final db = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kFirebaseDatabaseUrl,
    );
    // Ambil data terbaru dari monitoring_sawi
    final snapshot = await db.ref('monitoring_sawi').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final now = DateTime.now();
      final dateKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      // Simpan ke riwayat_harian dengan key tanggal hari ini
      await db.ref('riwayat_harian/$dateKey').set({
        'kelembaban': data['kelembaban'],
        'ph': data['ph'],
        'suhu': data['suhu'],
        'n': data['n'],
        'p': data['p'],
        'k': data['k'],
        'timestamp': ServerValue.timestamp,
      });
    }
  }
}

class LargeTrenCard extends StatelessWidget {
  const LargeTrenCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: StreamBuilder(
              stream: FirebaseDatabase.instanceFor(
                app: Firebase.app(),
                databaseURL: kFirebaseDatabaseUrl,
              ).ref('riwayat_harian').limitToLast(7).onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text("Belum ada data tren."));
                }

                final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                var sortedKeys = data.keys.toList()..sort();

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: sortedKeys.map((key) {
                    double val = (data[key]['kelembaban'] ?? 0).toDouble();
                    String day = key.split('-').last;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text("${val.toInt()}%", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                          width: 30,
                          height: 140 * (val / 100).clamp(0.1, 1.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D5A27),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(day, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DetailedHistoryList extends StatelessWidget {
  const DetailedHistoryList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: kFirebaseDatabaseUrl,
      ).ref('riwayat_harian').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text("Belum ada riwayat.", style: TextStyle(color: Colors.white70)));
        }

        final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        var sortedKeys = data.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedKeys.length,
          itemBuilder: (context, index) {
            final key = sortedKeys[index];
            final item = data[key];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ExpansionTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.calendar_today, color: Color(0xFF2D5A27), size: 18),
                ),
                title: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Lembap: ${item['kelembaban']}% | pH: ${item['ph']}"),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDetail("N", "${item['n']}"),
                        _buildDetail("P", "${item['p']}"),
                        _buildDetail("K", "${item['k']}"),
                        _buildDetail("Suhu", "${item['suhu']}°C"),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetail(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
