import 'package:flutter/material.dart';

class NutrisiSmallCard extends StatelessWidget {
  final String title, value, status;
  final Color color;

  const NutrisiSmallCard({
    super.key, 
    required this.title, 
    required this.value, 
    required this.status, 
    required this.color
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}