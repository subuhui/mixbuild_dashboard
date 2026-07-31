import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
