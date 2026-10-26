import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/features/copilot/services/gemini_service.dart';

void main() {
  group('AI Proposal JSON Parser Tests', () {
    test('Parses structured JSON proposal matching exact schema', () {
      final jsonMap = {
        "action": "batch_create",
        "tasks": [
          {
            "title": "Shortfilm Script Draft",
            "subject": "SCI",
            "column": "Do Soon",
            "badges": ["Do THIS WEEK", "Hard/Heavy", "Groupings"],
            "dueDate": "2026-10-30T17:00:00Z",
            "subtasks": ["Brainstorm theme", "Outline plot", "Draft scenes 1-3"]
          }
        ],
        "timeBlocks": [
          {
            "title": "Brainstorm theme [SCI]",
            "startTime": "2026-10-27T15:00:00Z",
            "endTime": "2026-10-27T16:30:00Z"
          }
        ]
      };

      final proposal = AIProposal.fromJson(jsonMap);

      expect(proposal.action, equals('batch_create'));
      expect(proposal.tasks.length, equals(1));

      final task = proposal.tasks.first;
      expect(task.title, equals('Shortfilm Script Draft'));
      expect(task.subject, equals('SCI'));
      expect(task.badges.length, equals(3));
      expect(task.subtasks.length, equals(3));
      expect(task.subtasks[0], equals('Brainstorm theme'));

      expect(proposal.timeBlocks.length, equals(1));
      final block = proposal.timeBlocks.first;
      expect(block.title, equals('Brainstorm theme [SCI]'));
      expect(block.startTime.isUtc, isTrue);
      expect(block.endTime.difference(block.startTime).inMinutes, equals(90));
    });
  });
}

