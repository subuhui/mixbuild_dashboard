import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/mcp/mixbuild_mcp_server.dart';

void main() {
  late _FakeToolHandler toolHandler;
  late MixbuildMcpServer server;

  setUp(() {
    toolHandler = _FakeToolHandler();
    server = MixbuildMcpServer(toolHandler);
  });

  test('negotiates protocol and exposes tools after initialization', () async {
    final initialize =
        await server.handlePayload(<String, dynamic>{
              'jsonrpc': '2.0',
              'id': 1,
              'method': 'initialize',
              'params': <String, dynamic>{
                'protocolVersion': '2025-06-18',
                'capabilities': <String, dynamic>{},
                'clientInfo': <String, dynamic>{
                  'name': 'test-client',
                  'version': '1.0.0',
                },
              },
            })
            as Map<String, dynamic>;

    final initializeResult = initialize['result'] as Map<String, dynamic>;
    expect(initializeResult['protocolVersion'], '2025-06-18');

    await server.handlePayload(<String, dynamic>{
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    });
    final response =
        await server.handlePayload(<String, dynamic>{
              'jsonrpc': '2.0',
              'id': 2,
              'method': 'tools/list',
              'params': <String, dynamic>{},
            })
            as Map<String, dynamic>;

    final result = response['result'] as Map<String, dynamic>;
    expect(result['tools'], toolHandler.tools);
  });

  test('returns structured and text content for tool calls', () async {
    await _initialize(server);

    final response =
        await server.handlePayload(<String, dynamic>{
              'jsonrpc': '2.0',
              'id': 'call-1',
              'method': 'tools/call',
              'params': <String, dynamic>{
                'name': 'test_tool',
                'arguments': <String, dynamic>{'value': 'hello'},
              },
            })
            as Map<String, dynamic>;

    final result = response['result'] as Map<String, dynamic>;
    expect(result['structuredContent'], <String, dynamic>{'echo': 'hello'});
    expect(result['isError'], isFalse);
    expect(
      ((result['content'] as List<dynamic>).single
          as Map<String, dynamic>)['text'],
      contains('"echo": "hello"'),
    );
  });

  test('supports JSON-RPC batches and omits notification responses', () async {
    await _initialize(server);

    final response =
        await server.handlePayload(<Object>[
              <String, dynamic>{'jsonrpc': '2.0', 'id': 3, 'method': 'ping'},
              <String, dynamic>{
                'jsonrpc': '2.0',
                'method': 'notifications/cancelled',
              },
            ])
            as List<dynamic>;

    expect(response, hasLength(1));
    expect((response.single as Map<String, dynamic>)['id'], 3);
  });

  test('rejects tool requests before initialization', () async {
    final response =
        await server.handlePayload(<String, dynamic>{
              'jsonrpc': '2.0',
              'id': 1,
              'method': 'tools/list',
            })
            as Map<String, dynamic>;

    final error = response['error'] as Map<String, dynamic>;
    expect(error['code'], -32002);
  });

  test('supports modern discovery and stateless tool requests', () async {
    final discover =
        await server.handlePayload(<String, dynamic>{
              'jsonrpc': '2.0',
              'id': 'discover',
              'method': 'server/discover',
              'params': _modernParams(),
            })
            as Map<String, dynamic>;

    final discoverResult = discover['result'] as Map<String, dynamic>;
    expect(discoverResult['supportedVersions'], <String>['2026-07-28']);
    expect(discoverResult['resultType'], 'complete');

    final list =
        await server.handlePayload(<String, dynamic>{
              'jsonrpc': '2.0',
              'id': 'list',
              'method': 'tools/list',
              'params': _modernParams(),
            })
            as Map<String, dynamic>;
    final listResult = list['result'] as Map<String, dynamic>;
    expect(listResult['tools'], toolHandler.tools);
    expect(listResult['ttlMs'], 300000);
  });

  test('returns supported versions for an unknown modern version', () async {
    final response =
        await server.handlePayload(<String, dynamic>{
              'jsonrpc': '2.0',
              'id': 'discover',
              'method': 'server/discover',
              'params': _modernParams(version: '2099-01-01'),
            })
            as Map<String, dynamic>;

    final error = response['error'] as Map<String, dynamic>;
    expect(error['code'], -32022);
    expect(
      (error['data'] as Map<String, dynamic>)['supported'],
      contains('2026-07-28'),
    );
  });
}

Future<void> _initialize(MixbuildMcpServer server) async {
  await server.handlePayload(<String, dynamic>{
    'jsonrpc': '2.0',
    'id': 1,
    'method': 'initialize',
    'params': <String, dynamic>{
      'protocolVersion': '2025-06-18',
      'capabilities': <String, dynamic>{},
      'clientInfo': <String, dynamic>{
        'name': 'test-client',
        'version': '1.0.0',
      },
    },
  });
  await server.handlePayload(<String, dynamic>{
    'jsonrpc': '2.0',
    'method': 'notifications/initialized',
  });
}

Map<String, dynamic> _modernParams({String version = '2026-07-28'}) {
  return <String, dynamic>{
    '_meta': <String, dynamic>{
      'io.modelcontextprotocol/protocolVersion': version,
      'io.modelcontextprotocol/clientInfo': <String, dynamic>{
        'name': 'test-client',
        'version': '1.0.0',
      },
      'io.modelcontextprotocol/clientCapabilities': <String, dynamic>{},
    },
  };
}

class _FakeToolHandler implements McpToolHandler {
  @override
  List<Map<String, dynamic>> get tools => <Map<String, dynamic>>[
    <String, dynamic>{
      'name': 'test_tool',
      'description': 'Test tool',
      'inputSchema': <String, dynamic>{'type': 'object'},
    },
  ];

  @override
  Future<McpToolCallResult> call(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    if (name != 'test_tool') {
      return const McpToolCallResult(<String, dynamic>{
        'error': 'unknown',
      }, isError: true);
    }
    return McpToolCallResult(<String, dynamic>{'echo': arguments['value']});
  }
}
