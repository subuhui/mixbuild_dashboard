import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/mcp/mixbuild_mcp_server.dart';
import 'package:mixbuild_dashboard/services/build_trigger_server.dart';

void main() {
  test(
    'POST /build forwards scenario and branch to the trigger handler',
    () async {
      BuildTriggerRequest? capturedRequest;
      final server = BuildTriggerServer(
        port: 0,
        onTrigger: (request) async {
          capturedRequest = request;
          return const RemoteBuildTriggerResult.accepted(
            projectName: 'workspace-demo',
            scenarioName: 'Release Build',
            branch: 'release/v1.2',
            score: 1,
          );
        },
      );
      await server.start();
      addTearDown(server.stop);

      final client = HttpClient();
      addTearDown(client.close);
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.port}/build'),
      );
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, String>{
          'scenario': 'Release Build',
          'branch': 'release/v1.2',
        }),
      );

      final response = await request.close();
      final body =
          jsonDecode(await utf8.decodeStream(response)) as Map<String, dynamic>;

      expect(response.statusCode, HttpStatus.accepted);
      expect(capturedRequest?.scenario, 'Release Build');
      expect(capturedRequest?.branch, 'release/v1.2');
      expect(body['accepted'], isTrue);
      expect(body['scenario'], 'Release Build');
    },
  );

  test('POST /build forwards dotted project name and branch', () async {
    BuildTriggerRequest? capturedRequest;
    final server = BuildTriggerServer(
      port: 0,
      onTrigger: (request) async {
        capturedRequest = request;
        return const RemoteBuildTriggerResult.accepted(
          projectName: 'flutter.module.ui',
          scenarioName: 'Release Build',
          branch: 'release/v1.2',
          score: 1,
        );
      },
    );
    await server.start();
    addTearDown(server.stop);

    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:${server.port}/build'),
    );
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode(<String, String>{
        'project': 'flutter.module.ui',
        'branch': 'release/v1.2',
      }),
    );

    final response = await request.close();
    await response.drain<void>();

    expect(response.statusCode, HttpStatus.accepted);
    expect(capturedRequest?.project, 'flutter.module.ui');
    expect(capturedRequest?.branch, 'release/v1.2');
  });

  test('POST /mcp forwards JSON-RPC requests to the MCP server', () async {
    final server = BuildTriggerServer(
      port: 0,
      mcpServer: MixbuildMcpServer(_FakeMcpToolHandler()),
      onTrigger: (_) async => const RemoteBuildTriggerResult.rejected(
        statusCode: HttpStatus.badRequest,
        message: 'unused',
      ),
    );
    await server.start();
    addTearDown(server.stop);

    final response = await _postJson(server.port, '/mcp', <String, Object?>{
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'server/discover',
      'params': <String, Object?>{
        '_meta': <String, Object?>{
          'io.modelcontextprotocol/protocolVersion': '2026-07-28',
        },
      },
    });

    expect(response.statusCode, HttpStatus.ok);
    expect(response.body['jsonrpc'], '2.0');
    expect(response.body['id'], 1);
    final result = response.body['result'] as Map<String, dynamic>;
    expect(result['supportedVersions'], <String>['2026-07-28']);
  });

  test('POST /mcp accepts JSON-RPC notifications without a body', () async {
    final server = BuildTriggerServer(
      port: 0,
      mcpServer: MixbuildMcpServer(_FakeMcpToolHandler()),
      onTrigger: (_) async => const RemoteBuildTriggerResult.rejected(
        statusCode: HttpStatus.badRequest,
        message: 'unused',
      ),
    );
    await server.start();
    addTearDown(server.stop);

    final response = await _postJson(server.port, '/mcp', <String, Object?>{
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    });

    expect(response.statusCode, HttpStatus.accepted);
    expect(response.rawBody, isEmpty);
  });

  test('GET /mcp reports no SSE stream', () async {
    final server = BuildTriggerServer(
      port: 0,
      mcpServer: MixbuildMcpServer(_FakeMcpToolHandler()),
      onTrigger: (_) async => const RemoteBuildTriggerResult.rejected(
        statusCode: HttpStatus.badRequest,
        message: 'unused',
      ),
    );
    await server.start();
    addTearDown(server.stop);

    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/mcp'),
    );
    final response = await request.close();
    await response.drain<void>();

    expect(response.statusCode, HttpStatus.methodNotAllowed);
    expect(response.headers.value(HttpHeaders.allowHeader), 'POST, GET');
  });

  test('POST /mcp rejects non-local Origin headers', () async {
    final server = BuildTriggerServer(
      port: 0,
      mcpServer: MixbuildMcpServer(_FakeMcpToolHandler()),
      onTrigger: (_) async => const RemoteBuildTriggerResult.rejected(
        statusCode: HttpStatus.badRequest,
        message: 'unused',
      ),
    );
    await server.start();
    addTearDown(server.stop);

    final response = await _postJson(server.port, '/mcp', <String, Object?>{
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'ping',
    }, origin: 'https://example.com');

    expect(response.statusCode, HttpStatus.forbidden);
    final error = response.body['error'] as Map<String, dynamic>;
    expect(error['message'], 'Forbidden origin');
  });
}

Future<_JsonHttpResponse> _postJson(
  int port,
  String path,
  Object body, {
  String? origin,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port$path'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (origin != null) {
      request.headers.set('origin', origin);
    }
    request.write(jsonEncode(body));

    final response = await request.close();
    final rawBody = await utf8.decodeStream(response);
    return _JsonHttpResponse(
      statusCode: response.statusCode,
      rawBody: rawBody,
      body: rawBody.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(rawBody) as Map<String, dynamic>,
    );
  } finally {
    client.close();
  }
}

class _JsonHttpResponse {
  const _JsonHttpResponse({
    required this.statusCode,
    required this.rawBody,
    required this.body,
  });

  final int statusCode;
  final String rawBody;
  final Map<String, dynamic> body;
}

class _FakeMcpToolHandler implements McpToolHandler {
  @override
  List<Map<String, dynamic>> get tools => <Map<String, dynamic>>[
    <String, dynamic>{
      'name': 'test_tool',
      'description': 'Test tool',
      'inputSchema': <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{},
      },
    },
  ];

  @override
  Future<McpToolCallResult> call(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    return const McpToolCallResult(<String, dynamic>{'ok': true});
  }
}
