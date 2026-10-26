import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIProposal {
  final String action; // "create_task", "create_time_block", "batch_create", "conversation"
  final List<AITaskItem> tasks;
  final List<AITimeBlockItem> timeBlocks;
  final String? message;

  const AIProposal({
    required this.action,
    this.tasks = const [],
    this.timeBlocks = const [],
    this.message,
  });

  factory AIProposal.fromJson(Map<String, dynamic> json, {String? conversationalMessage}) {
    final tasksList = (json['tasks'] as List<dynamic>?)
            ?.map((e) => AITaskItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final blocksList = (json['timeBlocks'] as List<dynamic>?)
            ?.map((e) => AITimeBlockItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return AIProposal(
      action: json['action'] as String? ?? 'create_task',
      tasks: tasksList,
      timeBlocks: blocksList,
      message: conversationalMessage ?? json['message'] as String?,
    );
  }
}

class AITaskItem {
  final String title;
  final String subject;
  final String column;
  final List<String> badges;
  final DateTime? dueDate;
  final DateTime? toDoDate;
  final List<String> subtasks;

  const AITaskItem({
    required this.title,
    required this.subject,
    required this.column,
    required this.badges,
    this.dueDate,
    this.toDoDate,
    required this.subtasks,
  });

  factory AITaskItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDueDate;
    if (json['dueDate'] != null) {
      try {
        parsedDueDate = DateTime.parse(json['dueDate'] as String);
      } catch (_) {}
    }

    DateTime? parsedToDoDate;
    if (json['toDoDate'] != null) {
      try {
        parsedToDoDate = DateTime.parse(json['toDoDate'] as String);
      } catch (_) {}
    }

    final subtasks = (json['subtasks'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final badges = (json['badges'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return AITaskItem(
      title: json['title'] as String? ?? 'Untitled Task',
      subject: json['subject'] as String? ?? 'GEN',
      column: json['column'] as String? ?? 'Do Soon',
      badges: badges,
      dueDate: parsedDueDate,
      toDoDate: parsedToDoDate,
      subtasks: subtasks,
    );
  }
}

class AITimeBlockItem {
  final String title;
  final DateTime startTime;
  final DateTime endTime;

  const AITimeBlockItem({
    required this.title,
    required this.startTime,
    required this.endTime,
  });

  factory AITimeBlockItem.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    DateTime start = now.add(const Duration(hours: 1));
    DateTime end = start.add(const Duration(minutes: 60));

    if (json['startTime'] != null) {
      try {
        start = DateTime.parse(json['startTime'] as String);
      } catch (_) {}
    }
    if (json['endTime'] != null) {
      try {
        end = DateTime.parse(json['endTime'] as String);
      } catch (_) {}
    }

    return AITimeBlockItem(
      title: json['title'] as String? ?? 'Focus Session',
      startTime: start,
      endTime: end,
    );
  }
}

class GeminiService {
  // Primary model specified by user, with graceful fallback to standard Flash models if 500 occurs
  static const String textModelCode = 'gemini-3.5-flash-lite';
  static const List<String> candidateModels = [
    'gemini-3.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
  ];

  static const _systemInstruction = '''
You are TEMPO AI, a strict, high-efficiency personal executive assistant powered by Gemini.
You have real-time awareness of the user's Kanban board, active tasks, subtasks, and calendar time blocks provided in the context.

STRICT INSTRUCTIONS:
1. When user asks questions about their current tasks or schedule (e.g. "What do I need to do?", "Summarize Doing Now", "When is my next block?"), answer directly, concisely, and accurately based on the active tasks and time blocks in the context.
2. When user asks to create, organize, or schedule new tasks or time blocks (e.g. "Plan study session tomorrow at 3pm", "Break down task X into 3 subtasks"), return ONLY valid JSON matching this schema:

{
  "action": "create_task" | "create_time_block" | "batch_create",
  "tasks": [
    {
      "title": "Shortfilm Script Draft",
      "subject": "SCI",
      "column": "Doing Now" | "Do Soon" | "Plan Later",
      "badges": ["ASAP", "High Effort", "Individual"],
      "toDoDate": "2026-10-27T10:00:00Z",
      "dueDate": "2026-10-30T17:00:00Z",
      "subtasks": ["Brainstorm theme", "Outline plot", "Draft scenes 1-3"]
    }
  ],
  "timeBlocks": [
    {
      "title": "Focus: Script Drafting [SCI]",
      "startTime": "2026-10-27T15:00:00Z",
      "endTime": "2026-10-27T16:30:00Z"
    }
  ]
}

3. Task titles: max 5-6 words. Subtasks: max 3-5 words.
4. "toDoDate" is when the task is scheduled to be done, while "dueDate" is the final deadline. Both can be specified or null.
5. Time blocks: realistic durations (30m, 45m, 60m, 90m) with precise ISO 8601 timestamps.
''';

  static Future<bool> testConnection(String apiKey, {String modelName = textModelCode}) async {
    final modelsToTry = [modelName, ...candidateModels.where((m) => m != modelName)];
    for (final code in modelsToTry) {
      try {
        final model = GenerativeModel(
          model: code,
          apiKey: apiKey,
        );
        final response = await model.generateContent([
          Content.text('Hello! Respond with OK.'),
        ]);
        if (response.text != null && response.text!.isNotEmpty) {
          return true;
        }
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  static Future<AIProposal> parseInput({
    required String apiKey,
    required String prompt,
    String? workspaceContext,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
  }) async {
    final buffer = StringBuffer();
    if (workspaceContext != null && workspaceContext.isNotEmpty) {
      buffer.writeln('--- CURRENT WORKSPACE CONTEXT ---');
      buffer.writeln(workspaceContext);
      buffer.writeln('--------------------------------\n');
    }
    buffer.writeln('USER QUERY: ${prompt.isNotEmpty ? prompt : 'Extract tasks and schedule blocks.'}');

    final List<Part> parts = [];
    if (imageBytes != null) {
      parts.add(DataPart(imageMimeType, imageBytes));
    }
    parts.add(TextPart(buffer.toString()));

    Exception? lastException;
    for (final modelCode in candidateModels) {
      try {
        final model = GenerativeModel(
          model: modelCode,
          apiKey: apiKey,
          systemInstruction: Content.system(_systemInstruction),
        );

        final response = await model.generateContent([Content.multi(parts)]);
        final rawText = response.text ?? '';
        return _extractProposal(rawText);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        // Retry with next fallback model if 500 or model not available
        continue;
      }
    }

    throw lastException ?? Exception('Failed to connect to Gemini API.');
  }

  static AIProposal _extractProposal(String rawText) {
    if (rawText.trim().isEmpty) {
      return const AIProposal(action: 'conversation', message: 'Ready for tasks or time blocks.');
    }

    final startIdx = rawText.indexOf('{');
    final endIdx = rawText.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      final jsonStr = rawText.substring(startIdx, endIdx + 1);
      try {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return AIProposal.fromJson(decoded);
      } catch (_) {}
    }

    // Conversational query response
    return AIProposal(
      action: 'conversation',
      message: rawText.trim(),
    );
  }
}
