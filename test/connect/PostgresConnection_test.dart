import 'dart:io';
import 'package:test/test.dart';
import 'package:pip_services3_postgres/src/connect/connect.dart';
import 'package:pip_services3_commons/pip_services3_commons.dart';

void main() {
  group('PostgresConnection', () {
    late PostgresConnection connection;

    var postgresUri = Platform.environment['POSTGRES_URI'];
    var postgresHost = Platform.environment['POSTGRES_HOST'] ?? 'localhost';
    var postgresPort = Platform.environment['POSTGRES_PORT'] ?? 5432;
    var postgresDatabase = Platform.environment['POSTGRES_DB'] ?? 'test';
    var postgresUser = Platform.environment['POSTGRES_USER'] ?? 'postgres';
    var postgresPassword =
        Platform.environment['POSTGRES_PASSWORD'] ?? 'postgres';

    if (postgresUri == null && postgresHost == null) {
      return;
    }

    setUp(() async {
      var dbConfig = ConfigParams.fromTuples([
        'connection.uri',
        postgresUri,
        'connection.host',
        postgresHost,
        'connection.port',
        postgresPort,
        'connection.database',
        postgresDatabase,
        'credential.username',
        postgresUser,
        'credential.password',
        postgresPassword
      ]);

      connection = PostgresConnection();
      connection.configure(dbConfig);

      await connection.open(null);
    });

    tearDown(() async {
      await connection.close(null);
    });

    test('Open and Close', () {
      expect(connection.getConnection(), isNotNull);
      expect(connection.getDatabaseName(), isNotNull);
    });
  });
}
