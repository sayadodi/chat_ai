import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<dynamic> messages = [];
  bool loading = true;

  // Deklarasikan variabel sebagai 'late final'
  late final String _apiUrl;

  @override
  void initState() {
    super.initState();
    // Inisialisasi variabel di dalam initState()
    _apiUrl = dotenv.env['API_URL']!;
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    final url = Uri.parse('$_apiUrl/get_messages.php');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          messages = jsonDecode(response.body);
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
        });
        print('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        loading = false;
      });
      print('Error: $e');
    }
  }

  Future<void> deleteMessage(int id) async {
    final url = Uri.parse('$_apiUrl/delete_message.php');
    try {
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id}),
      );
      if (response.statusCode != 200) {
        print('Failed to delete message: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kelompokkan pesan berdasarkan tanggal dengan urutan yang benar
    final groupedMessages = groupMessagesByDate(messages);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pesan',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : messages.isEmpty
              ? const Center(
                  child: Text('Belum ada pesan.',
                      style: TextStyle(fontSize: 16, color: Colors.grey)))
              : ListView.builder(
                  itemCount: groupedMessages.keys.length,
                  itemBuilder: (context, dateIndex) {
                    final date = groupedMessages.keys.elementAt(dateIndex);
                    final dailyMessages = groupedMessages[date]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            formatDateHeader(date),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[800],
                            ),
                          ),
                        ),
                        ...dailyMessages.map((msg) {
                          final int? messageId =
                              int.tryParse(msg['id'].toString());
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                            child: Dismissible(
                              key: Key(msg['id'].toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Konfirmasi Hapus'),
                                      content: const Text(
                                          'Yakin ingin menghapus pesan ini?'),
                                      actions: <Widget>[
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Tidak'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text('Ya'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              onDismissed: (direction) {
                                if (messageId != null) {
                                  setState(() {
                                    messages.removeWhere(
                                        (item) => item['id'] == msg['id']);
                                  });
                                  deleteMessage(messageId);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Pesan berhasil dihapus.')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('ID pesan tidak valid.')),
                                  );
                                }
                              },
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg['sender'] ?? 'User',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: msg['sender'] == 'User'
                                              ? Colors.blue
                                              : Colors.green,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        msg['content'] ?? '',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Pukul ${DateFormat.jm().format(DateTime.parse(msg['created_at']))}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
    );
  }

  Map<String, List<dynamic>> groupMessagesByDate(List<dynamic> messages) {
    final Map<String, List<dynamic>> groupedData = {};
    for (var message in messages) {
      final date = DateTime.parse(message['created_at']);
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);
      if (!groupedData.containsKey(formattedDate)) {
        groupedData[formattedDate] = [];
      }
      groupedData[formattedDate]!.add(message);
    }

    final Map<String, List<dynamic>> finalGroupedData = {};
    // Mengurutkan kunci (tanggal) dari yang terbaru ke terlama
    final sortedKeys = groupedData.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (var key in sortedKeys) {
      finalGroupedData[key] = groupedData[key]!;
    }

    return finalGroupedData;
  }

  String formatDateHeader(String date) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    if (date == today) {
      return 'Hari Ini';
    } else if (date == yesterday) {
      return 'Kemarin';
    } else {
      return DateFormat('EEEE, d MMMM yyyy', 'id_ID')
          .format(DateTime.parse(date));
    }
  }
}
