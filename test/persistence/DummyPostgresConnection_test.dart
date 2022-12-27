import 'dart:io';
import 'package:pip_services3_postgres/src/connect/PostgresConnection.dart';
import 'package:test/test.dart';
import 'package:pip_services3_commons/pip_services3_commons.dart';
import '../fixtures/DummyPersistenceFixture.dart';
import './DummyPostgresPersistence.dart';

void main() {
  group('DummyPostgresConnection', () {
    late PostgresConnection connection;
    late DummyPostgresPersistence persistence;
    late DummyPersistenceFixture fixture;

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

      connection = new PostgresConnection();
      connection.configure(dbConfig);

      persistence = new DummyPostgresPersistence();
      persistence.setReferences(References.fromTuples([
        new Descriptor(
            "pip-services", "connection", "postgres", "default", "1.0"),
        connection
      ]));

      fixture = new DummyPersistenceFixture(persistence);

      await connection.open(null);
      await persistence.open(null);
      await persistence.clear(null);
    });

    tearDown(() async {
      await persistence.close(null);
    });

    test('Connection', () async {
      expect(connection.getConnection(), isNotNull);
      expect(connection.getDatabaseName() is String, isTrue);
    });

    test('Crud Operations', () async {
      await fixture.testCrudOperations();
    });

    test('Batch Operations', () async {
      await fixture.testBatchOperations();
    });
  });
}
