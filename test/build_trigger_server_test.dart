import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixbuild_dashboard/services/build_trigger_server.dart';

void main() {
  test('POST /build forwards project and branch JSON to trigger handler',
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
          score: 0.75,
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
    request.write(jsonEncode(<String, String>{
      'scenario': 'Release Build',
      'branch': 'release/v1.2',
    }));

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body) as Map<String, dynamic>;

    expect(response.statusCode, HttpStatus.accepted);
    expect(capturedRequest?.scenario, 'Release Build');
    expect(capturedRequest?.branch, 'release/v1.2');
    expect(json['scenario'], 'Release Build');
    expect(json['branch'], 'release/v1.2');
  });

  test('POST /build forwards project name and branch JSON to trigger handler',
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
          score: 1.0,
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
    request.write(jsonEncode(<String, String>{
      'project': 'workspace-demo',
      'branch': 'release/v1.2',
    }));

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    final json = jsonDecode(body) as Map<String, dynamic>;

    expect(response.statusCode, HttpStatus.accepted);
    expect(capturedRequest?.project, 'workspace-demo');
    expect(capturedRequest?.branch, 'release/v1.2');
    expect(json['scenario'], 'Release Build');
    expect(json['branch'], 'release/v1.2');
  });
}
