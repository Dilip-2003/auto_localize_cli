import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Manages sharded incremental file-stat caching inside `.dart_tool/auto_localize_cli/cache/`.
///
/// Divides file stats across 256 lightweight JSON shards to eliminate single large
/// cache file bottlenecks in repositories with 100,000 to 50M+ files.
class IncrementalCacheManager {
  /// The root project directory.
  final Directory projectDir;

  /// Whether incremental caching is active.
  final bool enabled;

  /// Cache directory containing the shards.
  late final Directory cacheDir;

  final Map<String, Map<String, String>> _shards = {};
  final Set<String> _dirtyShards = {};

  /// Creates an [IncrementalCacheManager] for [projectDir].
  IncrementalCacheManager({
    required this.projectDir,
    this.enabled = true,
  }) {
    cacheDir = Directory(
      p.join(projectDir.path, '.dart_tool', 'auto_localize_cli', 'cache'),
    );
  }

  /// Calculates a deterministic 2-character hex shard key (00 to ff) for [relativePath].
  String _getShardKey(String relativePath) {
    var hash = 0;
    final normalized = relativePath.replaceAll(r'\', '/');
    for (var i = 0; i < normalized.length; i++) {
      hash = (hash * 31 + normalized.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return (hash & 0xFF).toRadixString(16).padLeft(2, '0');
  }

  /// Loads a shard lazily into memory.
  Map<String, String> _loadShard(String shardKey) {
    if (_shards.containsKey(shardKey)) {
      return _shards[shardKey]!;
    }

    final shardFile = File(p.join(cacheDir.path, 'shard_$shardKey.json'));
    if (shardFile.existsSync()) {
      try {
        final content = shardFile.readAsStringSync();
        final data = jsonDecode(content);
        if (data is Map) {
          final map = data.map((k, v) => MapEntry(k.toString(), v.toString()));
          _shards[shardKey] = map;
          return map;
        }
      } catch (_) {
        // Corrupted shard, start fresh
      }
    }

    final map = <String, String>{};
    _shards[shardKey] = map;
    return map;
  }

  /// Checks if the file at [relativePath] is clean (unmodified since last scan).
  bool isFileClean(String relativePath, FileStat stat) {
    if (!enabled) return false;
    final normalized = relativePath.replaceAll(r'\', '/');
    final shardKey = _getShardKey(normalized);
    final shard = _loadShard(shardKey);
    final cachedVal = shard[normalized];
    if (cachedVal == null) return false;

    final currentVal = '${stat.modified.microsecondsSinceEpoch}:${stat.size}';
    return cachedVal == currentVal;
  }

  /// Records that the file at [relativePath] has been verified or updated.
  void recordFileClean(String relativePath, FileStat stat) {
    if (!enabled) return;
    final normalized = relativePath.replaceAll(r'\', '/');
    final shardKey = _getShardKey(normalized);
    final shard = _loadShard(shardKey);
    final val = '${stat.modified.microsecondsSinceEpoch}:${stat.size}';

    if (shard[normalized] != val) {
      shard[normalized] = val;
      _dirtyShards.add(shardKey);
    }
  }

  /// Writes all modified shards to disk.
  Future<void> flush() async {
    if (!enabled || _dirtyShards.isEmpty) return;
    try {
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      for (final shardKey in _dirtyShards) {
        final shard = _shards[shardKey];
        if (shard != null) {
          final shardFile = File(p.join(cacheDir.path, 'shard_$shardKey.json'));
          await shardFile.writeAsString(jsonEncode(shard));
        }
      }
      _dirtyShards.clear();
    } catch (_) {
      // Non-critical, ignore write errors
    }
  }
}
