import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mixbuild_dashboard/mcp/mixbuild_mcp_server.dart';

typedef BuildTriggerHandler =
    Future<RemoteBuildTriggerResult> Function(BuildTriggerRequest request);

class BuildTriggerRequest {
  const BuildTriggerRequest({
    this.project,
    this.scenario,
    required this.branch,
    this.updateDescription,
  });

  final String? project;
  final String? scenario;
  final String branch;
  final String? updateDescription;
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
    this.mcpServer,
    this.host = '127.0.0.1',
    this.port = 8765,
  });

  final String host;
  int port;
  final BuildTriggerHandler onTrigger;
  final MixbuildMcpServer? mcpServer;
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
    if (request.uri.path == '/mcp') {
      await _handleMcpRequest(request);
      return;
    }

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
      final updateDescription = decoded['update_description'];

      if (project is! String? ||
          scenario is! String? ||
          updateDescription is! String?) {
        _writeBadRequest(
          request,
          'project, scenario and update_description must be string values',
        );
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
          updateDescription: updateDescription?.trim(),
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

  Future<void> _handleMcpRequest(HttpRequest request) async {
    if (!_isAllowedLocalOrigin(request)) {
      _writeJsonPayload(request, HttpStatus.forbidden, <String, Object?>{
        'jsonrpc': '2.0',
        'id': null,
        'error': <String, Object?>{
          'code': -32000,
          'message': 'Forbidden origin',
        },
      });
      return;
    }

    if (request.method == 'GET') {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..headers.set(HttpHeaders.allowHeader, 'POST, GET');
      unawaited(request.response.close());
      return;
    }

    if (request.method != 'POST') {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..headers.set(HttpHeaders.allowHeader, 'POST, GET');
      unawaited(request.response.close());
      return;
    }

    final server = mcpServer;
    if (server == null) {
      _writeJson(request, HttpStatus.notFound, <String, Object?>{
        'error': 'MCP endpoint is not configured',
      });
      return;
    }

    try {
      final payload = await utf8.decodeStream(request);
      final decoded = jsonDecode(payload);
      final response = await server.handlePayload(decoded);
      if (response == null) {
        request.response.statusCode = HttpStatus.accepted;
        unawaited(request.response.close());
        return;
      }
      _writeJsonPayload(request, HttpStatus.ok, response);
    } on FormatException catch (error) {
      _writeJsonPayload(request, HttpStatus.badRequest, <String, Object?>{
        'jsonrpc': '2.0',
        'id': null,
        'error': <String, Object?>{
          'code': -32700,
          'message': 'Parse error',
          'data': error.message,
        },
      });
    } catch (error) {
      _writeJsonPayload(
        request,
        HttpStatus.internalServerError,
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': null,
          'error': <String, Object?>{
            'code': -32603,
            'message': 'Internal error',
            'data': '$error',
          },
        },
      );
    }
  }

  bool _isAllowedLocalOrigin(HttpRequest request) {
    final origin = request.headers.value('origin');
    if (origin == null || origin.trim().isEmpty) {
      return true;
    }
    final uri = Uri.tryParse(origin);
    if (uri == null) {
      return false;
    }
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        (uri.host == '127.0.0.1' || uri.host == 'localhost');
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
    _writeJsonPayload(request, statusCode, body);
  }

  void _writeJsonPayload(HttpRequest request, int statusCode, Object? body) {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    unawaited(request.response.close());
  }
}
