import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import '../main.dart'; // Untuk mengakses scaffoldMessengerKey & kFirebaseDatabaseUrl

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static int _kelembabanState = 0;
  static int _phState = 0;
  static int _suhuState = 0;
  static int _nState = 0;
  static int _pState = 0;
  static int _kState = 0;

  static bool _lastPompaState = false;
  static bool _lastSprayerState = false;
  static bool _sensorReliabilityAlerted = false;

  static void init() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // v21 menggunakan named parameter 'settings:'
    _notificationsPlugin.initialize(
      settings: initializationSettings,
    );

    _listenToFirebase();
  }

  static void _listenToFirebase() {
    FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kFirebaseDatabaseUrl,
    ).ref('monitoring_sawi').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        double kelembaban = (data['kelembaban'] ?? 100).toDouble();
        double ph = (data['ph'] ?? 7).toDouble();
        double suhu = (data['suhu'] ?? 25).toDouble();
        double n = (data['n'] ?? 100).toDouble();
        double p = (data['p'] ?? 100).toDouble();
        double k = (data['k'] ?? 100).toDouble();

        bool pompaAktif = data['pompa_aktif'] == true;
        bool sprayerAktif = data['sprayer_aktif'] == true;
        String modeSistem = data['mode_sistem']?.toString() ?? "Otomatis";
        bool sensorRsValid = data['sensor_rs_valid'] == true;
        bool sensorDataFresh = data['sensor_data_fresh'] == true;
        bool airTempValid = data['air_temp_valid'] == true;
        int sensorErrorCount = (data['sensor_rs_error_count'] ?? 0).toInt();
        bool dataReliabilityOk = sensorRsValid && sensorDataFresh && airTempValid;

        // 0. Notifikasi Reliabilitas Sensor (anti-spam + recovery)
        if (!dataReliabilityOk && !_sensorReliabilityAlerted) {
          _triggerNotification(
            id: 30,
            title: "📡 Sensor RS Tidak Andal",
            message: "Data sensor invalid/stale (error: $sensorErrorCount). Sistem masuk mode aman.",
            type: "warning",
          );
          _sensorReliabilityAlerted = true;
        } else if (dataReliabilityOk && _sensorReliabilityAlerted) {
          _triggerNotification(
            id: 31,
            title: "✅ Sensor RS Kembali Normal",
            message: "Data sensor kembali valid dan fresh. Monitoring berjalan normal.",
            type: "info",
          );
          _sensorReliabilityAlerted = false;
        }

        // 1. Notifikasi Perubahan Status Pompa
        if (pompaAktif != _lastPompaState) {
          if (pompaAktif) {
            _triggerNotification(
              id: 10,
              title: "💧 Penyiraman Dimulai",
              message: "Sistem telah mengaktifkan pompa penyiraman.",
              type: "info",
            );
          } else {
            _triggerNotification(
              id: 11,
              title: "✅ Penyiraman Selesai",
              message: "Kondisi tanah sudah cukup lembap, pompa dimatikan.",
              type: "info",
            );
            // Simpan ke Riwayat Penyiraman
            _saveWateringHistory(kelembaban: kelembaban, mode: modeSistem);
          }
          _lastPompaState = pompaAktif;
        }

        // 2. Notifikasi Perubahan Status Sprayer
        if (sprayerAktif != _lastSprayerState) {
          if (sprayerAktif) {
            _triggerNotification(
              id: 20,
              title: "🚿 Penyemprotan Dimulai",
              message: "Sistem telah mengaktifkan sprayer nutrisi/pestisida.",
              type: "info",
            );
          } else {
            _triggerNotification(
              id: 21,
              title: "✅ Penyemprotan Selesai",
              message: "Proses penyemprotan telah berhasil diselesaikan.",
              type: "info",
            );
          }
          _lastSprayerState = sprayerAktif;
        }

        // 3. Notifikasi: parameter di luar rentang ideal
        // Kelembaban ideal: 50 - 70
        if (kelembaban < 50 && _kelembabanState != 1) {
          _triggerNotification(
            id: 1,
            title: "⚠️ Kelembaban tanah sangat rendah.",
            message: "Rekomendasi: Lakukan Penyiraman.",
            type: "warning",
          );
          _kelembabanState = 1;
        } else if (kelembaban > 70 && _kelembabanState != 2) {
          _triggerNotification(
            id: 1,
            title: "⚠️ Kelembaban tanah terlalu tinggi.",
            message: "Rekomendasi: Kurangi penyiraman.",
            type: "warning",
          );
          _kelembabanState = 2;
        } else if (kelembaban >= 50 && kelembaban <= 70) {
          _kelembabanState = 0;
        }

        // pH ideal: 6.0 - 7.0
        if (ph < 6.0 && _phState != 1) {
          _triggerNotification(
            id: 2,
            title: "⚠️ pH tanah terlalu asam.",
            message: "Rekomendasi: Tindakan pengapuran.",
            type: "warning",
          );
          _phState = 1;
        } else if (ph > 7.0 && _phState != 2) {
          _triggerNotification(
            id: 2,
            title: "⚠️ pH tanah terlalu basa.",
            message: "Rekomendasi: Tambahkan kompos atau bahan organik.",
            type: "warning",
          );
          _phState = 2;
        } else if (ph >= 6.0 && ph <= 7.0) {
          _phState = 0;
        }

        // Suhu tanah ideal: < 15 rendah, 15 - 30 normal, > 30 tinggi
        if (suhu < 15 && _suhuState != 1) {
          _triggerNotification(
            id: 3,
            title: "⚠️ Suhu tanah rendah.",
            message: "Rekomendasi: Periksa kondisi lingkungan dan atur penyiraman secara tepat.",
            type: "warning",
          );
          _suhuState = 1;
        } else if (suhu > 30 && _suhuState != 2) {
          _triggerNotification(
            id: 3,
            title: "⚠️ Suhu tanah tinggi.",
            message: "Rekomendasi: Kurangi pemanasan lahan (mis. tambah mulsa jerami).",
            type: "warning",
          );
          _suhuState = 2;
        } else if (suhu >= 15 && suhu <= 30) {
          _suhuState = 0;
        }


        // N ideal: 50 - 125
        if (n < 50 && _nState != 1) {
          _triggerNotification(
            id: 4,
            title: "⚠️ Kadar nitrogen rendah.",
            message: "Rekomendasi: Tambahkan pupuk nitrogen.",
            type: "warning",
          );
          _nState = 1;
        } else if (n > 125 && _nState != 2) {
          _triggerNotification(
            id: 4,
            title: "⚠️ Kadar nitrogen tinggi.",
            message: "Rekomendasi: Kurangi pemberian pupuk nitrogen.",
            type: "warning",
          );
          _nState = 2;
        } else if (n >= 50 && n <= 125) {
          _nState = 0;
        }

        // P ideal: 15 - 30
        if (p < 15 && _pState != 1) {
          _triggerNotification(
            id: 5,
            title: "⚠️ Kadar fosfor rendah.",
            message: "Rekomendasi: Tambahkan pupuk fosfor.",
            type: "warning",
          );
          _pState = 1;
        } else if (p > 30 && _pState != 2) {
          _triggerNotification(
            id: 5,
            title: "⚠️ Kadar fosfor tinggi.",
            message: "Rekomendasi: Kurangi pupuk fosfor.",
            type: "warning",
          );
          _pState = 2;
        } else if (p >= 15 && p <= 30) {
          _pState = 0;
        }

        // K ideal: 80 - 200
        if (k < 80 && _kState != 1) {
          _triggerNotification(
            id: 6,
            title: "⚠️ Kadar kalium rendah.",
            message: "Rekomendasi: Tambahkan pupuk kalium.",
            type: "warning",
          );
          _kState = 1;
        } else if (k > 200 && _kState != 2) {
          _triggerNotification(
            id: 6,
            title: "⚠️ Kadar kalium berlebih.",
            message: "Rekomendasi: Kurangi pupuk kalium.",
            type: "warning",
          );
          _kState = 2;
        } else if (k >= 80 && k <= 200) {
          _kState = 0;
        }
      }
    });
  }

  static void _triggerNotification({
    required int id,
    required String title,
    required String message,
    required String type,
  }) {
    _showPopup(id: id, title: title, body: message);
    _saveNotificationToFirebase(title: title, message: message, type: type);
    _showInAppPopup(title: title, message: message, type: type);
  }

  static void _showInAppPopup({
    required String title,
    required String message,
    required String type,
  }) {
    final bool isWarning = type == 'warning';
    
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
            ],
            border: Border.all(color: isWarning ? Colors.red : Colors.green, width: 2),
          ),
          child: Row(
            children: [
              Icon(isWarning ? Icons.warning_amber_rounded : Icons.info_outline, color: isWarning ? Colors.red : Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(message, style: const TextStyle(color: Colors.black87, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                onPressed: () => scaffoldMessengerKey.currentState?.hideCurrentSnackBar(),
              )
            ],
          ),
        ),
      ),
    );
  }

  static void _saveWateringHistory({required double kelembaban, required String mode}) {
    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month}/${now.year}";
    final timeStr = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
    
    FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kFirebaseDatabaseUrl,
    ).ref('riwayat_penyiraman').push().set({
      'kelembaban': kelembaban.toStringAsFixed(0),
      'waktu': timeStr,
      'tanggal_lengkap': dateStr,
      'tipe': mode,
      'timestamp': ServerValue.timestamp,
    });
  }

  static void _saveNotificationToFirebase({
    required String title,
    required String message,
    required String type,
  }) {
    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}";
    
    FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: kFirebaseDatabaseUrl,
    ).ref('notifications').push().set({
      'title': title,
      'message': message,
      'type': type,
      'date': dateStr,
      'timestamp': ServerValue.timestamp,
    });
  }

  static Future<void> _showPopup({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'agrifis_alert_channel',
      'Peringatan AgriFIS',
      importance: Importance.max,
      priority: Priority.max,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    // PERBAIKAN: v21 menggunakan named parameter
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}
