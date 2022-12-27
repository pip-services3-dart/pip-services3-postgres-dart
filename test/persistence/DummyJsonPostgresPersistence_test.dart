import 'dart:io';
import 'package:test/test.dart';
import 'package:pip_services3_commons/pip_services3_commons.dart';
import '../fixtures/DummyPersistenceFixture.dart';
import './DummyJsonPostgresPersistence.dart';

void main() {
  group('DummyJsonPostgresPersistence', () {
    late DummyJsonPostgresPersistence persistence;
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

      persistence = new DummyJsonPostgresPersistence();
      persistence.configure(dbConfig);

      fixture = new DummyPersistenceFixture(persistence);

      await persistence.open(null);
      await persistence.clear(null);
    });

    tearDown(() async {
      await persistence.close(null);
    });

    test('Crud Operations', () async {
      await fixture.testCrudOperations();
    });

    test('Batch Operations', () async {
      await fixture.testBatchOperations();
    });
  });
}
