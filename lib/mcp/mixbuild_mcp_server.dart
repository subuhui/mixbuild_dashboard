import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mixbuild_dashboard/services/mcp_build_service.dart';

const String _modernProtocolVersion = '2026-07-28';
const List<String> _legacyProtocolVersions = <String>[
  '2025-11-25',
  '2025-06-18',
  '2025-03-26',
  '2024-11-05',
];

class McpToolCallResult {
  const McpToolCallResult(this.payload, {this.isError = false});

  final Map<String, dynamic> payload;
  final bool isError;
}

abstract class McpToolHandler {
  List<Map<String, dynamic>> get tools;

  Future<McpToolCallResult> call(String name, Map<String, dynamic> arguments);
}

class MixbuildMcpToolHandler implements McpToolHandler {
  const MixbuildMcpToolHandler(this._service);

  final McpBuildService _service;

  @override
  List<Map<String, dynamic>> get tools => <Map<String, dynamic>>[
    <String, dynamic>{
      'name': 'mixbuild_list_scenarios',
      'title': 'List matching MixBuild scenarios',
      'description':
          'Find build scenarios by project directory and target Git branch.',
      'inputSchema': <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'project_directory': <String, dynamic>{
            'type': 'string',
            'description':
                'Absolute main project directory or a directory inside it.',
          },
          'branch': <String, dynamic>{
            'type': 'string',
            'description': 'Exact target Git branch.',
          },
        },
        'required': <String>['project_directory', 'branch'],
        'additionalProperties': false,
      },
      'annotations': <String, dynamic>{
        'readOnlyHint': true,
        'destructiveHint': false,
        'idempotentHint': true,
        'openWorldHint': false,
      },
    },
    <String, dynamic>{
      'name': 'mixbuild_build_project',
      'title': 'Build and package a MixBuild project',
      'description':
          'Run the configured MixBuild pipeline selected by project '
          'directory, branch, and optional scenario name. The pipeline may '
          'reset and clean configured Git repositories.',
      'inputSchema': <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'project_directory': <String, dynamic>{
            'type': 'string',
            'description':
                'Absolute main project directory or a directory inside it.',
          },
          'branch': <String, dynamic>{
            'type': 'string',
            'description': 'Exact target Git branch.',
          },
          'scenario_name': <String, dynamic>{
            'type': 'string',
            'description':
                'Required only when multiple scenarios match the branch.',
          },
          'clean_before_build': <String, dynamic>{
            'type': 'boolean',
            'default': false,
            'description': 'Append --clean to the configured build command.',
          },
        },
        'required': <String>['project_directory', 'branch'],
        'additionalProperties': false,
      },
      'annotations': <String, dynamic>{
        'readOnlyHint': false,
        'destructiveHint': true,
        'idempotentHint': false,
        'openWorldHint': true,
      },
    },
    <String, dynamic>{
      'name': 'mixbuild_add_scenario',
      'title': 'Add a MixBuild scenario',
      'description':
          'Add a build scenario to the workspace matched by the current '
          'project directory.',
      'inputSchema': <String, dynamic>{
        'type': 'object',
        'properties': <String, dynamic>{
          'project_directory': <String, dynamic>{
            'type': 'string',
            'description':
                'Absolute main project directory or a directory inside it.',
          },
          'branch': <String, dynamic>{
            'type': 'string',
            'description': 'Exact target Git branch for the new scenario.',
          },
          'name': <String, dynamic>{'type': 'string'},
          'command': <String, dynamic>{
            'type': 'string',
            'description': 'Build/package shell command.',
          },
          'output_directory': <String, dynamic>{'type': 'string'},
          'auto_tag': <String, dynamic>{'type': 'boolean', 'default': false},
          'tag_prefix': <String, dynamic>{'type': 'string'},
          'dependency_overrides': <String, dynamic>{
            'type': 'object',
            'additionalProperties': <String, dynamic>{'type': 'string'},
          },
        },
        'required': <String>['project_directory', 'branch', 'name', 'command'],
        'additionalProperties': false,
      },
      'annotations': <String, dynamic>{
        'readOnlyHint': false,
        'destructiveHint': false,
        'idempotentHint': false,
        'openWorldHint': false,
      },
    },
  ];

  @override
  Future<McpToolCallResult> call(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    try {
      switch (name) {
        case 'mixbuild_list_scenarios':
          return McpToolCallResult(
            _service.listScenarios(
              projectDirectory: _stringArgument(arguments, 'project_directory'),
              branch: _stringArgument(arguments, 'branch'),
            ),
          );
        case 'mixbuild_build_project':
          final payload = await _service.buildProject(
            projectDirectory: _stringArgument(arguments, 'project_directory'),
            branch: _stringArgument(arguments, 'branch'),
            scenarioName: _optionalStringArgument(arguments, 'scenario_name'),
            cleanBeforeBuild: _optionalBoolArgument(
              arguments,
              'clean_before_build',
            ),
          );
          return McpToolCallResult(
            payload,
            isError: payload['success'] != true,
          );
        case 'mixbuild_add_scenario':
          return McpToolCallResult(
            _service.addScenario(
              projectDirectory: _stringArgument(arguments, 'project_directory'),
              branch: _stringArgument(arguments, 'branch'),
              name: _stringArgument(arguments, 'name'),
              command: _stringArgument(arguments, 'command'),
              outputDirectory: _optionalStringArgument(
                arguments,
                'output_directory',
              ),
              autoTag: _optionalBoolArgument(arguments, 'auto_tag'),
              tagPrefix: _optionalStringArgument(arguments, 'tag_prefix') ?? '',
              dependencyOverrides: _stringMapArgument(
                arguments,
                'dependency_overrides',
              ),
            ),
          );
        default:
          return McpToolCallResult(<String, dynamic>{
            'error': 'Unknown tool: $name',
          }, isError: true);
      }
    } on McpBuildServiceException catch (error) {
      return McpToolCallResult(<String, dynamic>{
        'error': error.message,
      }, isError: true);
    } on FormatException catch (error) {
      return McpToolCallResult(<String, dynamic>{
        'error': error.message,
      }, isError: true);
    }
  }
}

