import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef BuildTriggerHandler =
    Future<RemoteBuildTriggerResult> Function(BuildTriggerRequest request);

class BuildTriggerRequest {
  const BuildTriggerRequest({
    this.project,
    this.scenario,
    required this.branch,
  });

  final String? project;
  final String? scenario;
  final String branch;
}

class RemoteBuildTriggerResult {
  const RemoteBuildTriggerResult.accepted({
    required this.projectName,
    required this.scenarioName,
    required this.branch,
    required this.score,
  }) : accepted = true,
       statusCode = HttpStatus.accepted,
       message = 'Build queued';

  const RemoteBuildTriggerResult.rejected({
    required this.statusCode,
    required this.message,
  }) : accepted = false,
       projectName = null,
       scenarioName = null,
       branch = null,
       score = null;

  final bool accepted;
  final int statusCode;
  final String message;
  final String? projectName;
  final String? scenarioName;
  final String? branch;
  final double? score;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'accepted': accepted,
      'message': message,
      if (projectName != null) 'project': projectName,
      if (scenarioName != null) 'scenario': scenarioName,
      if (branch != null) 'branch': branch,
      if (score != null) 'score': score,
    };
  }
}

class BuildTriggerServer {
  BuildTriggerServer({
    required this.onTrigger,
    this.host = '127.0.0.1',
    this.port = 8765,
  });

  final String host;
  int port;
  final BuildTriggerHandler onTrigger;
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;

  Future<void> start() async {
    if (_server != null) {
      return;
    }
    final server = await HttpServer.bind(host, port);
    _server = server;
    port = server.port;
    _subscription = server.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method != 'POST' || request.uri.path != '/build') {
      _writeJson(request, HttpStatus.notFound, <String, Object?>{
        'accepted': false,
        'message': 'Not found',
      });
      return;
    }

    try {
      final payload = await utf8.decodeStream(request);
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        _writeBadRequest(request, 'Request body must be a JSON object');
        return;
      }
      final project = decoded['project'];
      final scenario = decoded['scenario'];
      final branch = decoded['branch'];

      if (project is! String? || scenario is! String?) {
        _writeBadRequest(request, 'project and scenario must be string values');
        return;
      }

      final hasProject = project != null && project.trim().isNotEmpty;
      final hasScenario = scenario != null && scenario.trim().isNotEmpty;

      if (!hasProject && !hasScenario) {
        _writeBadRequest(request, 'Either scenario or project is required');
        return;
      }

      if (branch is! String || branch.trim().isEmpty) {
        _writeBadRequest(request, 'Missing non-empty branch');
        return;
      }

      final result = await onTrigger(
        BuildTriggerRequest(
          project: hasProject ? project.trim() : null,
          scenario: hasScenario ? scenario.trim() : null,
          branch: branch.trim(),
        ),
      );
      _writeJson(request, result.statusCode, result.toJson());
    } on FormatException {
      _writeBadRequest(request, 'Request body must be valid JSON');
    } catch (error) {
      _writeJson(request, HttpStatus.internalServerError, <String, Object?>{
        'accepted': false,
        'message': '$error',
      });
    }
  }

  void _writeBadRequest(HttpRequest request, String message) {
    _writeJson(request, HttpStatus.badRequest, <String, Object?>{
      'accepted': false,
      'message': message,
    });
  }

  void _writeJson(
    HttpRequest request,
    int statusCode,
    Map<String, Object?> body,
  ) {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    unawaited(request.response.close());
  }
}
