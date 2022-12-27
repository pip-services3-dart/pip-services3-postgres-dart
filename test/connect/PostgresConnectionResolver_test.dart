import 'package:pip_services3_postgres/src/connect/PostgresConnectionResolver.dart';
import 'package:test/test.dart';
import 'package:pip_services3_commons/pip_services3_commons.dart';

void main() {
  group('PostgresConnectionResolver', () {
    test('Connection Config', () async {
      var dbConfig = ConfigParams.fromTuples([
        'connection.host',
        'localhost',
        'connection.port',
        5432,
        'connection.database',
        'test',
        'connection.ssl',
        true,
        'credential.username',
        'postgres',
        'credential.password',
        'postgres',
      ]);
      var resolver = new PostgresConnectionResolver();
      resolver.configure(dbConfig);

      var config = await resolver.resolve(null);
      expect('localhost', config['host']);
      expect(5432, config['port']);
      expect('test', config['database']);
      expect('postgres', config['user']);
      expect('postgres', config['password']);
      expect(config['ssl'], isNull);
    });
  });
}
