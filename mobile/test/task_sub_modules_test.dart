import 'package:flutter_test/flutter_test.dart';
import 'package:al_nadheera_construction/models/task_model.dart';

void main() {
  group('TaskModel and Sub-Modules Tests', () {
    test('TaskModel correctly parses sub_modules from JSON', () {
      final json = {
        'id': 'task-101',
        'site_id': 'site-202',
        'title': 'make website',
        'description': 'Full stack web application project',
        'status': 'Ongoing',
        'sub_modules': [
          {
            'id': 'sub-1',
            'title': 'design',
            'status': 'Completed',
            'description': 'Wireframes and UI prototype done in Figma',
          },
          {
            'id': 'sub-2',
            'title': 'code',
            'status': 'Ongoing',
            'description': 'Frontend screens completed, integrating backend APIs',
          },
          {
            'id': 'sub-3',
            'title': 'deploy',
            'status': 'Pending',
            'description': '',
          },
        ],
      };

      final task = TaskModel.fromJson(json);

      expect(task.id, 'task-101');
      expect(task.title, 'make website');
      expect(task.subModules.length, 3);

      expect(task.subModules[0].title, 'design');
      expect(task.subModules[0].status, 'Completed');
      expect(task.subModules[0].description, 'Wireframes and UI prototype done in Figma');

      expect(task.subModules[1].title, 'code');
      expect(task.subModules[1].status, 'Ongoing');
      expect(task.subModules[1].description, 'Frontend screens completed, integrating backend APIs');

      expect(task.subModules[2].title, 'deploy');
      expect(task.subModules[2].status, 'Pending');

      // Progress & counts
      expect(task.completedSubModulesCount, 1);
      expect(task.ongoingSubModulesCount, 1);
      expect(task.pendingSubModulesCount, 1);
      expect(task.subModulesProgress, closeTo(1 / 3, 0.001));
    });

    test('TaskModel serializes sub_modules to JSON properly', () {
      final task = TaskModel(
        id: 'task-101',
        siteId: 'site-202',
        title: 'make website',
        status: 'Ongoing',
        subModules: [
          TaskSubModule(
            id: 'sub-1',
            title: 'design',
            status: 'Completed',
            description: 'UI approved',
          ),
          TaskSubModule(
            id: 'sub-2',
            title: 'code',
            status: 'Ongoing',
            description: 'Working on APIs',
          ),
          TaskSubModule(
            id: 'sub-3',
            title: 'deploy',
            status: 'Pending',
          ),
        ],
      );

      final json = task.toJson();
      expect(json['title'], 'make website');
      expect(json['sub_modules'], isA<List>());

      final subs = json['sub_modules'] as List;
      expect(subs.length, 3);
      expect(subs[0]['title'], 'design');
      expect(subs[0]['status'], 'Completed');
      expect(subs[0]['description'], 'UI approved');
      expect(subs[1]['title'], 'code');
      expect(subs[1]['status'], 'Ongoing');
      expect(subs[1]['description'], 'Working on APIs');
      expect(subs[2]['title'], 'deploy');
      expect(subs[2]['status'], 'Pending');
    });

    test('TaskModel handles legacy String array sub_modules gracefully', () {
      final json = {
        'id': 'task-102',
        'site_id': 'site-202',
        'title': 'make website',
        'status': 'Pending',
        'sub_modules': ['design', 'code', 'deploy'],
      };

      final task = TaskModel.fromJson(json);
      expect(task.subModules.length, 3);
      expect(task.subModules[0].title, 'design');
      expect(task.subModules[0].status, 'Pending');
      expect(task.subModules[1].title, 'code');
      expect(task.subModules[2].title, 'deploy');
    });

    test('TaskModel copyWith updates subModules properly', () {
      final original = TaskModel(
        id: 'task-103',
        siteId: 'site-202',
        title: 'make website',
        status: 'Pending',
        subModules: [
          TaskSubModule(id: '1', title: 'design', status: 'Pending'),
        ],
      );

      final updated = original.copyWith(
        status: 'Ongoing',
        subModules: [
          TaskSubModule(id: '1', title: 'design', status: 'Completed'),
          TaskSubModule(id: '2', title: 'code', status: 'Ongoing', description: 'In development'),
        ],
      );

      expect(updated.status, 'Ongoing');
      expect(updated.subModules.length, 2);
      expect(updated.completedSubModulesCount, 1);
      expect(updated.ongoingSubModulesCount, 1);
      expect(updated.subModulesProgress, 0.5);
    });
  });
}
