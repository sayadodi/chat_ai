import 'package:flutter/material.dart';
import '../pages/list_view_page.dart';
import '../pages/list_builder_page.dart';
import '../pages/list_separated_page.dart';
import '../pages/home_page.dart';
import '../pages/chatpage/chat_page.dart';
import '../pages/chatpage/history_page.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => HomePage(),
  '/listview': (context) => ListViewPage(),
  '/listbuilder': (context) => ListBuilderPage(),
  '/listseparated': (context) => ListSeparatedPage(),
  '/chat': (context) => ChatPage(),
  '/history': (context) => HistoryPage(),
};