class MixbuildMcpServer {
  MixbuildMcpServer(this._toolHandler);

  final McpToolHandler _toolHandler;
  bool _initialized = false;

  Future<void> run({Stream<List<int>>? input, IOSink? output}) async {
    final inputStream = input ?? stdin;
    final outputSink = output ?? stdout;
    await for (final line
        in inputStream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.trim().isEmpty) {
        continue;
      }
      Object? response;
      try {
        response = await handlePayload(jsonDecode(line));
      } on FormatException catch (error) {
        response = _errorResponse(
          null,
          code: -32700,
          message: 'Parse error',
          data: error.message,
        );
      }
      if (response != null) {
        outputSink.writeln(jsonEncode(response));
        await outputSink.flush();
      }
    }
  }

  Future<Object?> handlePayload(Object? payload) async {
    if (payload is List) {
      if (payload.isEmpty) {
        return _errorResponse(null, code: -32600, message: 'Invalid Request');
      }
      final responses = <Object>[];
      for (final item in payload) {
        final response = await _handleMessage(item);
        if (response != null) {
          responses.add(response);
        }
      }
      return responses.isEmpty ? null : responses;
    }
    return _handleMessage(payload);
  }

  Future<Map<String, dynamic>?> _handleMessage(Object? message) async {
    if (message is! Map) {
      return _errorResponse(null, code: -32600, message: 'Invalid Request');
    }
    final request = Map<String, dynamic>.from(message);
    final id = request['id'];
    final hasId = request.containsKey('id');
    final method = request['method'];
    if (request['jsonrpc'] != '2.0' || method is! String) {
      return hasId
          ? _errorResponse(id, code: -32600, message: 'Invalid Request')
          : null;
    }

    if (!hasId) {
      if (method == 'notifications/initialized') {
        _initialized = true;
      }
      return null;
    }
    if (id is! String && id is! num) {
      return _errorResponse(
        null,
        code: -32600,
        message: 'Request id must be a string or number.',
      );
    }

    final requestVersion = _requestProtocolVersion(request['params']);
    if (method == 'server/discover') {
      if (requestVersion == null) {
        return _errorResponse(
          id,
          code: -32601,
          message: 'Method not found: $method',
        );
      }
      if (requestVersion != _modernProtocolVersion) {
        return _unsupportedVersionResponse(id, requestVersion);
      }
      return _successResponse(id, <String, dynamic>{
        'resultType': 'complete',
        'supportedVersions': <String>[_modernProtocolVersion],
        'capabilities': <String, dynamic>{
          'tools': <String, dynamic>{'listChanged': false},
        },
        '_meta': _serverInfoMeta,
        'instructions':
            'Match projects with absolute project_directory and exact branch. '
            'List scenarios before building when a branch has multiple options.',
        'ttlMs': 300000,
        'cacheScope': 'public',
      });
    }
    if (requestVersion != null) {
      if (requestVersion != _modernProtocolVersion) {
        return _unsupportedVersionResponse(id, requestVersion);
      }
      return _handleOperationalRequest(
        id,
        method,
        request['params'],
        modern: true,
      );
    }

    if (method == 'initialize') {
      return _initializeResponse(id, request['params']);
    }
    if (method == 'ping') {
      return _successResponse(id, <String, dynamic>{});
    }
    if (!_initialized) {
      return _errorResponse(
        id,
        code: -32002,
        message: 'Server not initialized',
      );
    }

    return _handleOperationalRequest(id, method, request['params']);
  }

  Future<Map<String, dynamic>> _handleOperationalRequest(
    Object id,
    String method,
    Object? params, {
    bool modern = false,
  }) async {
    switch (method) {
      case 'ping':
        return _successResponse(id, <String, dynamic>{
          if (modern) 'resultType': 'complete',
          if (modern) '_meta': _serverInfoMeta,
        });
      case 'tools/list':
        return _successResponse(id, <String, dynamic>{
          if (modern) 'resultType': 'complete',
          'tools': _toolHandler.tools,
          if (modern) ...<String, dynamic>{
            'ttlMs': 300000,
            'cacheScope': 'public',
            '_meta': _serverInfoMeta,
          },
        });
      case 'tools/call':
        return _callTool(id, params, modern: modern);
      default:
        return _errorResponse(
          id,
          code: -32601,
          message: 'Method not found: $method',
        );
    }
  }

  Map<String, dynamic> _initializeResponse(Object id, Object? rawParams) {
    if (rawParams is! Map) {
      return _errorResponse(
        id,
        code: -32602,
        message: 'initialize params must be an object.',
      );
    }
    final params = Map<String, dynamic>.from(rawParams);
    final requestedVersion = params['protocolVersion'];
    final protocolVersion =
        requestedVersion is String &&
            _legacyProtocolVersions.contains(requestedVersion)
        ? requestedVersion
        : _legacyProtocolVersions.first;
    return _successResponse(id, <String, dynamic>{
      'protocolVersion': protocolVersion,
      'capabilities': <String, dynamic>{
        'tools': <String, dynamic>{'listChanged': false},
      },
      'serverInfo': <String, dynamic>{
        'name': 'mixbuild-dashboard',
        'version': '1.0.4',
      },
      'instructions':
          'Match projects with absolute project_directory and exact branch. '
          'List scenarios before building when a branch has multiple options.',
    });
  }

  Future<Map<String, dynamic>> _callTool(
    Object id,
    Object? rawParams, {
    bool modern = false,
  }) async {
    if (rawParams is! Map) {
      return _errorResponse(
        id,
        code: -32602,
        message: 'tools/call params must be an object.',
      );
    }
    final params = Map<String, dynamic>.from(rawParams);
    final name = params['name'];
    final rawArguments = params['arguments'];
    if (name is! String || (rawArguments != null && rawArguments is! Map)) {
      return _errorResponse(
        id,
        code: -32602,
        message: 'tools/call requires a tool name and object arguments.',
      );
    }
    final arguments = rawArguments == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(rawArguments as Map);
    final result = await _toolHandler.call(name, arguments);
    final text = const JsonEncoder.withIndent('  ').convert(result.payload);
    return _successResponse(id, <String, dynamic>{
      if (modern) 'resultType': 'complete',
      'content': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'text', 'text': text},
      ],
      'structuredContent': result.payload,
      'isError': result.isError,
      if (modern) '_meta': _serverInfoMeta,
    });
  }
}

