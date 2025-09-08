import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'debug_service.dart';

class ActivityService {
  static final ActivityService _instance = ActivityService._internal();
  factory ActivityService() => _instance;
  ActivityService._internal();

  static const String _activityKey = 'recent_activities';
  static const int _maxActivities = 50; // Store up to 50 items for history
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    DebugService().log('ACTIVITY', 'Activity service initialized');
  }

  Future<List<Map<String, dynamic>>> getActivities() async {
    await initialize();

    try {
      final String? activitiesJson = _prefs!.getString(_activityKey);
      if (activitiesJson == null) {
        DebugService().log('ACTIVITY', 'No stored activities found');
        return [];
      }

      final List<dynamic> activitiesList = json.decode(activitiesJson);
      final List<Map<String, dynamic>> activities =
          activitiesList.cast<Map<String, dynamic>>();

      DebugService().log('ACTIVITY', 'Loaded activities', data: {
        'count': activities.length,
      });

      return activities;
    } catch (e) {
      DebugService().logError('ACTIVITY', 'Error loading activities', error: e);
      return [];
    }
  }

  Future<void> addActivity(Map<String, dynamic> activity) async {
    await initialize();

    try {
      List<Map<String, dynamic>> activities = await getActivities();

      // Add timestamp if not present
      if (!activity.containsKey('timestamp')) {
        activity['timestamp'] = DateTime.now().toIso8601String();
      }

      // Add to beginning of list
      activities.insert(0, activity);

      // Keep only the last _maxActivities
      if (activities.length > _maxActivities) {
        activities = activities.sublist(0, _maxActivities);
      }

      // Save to preferences
      final String activitiesJson = json.encode(activities);
      await _prefs!.setString(_activityKey, activitiesJson);

      DebugService().log('ACTIVITY', 'Activity added', data: {
        'type': activity['type'] ?? 'unknown',
        'totalActivities': activities.length,
      });
    } catch (e) {
      DebugService().logError('ACTIVITY', 'Error adding activity', error: e);
    }
  }

  Future<void> saveActivities(List<Map<String, dynamic>> activities) async {
    await initialize();

    try {
      // Keep only the last _maxActivities
      final limitedActivities = activities.length > _maxActivities
          ? activities.sublist(0, _maxActivities)
          : activities;

      // Save to preferences
      final String activitiesJson = json.encode(limitedActivities);
      await _prefs!.setString(_activityKey, activitiesJson);

      DebugService().log('ACTIVITY', 'Activities saved', data: {
        'totalActivities': limitedActivities.length,
      });
    } catch (e) {
      DebugService().logError('ACTIVITY', 'Error saving activities', error: e);
    }
  }

  Future<void> clearActivities() async {
    await initialize();

    try {
      await _prefs!.remove(_activityKey);
      DebugService().log('ACTIVITY', 'All activities cleared');
    } catch (e) {
      DebugService()
          .logError('ACTIVITY', 'Error clearing activities', error: e);
    }
  }
}
