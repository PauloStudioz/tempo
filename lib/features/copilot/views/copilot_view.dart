import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/tempo_toast.dart';
import '../../../providers/tempo_providers.dart';
import '../services/gemini_service.dart';
import '../services/local_stt_service.dart';
import '../widgets/ai_proposal_card.dart';
import '../widgets/typing_indicator.dart';

class ChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final Uint8List? imageBytes;
  final String? imageName;
  final AIProposal? proposal;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    this.imageBytes,
    this.imageName,
    this.proposal,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'isUser': isUser,
        'text': text,
        'imageName': imageName,
        'imageBase64': (imageBytes != null && imageBytes!.length < 3 * 1024 * 1024)
            ? base64Encode(imageBytes!)
            : null,
        'timestamp': timestamp.toIso8601String(),
        'proposal': proposal != null
            ? {
                'action': proposal!.action,
                'tasks': proposal!.tasks
                    .map((t) => {
                          'title': t.title,
                          'subject': t.subject,
                          'column': t.column,
                          'badges': t.badges,
                          'toDoDate': t.toDoDate?.toIso8601String(),
                          'dueDate': t.dueDate?.toIso8601String(),
                          'subtasks': t.subtasks,
                        })
                    .toList(),
                'timeBlocks': proposal!.timeBlocks
                    .map((b) => {
                          'title': b.title,
                          'startTime': b.startTime.toIso8601String(),
                          'endTime': b.endTime.toIso8601String(),
                        })
                    .toList(),
                'message': proposal!.message,
              }
            : null,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    AIProposal? prop;
    if (json['proposal'] != null) {
      prop = AIProposal.fromJson(json['proposal'] as Map<String, dynamic>);
    }
    Uint8List? imgBytes;
    if (json['imageBase64'] != null) {
      try {
        imgBytes = base64Decode(json['imageBase64'] as String);
      } catch (_) {}
    }
    return ChatMessage(
      id: json['id'] as String? ?? const Uuid().v4(),
      isUser: json['isUser'] as bool? ?? false,
      text: json['text'] as String? ?? '',
      imageBytes: imgBytes,
      imageName: json['imageName'] as String?,
      proposal: prop,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }
}

class CopilotView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenSettings;

  const CopilotView({super.key, this.onOpenSettings});

  @override
  ConsumerState<CopilotView> createState() => _CopilotViewState();
}

