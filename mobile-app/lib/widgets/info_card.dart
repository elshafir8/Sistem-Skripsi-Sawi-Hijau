import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
  final String title, value, status;
  final IconData icon;
  const InfoCard({super.key, required this.title, required this.value, required this.status, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(status, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
          ],
        ),
        trailing: Icon(icon, color: Colors.green),
      ),
    );
  }
}

class MiniParameterCard extends StatelessWidget {
  final String title, value, status;
  final IconData icon;

  const MiniParameterCard({
    super.key, 
    required this.title, 
    required this.value, 
    required this.status, 
    required this.icon
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.green, size: 24),
          const SizedBox(height: 8),
          Text(
            title, 
            style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 4),
          Text(
            value, 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 4),
          Text(
            status, 
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)
          ),
        ],
      ),
    );
  }
}