const Map<String, dynamic> _serverInfoMeta = <String, dynamic>{
  'io.modelcontextprotocol/serverInfo': <String, dynamic>{
    'name': 'mixbuild-dashboard',
    'version': '1.0.4',
  },
};

String? _requestProtocolVersion(Object? rawParams) {
  if (rawParams is! Map) {
    return null;
  }
  final meta = rawParams['_meta'];
  if (meta is! Map) {
    return null;
  }
  final version = meta['io.modelcontextprotocol/protocolVersion'];
  return version is String ? version : null;
}

Map<String, dynamic> _unsupportedVersionResponse(
  Object id,
  String requestedVersion,
) {
  return _errorResponse(
    id,
    code: -32022,
    message: 'Unsupported protocol version',
    data: <String, dynamic>{
      'supported': <String>[_modernProtocolVersion, ..._legacyProtocolVersions],
      'requested': requestedVersion,
    },
  );
}

Map<String, dynamic> _successResponse(Object id, Map<String, dynamic> result) {
  return <String, dynamic>{'jsonrpc': '2.0', 'id': id, 'result': result};
}

Map<String, dynamic> _errorResponse(
  Object? id, {
  required int code,
  required String message,
  Object? data,
}) {
  return <String, dynamic>{
    'jsonrpc': '2.0',
    'id': id,
    'error': <String, dynamic>{
      'code': code,
      'message': message,
      ...data == null
          ? const <String, dynamic>{}
          : <String, dynamic>{'data': data},
    },
  };
}

String _stringArgument(Map<String, dynamic> arguments, String name) {
  final value = arguments[name];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$name must be a non-empty string.');
  }
  return value.trim();
}

String? _optionalStringArgument(Map<String, dynamic> arguments, String name) {
  final value = arguments[name];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$name must be a string.');
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _optionalBoolArgument(Map<String, dynamic> arguments, String name) {
  final value = arguments[name];
  if (value == null) {
    return false;
  }
  if (value is! bool) {
    throw FormatException('$name must be a boolean.');
  }
  return value;
}

Map<String, String> _stringMapArgument(
  Map<String, dynamic> arguments,
  String name,
) {
  final value = arguments[name];
  if (value == null) {
    return const <String, String>{};
  }
  if (value is! Map) {
    throw FormatException('$name must be an object.');
  }
  final result = <String, String>{};
  for (final entry in value.entries) {
    if (entry.key is! String ||
        entry.value is! String ||
        (entry.value as String).trim().isEmpty) {
      throw FormatException('$name values must be non-empty strings.');
    }
    result[(entry.key as String).trim()] = (entry.value as String).trim();
  }
  return result;
}
