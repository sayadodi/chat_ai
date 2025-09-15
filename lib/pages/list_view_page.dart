import 'package:flutter/material.dart';

class ListViewPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('ListView')),
      body: ListView(
        children: [
          Container(
              height: 150,
              color: Colors.red,
              child: Center(child: Text('Item 1'))),
          Container(
              height: 150,
              color: Colors.blue,
              child: Center(child: Text('Item 2'))),
          Container(
              height: 150,
              color: Colors.green,
              child: Center(child: Text('Item 3'))),
          Container(
              height: 150,
              color: Colors.yellow,
              child: Center(child: Text('Item 4'))),
          Container(
              height: 150,
              color: Colors.orange,
              child: Center(child: Text('Item 5'))),
        ],
      ),
    );
  }
}
