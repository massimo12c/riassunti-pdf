import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PdfRiassuntiApp());
}

class PdfRiassuntiApp extends StatelessWidget {
  const PdfRiassuntiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riassunti PDF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.lightBlue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  String _clock = '';
  String? _pdfName;
  String _extractedText = '';
  bool _loading = false;

  final _notesController = TextEditingController();
  List<BookNote> _savedNotes = [];

  @override
  void initState() {
    super.initState();
    _tickClock();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tickClock());
    _loadNotes();
  }

  void _tickClock() {
    final now = DateTime.now();
    final fmt = DateFormat('HH:mm:ss  •  dd/MM/yyyy');
    setState(() => _clock = fmt.format(now));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfAndExtract() async {
    setState(() {
      _loading = true;
      _pdfName = null;
      _extractedText = '';
    });

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );

      if (res == null || res.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final file = res.files.single;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _loading = false;
          _extractedText = 'Errore: non riesco a leggere il file.';
        });
        return;
      }

      final extracted = _extractTextFromPdfBytes(bytes);

      setState(() {
        _pdfName = file.name;
        _extractedText = extracted.trim().isEmpty
            ? 'Nessun testo trovato. Probabile PDF scannerizzato/immagine.'
            : extracted;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _extractedText = 'Errore durante lettura PDF: $e';
      });
    }
  }

  String _extractTextFromPdfBytes(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();
    return text;
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('book_notes');
    if (raw == null) return;
    final list = (jsonDecode(raw) as List)
        .map((e) => BookNote.fromJson(e as Map<String, dynamic>))
        .toList();
    setState(() => _savedNotes = list);
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_savedNotes.map((e) => e.toJson()).toList());
    await prefs.setString('book_notes', raw);
  }

  Future<void> _addNote() async {
    final text = _notesController.text.trim();
    if (text.isEmpty) return;

    final note = BookNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      text: text,
      pdfName: _pdfName,
    );

    setState(() {
      _savedNotes.insert(0, note);
      _notesController.clear();
    });

    await _saveNotes();
  }

  Future<void> _deleteNote(String id) async {
    setState(() => _savedNotes.removeWhere((n) => n.id == id));
    await _saveNotes();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD9F2FF), Color(0xFF8FD3FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Riassunti PDF (manuali)',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(blurRadius: 10, offset: Offset(0, 4))
                            ],
                          ),
                          child: Text(
                            _clock,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _loading ? null : _pickPdfAndExtract,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: Text(_loading ? 'Carico...' : 'Scegli PDF'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_pdfName != null)
                            Text('PDF: $_pdfName',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          const Text('Testo estratto:',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Container(
                            height: 190,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.8)),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                _extractedText.isEmpty
                                    ? 'Seleziona un PDF per vedere il testo.'
                                    : _extractedText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'I tuoi riassunti (scritti da te)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _notesController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText:
                                  'Scrivi un riassunto / appunto (nessuna AI)...',
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.85),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _addNote,
                            icon: const Icon(Icons.save),
                            label: const Text('Salva appunto'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Appunti salvati:',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _savedNotes.isEmpty
                                ? const Center(
                                    child: Text('Nessun appunto salvato.',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700)),
                                  )
                                : ListView.separated(
                                    itemCount: _savedNotes.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, i) {
                                      final n = _savedNotes[i];
                                      final when = DateFormat('dd/MM HH:mm')
                                          .format(n.createdAt.toLocal());
                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.85),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '$when${n.pdfName == null ? '' : ' • ${n.pdfName}'}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Elimina',
                                                  onPressed: () =>
                                                      _deleteNote(n.id),
                                                  icon: const Icon(
                                                      Icons.delete_outline),
                                                ),
                                              ],
                                            ),
                                            SelectableText(n.text),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
        boxShadow: const [BoxShadow(blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }
}

class BookNote {
  final String id;
  final DateTime createdAt;
  final String text;
  final String? pdfName;

  BookNote({
    required this.id,
    required this.createdAt,
    required this.text,
    required this.pdfName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'text': text,
        'pdfName': pdfName,
      };

  static BookNote fromJson(Map<String, dynamic> json) => BookNote(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        text: json['text'] as String,
        pdfName: json['pdfName'] as String?,
      );
}
