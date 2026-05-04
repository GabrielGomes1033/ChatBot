import 'chat_api.dart';

class MemoryService {
  MemoryService({
    required ChatApiService api,
  }) : _api = api;

  final ChatApiService _api;

  Future<Map<String, dynamic>> openMemory({
    required String userId,
    int limit = 8,
  }) {
    return _api.openMemoryPanel(userId: userId, limit: limit);
  }

  Future<Map<String, dynamic>> loadWorkspaceSnapshot({
    required String userId,
  }) async {
    final recent = await _api.getRecentMemory(userId: userId, limit: 6);
    final notes = await _api.getBrainNotes(limit: 4);
    final suggestions = await _api.getBrainSuggestions(limit: 4);
    final graph = await _api.getBrainGraph();
    return {
      'recent_memories': recent,
      'notes': notes,
      'suggestions': suggestions,
      'graph': graph,
    };
  }
}
