import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'routes/routes.dart';

Future<void> main() async {
  // 1. Pastikan Flutter framework sudah siap. Ini adalah langkah paling penting.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. Muat file .env secara eksplisit.
    await dotenv.load(fileName: ".env");
    print('✅ .env loaded successfully!');
  } catch (e) {
    print('❌ Failed to load .env: $e');
  }

  // 3. Jalankan aplikasi setelah semuanya dimuat.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      routes: appRoutes,
    );
  }
}
