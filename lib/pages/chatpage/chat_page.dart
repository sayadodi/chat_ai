import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatPage extends StatefulWidget {
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _messages = [];
  bool _sending = false;

  // Deklarasikan variabel untuk URL API
  late final String _apiUrl;

  @override
  void initState() {
    super.initState();
    // Inisialisasi URL API di sini, setelah .env dipastikan sudah dimuat
    _apiUrl = dotenv.env['API_URL']!;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Fungsi baru untuk menyimpan pesan ke backend
  Future<void> _saveMessageToBackend(String sender, String content) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/save_message.php'), // Gunakan URL dari .env
        body: {'sender': sender, 'content': content},
      );
      if (response.statusCode != 200) {
        print('Gagal menyimpan pesan ke backend: ${response.body}');
      }
    } catch (e) {
      print('Terjadi kesalahan saat menyimpan pesan: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    if (_sending || text.trim().isEmpty) return;

    final userMessage =
        _Msg(role: 'user', content: text.trim(), time: DateTime.now());
    setState(() {
      _messages.add(userMessage);
    });
    _scrollToBottom();

    await _saveMessageToBackend(userMessage.role, userMessage.content);

    final placeholder = _Msg(
        role: 'assistant', content: '', time: DateTime.now(), isTyping: true);
    setState(() => _messages.add(placeholder));
    _scrollToBottom();

    _sending = true;

    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _finishAssistant(
          placeholder, 'Error: OPENROUTER_API_KEY tidak ditemukan di .env');
      _sending = false;
      return;
    }

    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer':
          dotenv.env['HTTP_REFERER'] ?? 'https://aplikasi-anda.example',
      'X-Title': dotenv.env['API_TITLE'] ?? 'Flutter Chat AI',
    };
    final model = dotenv.env['MODEL_ID'] ?? 'deepseek/deepseek-r1:free';

    final body = jsonEncode({
      "model": model,
      "messages": [
        for (final m in _messages.where((m) => m.content.isNotEmpty))
          {"role": m.role, "content": m.content}
      ],
    });

    try {
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 60));

      final decodedBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final data = jsonDecode(decodedBody);
        final raw =
            (data['choices']?[0]?['message']?['content'] ?? '').toString();

        await _saveMessageToBackend('ai', raw);

        await _typewriterInsert(placeholder, raw);
      } else {
        String errMsg = response.reasonPhrase ?? 'Bad Request';
        try {
          final err = jsonDecode(decodedBody);
          errMsg = (err['error']?['message'] ?? errMsg).toString();
        } catch (_) {}
        _finishAssistant(placeholder, 'Error: $errMsg');
      }
    } on TimeoutException {
      _finishAssistant(placeholder, 'Error: Request timeout');
    } catch (e) {
      _finishAssistant(placeholder, 'Error: $e');
    } finally {
      _sending = false;
    }
  }

  void _finishAssistant(_Msg holder, String text) {
    final idx = _messages.indexOf(holder);
    if (idx == -1) return;
    setState(() {
      _messages[idx] = _messages[idx].copyWith(
        content: text,
        isTyping: false,
        time: DateTime.now(),
      );
    });
    _scrollToBottom();
  }

  Future<void> _typewriterInsert(_Msg holder, String fullText) async {
    const chunk = 3;
    const tick = Duration(milliseconds: 12);

    var current = '';
    final idx = _messages.indexOf(holder);
    if (idx == -1) return;

    for (int i = 0; i < fullText.length; i += chunk) {
      final end = (i + chunk < fullText.length) ? i + chunk : fullText.length;
      current += fullText.substring(i, end);

      if (!mounted) break;
      setState(() {
        _messages[idx] = _messages[idx].copyWith(content: current);
      });
      _scrollToBottom();
      await Future.delayed(tick);
    }

    if (!mounted) return;
    setState(() {
      _messages[idx] =
          _messages[idx].copyWith(isTyping: false, time: DateTime.now());
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Chat AI'),
        elevation: 0.5,
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _MessageBubble(msg: _messages[i]),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: _Composer(
              controller: _controller,
              sending: _sending,
              onSend: (txt) {
                final t = txt.trim();
                if (t.isNotEmpty) {
                  sendMessage(t);
                  _controller.clear();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Bagian _Composer, _MessageBubble, _TypingDots, dan _Msg tetap sama
class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSend;
  final bool sending;
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.sending,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autocorrect: true,
              enableSuggestions: true,
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
              decoration: InputDecoration(
                hintText: 'Ketik pesan…',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: sending ? null : () => onSend(controller.text),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Kirim'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _Msg msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    final bubbleColor = isUser ? Colors.blue[50] : Colors.grey[100];
    final borderColor = isUser ? Colors.blue[100]! : Colors.grey[300]!;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: bubbleColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isUser ? 14 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 14),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isUser ? Colors.blue : Colors.green,
                child: Icon(isUser ? Icons.person : Icons.smart_toy,
                    size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isUser ? 'You' : 'Assistant',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800]),
                        ),
                        const SizedBox(width: 8),
                        Text(_fmt(msg.time),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (msg.isTyping) const _TypingDots(),
                    if (!msg.isTyping) MarkdownMessage(text: msg.content),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

// Widget MarkdownMessage, CodeBlock, _TypingDots dan _Msg tetap sama
class MarkdownMessage extends StatelessWidget {
  final String text;
  const MarkdownMessage({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final segments = _splitMarkdown(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in segments)
          switch (s) {
            _MdSegmentText() => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: MarkdownBody(
                  selectable: true,
                  data: s.content,
                  softLineBreak: true,
                  styleSheet:
                      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    code: const TextStyle(fontFamily: 'monospace'),
                    codeblockDecoration: const BoxDecoration(),
                  ),
                ),
              ),
            _MdSegmentCode() => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CodeBlock(code: s.code, language: s.lang),
              ),
          }
      ],
    );
  }

  List<_MdSegment> _splitMarkdown(String input) {
    final lines = const LineSplitter().convert(input);
    final List<_MdSegment> out = [];
    final buffer = StringBuffer();

    bool inCode = false;
    String codeLang = '';
    final codeBuf = StringBuffer();

    for (final line in lines) {
      if (!inCode && line.trimLeft().startsWith('```')) {
        final lang =
            line.trim().length > 3 ? line.trim().substring(3).trim() : '';
        if (buffer.isNotEmpty) {
          out.add(_MdSegmentText(buffer.toString().trimRight()));
          buffer.clear();
        }
        inCode = true;
        codeLang = lang;
        continue;
      }

      if (inCode && line.trimLeft().startsWith('```')) {
        out.add(_MdSegmentCode(codeBuf.toString().trimRight(), codeLang));
        codeBuf.clear();
        inCode = false;
        codeLang = '';
        continue;
      }

      if (inCode) {
        codeBuf.writeln(line);
      } else {
        buffer.writeln(line);
      }
    }

    if (buffer.isNotEmpty) {
      out.add(_MdSegmentText(buffer.toString().trimRight()));
    }
    if (codeBuf.isNotEmpty) {
      out.add(_MdSegmentCode(codeBuf.toString().trimRight(), codeLang));
    }
    return out;
  }
}

sealed class _MdSegment {}

class _MdSegmentText extends _MdSegment {
  final String content;
  _MdSegmentText(this.content);
}

class _MdSegmentCode extends _MdSegment {
  final String code;
  final String lang;
  _MdSegmentCode(this.code, this.lang);
}

class CodeBlock extends StatelessWidget {
  final String code;
  final String language;
  const CodeBlock({super.key, required this.code, this.language = ''});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : const Color(0xFFEFF1F3),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                bottom: BorderSide(
                    color: isDark
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFE5E7EB)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.isEmpty ? 'code' : language,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: SelectableText(
              code,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a1;
  late final Animation<double> _a2;
  late final Animation<double> _a3;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _a1 = CurvedAnimation(
        parent: _c, curve: const Interval(0.0, 0.6, curve: Curves.easeInOut));
    _a2 = CurvedAnimation(
        parent: _c, curve: const Interval(0.2, 0.8, curve: Curves.easeInOut));
    _a3 = CurvedAnimation(
        parent: _c, curve: const Interval(0.4, 1.0, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dot = 7.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(_a1, dot),
        const SizedBox(width: 4),
        _dot(_a2, dot),
        const SizedBox(width: 4),
        _dot(_a3, dot),
      ],
    );
  }

  Widget _dot(Animation<double> a, double size) {
    return FadeTransition(
      opacity: a,
      child: Container(
        width: size,
        height: size,
        decoration:
            const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
      ),
    );
  }
}

class _Msg {
  final String role;
  final String content;
  final DateTime time;
  final bool isTyping;
  _Msg({
    required this.role,
    required this.content,
    required this.time,
    this.isTyping = false,
  });
  _Msg copyWith(
      {String? role, String? content, DateTime? time, bool? isTyping}) {
    return _Msg(
      role: role ?? this.role,
      content: content ?? this.content,
      time: time ?? this.time,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}