class _CopilotViewState extends ConsumerState<CopilotView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isLoading = false;
  bool _isRecordingVoice = false;
  bool _isTranscribingVoice = false;
  Uint8List? _attachedImageBytes;
  String? _attachedImageName;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<File> _getChatFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/tempo_chat_history.json');
  }

  Future<void> _loadChatHistory() async {
    try {
      final file = await _getChatFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content) as List<dynamic>;
        final loaded = list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
        if (loaded.isNotEmpty) {
          setState(() {
            _messages.clear();
            _messages.addAll(loaded);
          });
          return;
        }
      }
    } catch (_) {}

    if (_messages.isEmpty) {
      setState(() {
        _messages.add(
          ChatMessage(
            id: 'welcome',
            isUser: false,
            text: 'TEMPO AI Assistant ready.\n\nTell me what you need to get done, and I will strictly extract concise tasks, actionable subtasks, and schedule focus blocks onto your calendar.',
          ),
        );
      });
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final file = await _getChatFile();
      final data = jsonEncode(_messages.map((m) => m.toJson()).toList());
      await file.writeAsString(data);
    } catch (_) {}
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _pickAttachment() async {
    HapticFeedback.lightImpact();
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        if (mounted) {
          setState(() {
            _attachedImageBytes = bytes;
            _attachedImageName = file.name;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _handlePaste() async {
    HapticFeedback.lightImpact();

    Uint8List? detectedImageBytes;
    String? detectedImageName;

    // 1. Try reading raw image from clipboard via Pasteboard
    try {
      final bytes = await Pasteboard.image;
      if (bytes != null && bytes.isNotEmpty) {
        detectedImageBytes = bytes;
        detectedImageName = 'Pasted image (${(bytes.length / 1024).toStringAsFixed(1)} KB)';
      }
    } catch (_) {}

    // 2. Try reading image files copied in clipboard via Pasteboard
    if (detectedImageBytes == null) {
      try {
        final files = await Pasteboard.files();
        if (files.isNotEmpty) {
          final imageExtensions = ['.png', '.jpg', '.jpeg', '.webp', '.bmp', '.gif'];
          for (final filePath in files) {
            final lower = filePath.toLowerCase();
            if (imageExtensions.any((ext) => lower.endsWith(ext))) {
              final file = File(filePath);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                if (bytes.isNotEmpty) {
                  detectedImageBytes = bytes;
                  detectedImageName = filePath.split(Platform.pathSeparator).last;
                  break;
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback on Windows: PowerShell System.Windows.Forms.Clipboard (100% reliable native fallback)
    if (detectedImageBytes == null && Platform.isWindows) {
      try {
        const psScript = r'''
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
    $img = [System.Windows.Forms.Clipboard]::GetImage()
    if ($img -ne $null) {
        $temp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "tempo_clip_" + [System.Guid]::NewGuid().ToString() + ".png")
        $img.Save($temp, [System.Drawing.Imaging.ImageFormat]::Png)
        $img.Dispose()
        [Console]::Out.Write($temp)
    }
}
''';
        final result = await Process.run(
          'powershell',
          ['-NoProfile', '-NonInteractive', '-Command', psScript],
        );
        final tempPath = result.stdout.toString().trim();
        if (tempPath.isNotEmpty) {
          final tempFile = File(tempPath);
          if (await tempFile.exists()) {
            final bytes = await tempFile.readAsBytes();
            if (bytes.isNotEmpty) {
              detectedImageBytes = bytes;
              detectedImageName = 'Pasted screenshot (${(bytes.length / 1024).toStringAsFixed(1)} KB)';
            }
            try {
              await tempFile.delete();
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    // If an image was retrieved from clipboard, attach it just like uploading an image!
    if (detectedImageBytes != null && mounted) {
      setState(() {
        _attachedImageBytes = detectedImageBytes;
        _attachedImageName = detectedImageName ?? 'Attached image';
      });
      TempoToast.show(context, 'Image attached from clipboard');
      return;
    }

    // 4. If no image found, check and paste text from clipboard
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final textToInsert = clipboardData?.text;
      if (textToInsert != null && textToInsert.isNotEmpty && mounted) {
        final currentText = _textController.text;
        final selection = _textController.selection;

        if (selection.isValid && selection.start >= 0 && selection.end <= currentText.length) {
          final before = currentText.substring(0, selection.start);
          final after = currentText.substring(selection.end);
          _textController.text = '$before$textToInsert$after';
          _textController.selection = TextSelection.collapsed(offset: selection.start + textToInsert.length);
        } else {
          _textController.text = '$currentText$textToInsert';
          _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleListening() async {
    HapticFeedback.lightImpact();
    if (_isRecordingVoice) {
      // Stop recording and transcribe
      try {
        final path = await _audioRecorder.stop();
        if (!mounted) return;
        setState(() {
          _isRecordingVoice = false;
          _isTranscribingVoice = true;
        });

        if (path != null && File(path).existsSync()) {
          final transcribedText = await LocalSttService.transcribe(path);
          if (!mounted) return;
          if (transcribedText.trim().isNotEmpty) {
            final current = _textController.text;
            final space = (current.isNotEmpty && !current.endsWith(' ')) ? ' ' : '';
            _textController.text = '$current$space$transcribedText';
            _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
            TempoToast.show(context, 'Transcribed: "$transcribedText"');
          } else {
            TempoToast.show(context, 'No speech detected in audio.');
          }
        }
      } catch (e) {
        if (mounted) {
          TempoToast.show(context, 'STT error: $e', isError: true);
        }
      } finally {
        if (mounted) {
          setState(() => _isTranscribingVoice = false);
        }
      }
    } else {
      // Start recording
      try {
        final hasPermission = await _audioRecorder.hasPermission();
        if (!hasPermission) {
          TempoToast.show(context, 'Microphone permission denied.', isError: true);
          return;
        }

        if (!LocalSttService.isModelAvailable()) {
          TempoToast.show(
            context,
            'Local Whisper model not found in models/stt/. Please place your model there.',
            isError: true,
          );
          return;
        }

        final tempDir = await getTemporaryDirectory();
        final wavPath = '${tempDir.path}/tempo_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: wavPath,
        );

        if (mounted) {
          setState(() => _isRecordingVoice = true);
        }
      } catch (e) {
        if (mounted) {
          TempoToast.show(context, 'Could not start recording: $e', isError: true);
        }
      }
    }
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _attachedImageBytes == null) return;

    final apiKeyAsync = ref.read(apiKeyProvider);
    final apiKey = apiKeyAsync.value;

    if (apiKey == null || apiKey.isEmpty) {
      TempoToast.show(
        context,
        'Configure your API Key in Settings first.',
        isError: true,
      );
      return;
    }

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isUser: true,
      text: text,
      imageBytes: _attachedImageBytes,
      imageName: _attachedImageName,
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _textController.clear();
      _attachedImageBytes = null;
      _attachedImageName = null;
    });

    _scrollToBottom();

    try {
      final tasks = ref.read(tasksStreamProvider).value ?? [];
      final timeBlocks = ref.read(timeBlocksStreamProvider).value ?? [];
      final columns = ref.read(columnsStreamProvider).value ?? [];

      final sb = StringBuffer();
      sb.writeln('Columns: ${columns.map((c) => c.title).join(", ")}');
      sb.writeln('Current Local Time: ${DateTime.now().toIso8601String()}');
      sb.writeln('\nACTIVE TASKS ON BOARD:');
      for (final t in tasks) {
        final subList = t.subtasks.map((s) => '${s.title} [${s.isCompleted ? "DONE" : "PENDING"}]').join(', ');
        final toDoStr = t.toDoDate?.toIso8601String() ?? "None";
        final dueStr = t.dueDate?.toIso8601String() ?? "None";
        sb.writeln('- [${t.subjectCode}] "${t.title}" (Column: ${t.columnId}, To-Do Date: $toDoStr, Due Date / Deadline: $dueStr, Subtasks: $subList)');
      }
      sb.writeln('\nSCHEDULED TIME BLOCKS:');
      for (final b in timeBlocks) {
        sb.writeln('- "${b.title}" (${b.startTime.toLocal()} to ${b.endTime.toLocal()})');
      }

      final proposal = await GeminiService.parseInput(
        apiKey: apiKey,
        prompt: text,
        workspaceContext: sb.toString(),
        imageBytes: userMessage.imageBytes,
      );

      final totalItems = proposal.tasks.length + proposal.timeBlocks.length;
      final String responseText;
      if (totalItems > 0) {
        responseText = 'Generated $totalItems structured item${totalItems > 1 ? 's' : ''}. Review and tap "Apply to Board":';
      } else if (proposal.message != null && proposal.message!.isNotEmpty) {
        responseText = proposal.message!;
      } else {
        responseText = 'Ready for tasks or time blocks. Please specify what you would like to schedule.';
      }

      final aiMessage = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        isUser: false,
        text: responseText,
        proposal: totalItems > 0 ? proposal : null,
      );

      if (mounted) {
        setState(() {
          _messages.add(aiMessage);
          _isLoading = false;
        });
        _scrollToBottom();
        _saveChatHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
              isUser: false,
              text: 'Unable to connect to AI: $e\n\nPlease verify your Gemini API key in Settings.',
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
        _saveChatHistory();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = ref.watch(customAccentColorProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'AI Co-Pilot',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Strict & Concise',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: accentColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear Chat History',
                    icon: Icon(CupertinoIcons.trash, size: 14, color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                    onPressed: () async {
                      setState(() {
                        _messages.clear();
                        _messages.add(
                          ChatMessage(
                            id: 'welcome',
                            isUser: false,
                            text: 'TEMPO AI Assistant ready.\n\nTell me what you need to get done, and I will strictly extract concise tasks, actionable subtasks, and schedule focus blocks onto your calendar.',
                          ),
                        );
                      });
                      await _saveChatHistory();
                    },
                  ),
                ],
              ),
            ),

            // Chat Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageBubble(msg, isDark, accentColor);
                },
              ),
            ),

            // Loading state indicator (Facebook Messenger style jumping 3-dot bubble)
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TypingIndicatorBubble(accentColor: accentColor),
              ),

            // Voice Recording Status Banner
            if (_isRecordingVoice)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35), width: 0.8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recording voice with local Whisper... Speak now.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleListening,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Done',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Voice Transcribing Status Banner
            if (_isTranscribingVoice)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.30), width: 0.8),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Transcribing audio locally (${LocalSttService.getModelName() ?? "Whisper"})...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Input Bar
            Container(
              margin: const EdgeInsets.all(12),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.keyV, control: true): _handlePaste,
                  const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _handlePaste,
                },
                child: GlassContainer(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  backgroundColor: isDark
                      ? TempoTheme.surfaceElevated.withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.94),
                  borderColor: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Attachment preview
                      if (_attachedImageBytes != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _attachedImageBytes!,
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(CupertinoIcons.photo, size: 20, color: accentColor),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _attachedImageName ?? 'Attached Image',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${(_attachedImageBytes!.length / 1024).toStringAsFixed(1)} KB • Attached & ready to send',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() {
                                  _attachedImageBytes = null;
                                  _attachedImageName = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(CupertinoIcons.xmark, size: 12, color: isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      Row(
                        children: [
                          // Attachment Button
                          IconButton(
                            onPressed: _pickAttachment,
                            icon: const Icon(CupertinoIcons.paperclip, size: 17),
                            color: _attachedImageBytes != null
                                ? accentColor
                                : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                            tooltip: 'Attach syllabus or image',
                          ),

                          // Paste (Image / Text) from Clipboard Button
                          IconButton(
                            onPressed: _handlePaste,
                            icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 17),
                            color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                            tooltip: 'Paste image or text from clipboard (⌘V / Ctrl+V)',
                          ),

                          // Voice Input (Microphone) with Local STT
                          IconButton(
                            onPressed: _toggleListening,
                            icon: Icon(
                              _isRecordingVoice
                                  ? CupertinoIcons.stop_circle_fill
                                  : CupertinoIcons.mic,
                              size: 18,
                            ),
                            color: _isRecordingVoice
                                ? Colors.redAccent
                                : (_isTranscribingVoice
                                    ? accentColor
                                    : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted)),
                            tooltip: _isRecordingVoice
                                ? 'Stop recording & transcribe'
                                : 'Voice input (Local Whisper STT)',
                          ),

                          // Text Field with robust Actions & Context Menu paste support
                          Expanded(
                            child: Actions(
                              actions: {
                                PasteTextIntent: CallbackAction<PasteTextIntent>(
                                  onInvoke: (intent) {
                                    _handlePaste();
                                    return null;
                                  },
                                ),
                              },
                              child: TextField(
                                controller: _textController,
                                onSubmitted: (_) => _sendMessage(),
                                contextMenuBuilder: (context, editableTextState) {
                                  final List<ContextMenuButtonItem> buttonItems =
                                      editableTextState.contextMenuButtonItems;
                                  final pasteIndex = buttonItems
                                      .indexWhere((item) => item.type == ContextMenuButtonType.paste);
                                  if (pasteIndex >= 0) {
                                    buttonItems[pasteIndex] = ContextMenuButtonItem(
                                      type: ContextMenuButtonType.paste,
                                      onPressed: () {
                                        editableTextState.hideToolbar();
                                        _handlePaste();
                                      },
                                    );
                                  }
                                  return AdaptiveTextSelectionToolbar.buttonItems(
                                    anchors: editableTextState.contextMenuAnchors,
                                    buttonItems: buttonItems,
                                  );
                                },
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Schedule 1h study block for tomorrow 2pm...',
                                  hintStyle: TextStyle(
                                    color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                    fontSize: 12,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                ),
                              ),
                            ),
                          ),

                          // Send Button
                          IconButton(
                            onPressed: _sendMessage,
                            icon: const Icon(CupertinoIcons.arrow_up_circle_fill, size: 24),
                            color: accentColor,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark, Color accentColor) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (msg.imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    msg.imageBytes!,
                    width: 220,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 6),
              ] else if (msg.imageName != null) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.paperclip, size: 11, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      msg.imageName!,
                      style: TextStyle(fontSize: 10.5, color: accentColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Text(
                msg.text,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(bottom: 12, right: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassContainer(
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: isDark ? TempoTheme.surfaceDark.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.85),
              borderColor: Colors.transparent,
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                  height: 1.35,
                ),
              ),
            ),
            if (msg.proposal != null) ...[
              const SizedBox(height: 6),
              AIProposalCard(
                proposal: msg.proposal!,
                onDismiss: () {
                  setState(() {
                    _messages.remove(msg);
                  });
                },
              ),
            ],
          ],
        ),
      );
    }
  }
}
