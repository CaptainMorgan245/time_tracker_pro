// lib/widgets/app_setting_list_card.dart

import 'package:flutter/material.dart';

// start class: AppSettingListCard
class AppSettingListCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final Function(int) onEdit;

  // start method: constructor
  const AppSettingListCard({
    super.key,
    required this.title,
    required this.items,
    required this.onEdit,
  });
  // end method: constructor

  // start method: build
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            // FIX: Added Expanded wrapper. This tells the ListView to fill the rest of the Card's height and scroll internally.
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final value = items[index];
                  return ListTile(
                    title: Text(value),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => onEdit(index),
                    ),
                    onTap: () => onEdit(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
// end method: build
}
// end class: AppSettingListCard
