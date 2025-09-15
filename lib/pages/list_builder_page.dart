import 'package:flutter/material.dart';

class ListBuilderPage extends StatelessWidget {
  const ListBuilderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> items =
        List.generate(100, (index) => 'Item ${index + 1}');
    return Scaffold(
      appBar: AppBar(title: Text('ListView.builder')),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          return ListTile(title: Text(items[index]));
        },
      ),
    );
  }
}
