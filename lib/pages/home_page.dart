import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "My Apps",
          style: TextStyle(fontSize: 40),
        ),
      ),
      body: Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                child: Text('ListView'),
                onPressed: () {
                  Navigator.pushNamed(context, '/listview');
                },
              ),
              SizedBox(height: 16),
              ElevatedButton(
                child: Text('ListView.builder'),
                onPressed: () {
                  Navigator.pushNamed(context, '/listbuilder');
                },
              ),
              SizedBox(height: 16),
              ElevatedButton(
                child: Text('ListView.separated'),
                onPressed: () {
                  Navigator.pushNamed(context, '/listseparated');
                },
              ),
              SizedBox(height: 16),
              ElevatedButton(
                child: Text('Chat AI'),
                onPressed: () {
                  Navigator.pushNamed(context, '/chat');
                },
              ),
              SizedBox(height: 16),
              ElevatedButton(
                child: Text('History'),
                onPressed: () {
                  Navigator.pushNamed(context, '/history');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
