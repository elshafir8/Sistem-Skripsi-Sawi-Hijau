import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../main.dart' show kFirebaseDatabaseUrl;

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifikasi Sistem", style: TextStyle(color: Color(0xFF2D5A27), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.green),
        elevation: 0.5,
      ),
      body: StreamBuilder(
        stream: FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: kFirebaseDatabaseUrl,
        ).ref('notifications').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text("Tidak ada notifikasi baru."));
          }

          // Konversi data Firebase ke Map
          final rawData = snapshot.data!.snapshot.value as Map;
          final notifications = rawData.entries.toList();

          // Urutkan berdasarkan timestamp (terbaru di atas)
          notifications.sort((a, b) => b.value['timestamp'].compareTo(a.value['timestamp']));

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var item = notifications[index].value;
              bool isWarning = item['type'] == 'warning';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isWarning ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
                      color: isWarning ? Colors.red : Colors.blue,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    item['title'] ?? "Peringatan",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(
                        item['message'] ?? "",
                        style: const TextStyle(color: Colors.black87, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            item['date'] ?? "",
                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );

        },
      ),
    );
  }
}