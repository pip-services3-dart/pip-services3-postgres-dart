import 'package:pip_services3_commons/pip_services3_commons.dart';
import 'package:pip_services3_components/pip_services3_components.dart';
import 'package:pip_services3_postgres/src/connect/PostgresConnection.dart';

/// Creates Postgres components by their descriptors.
///
/// See [Factory]
/// See [PostgresConnection]
class DefaultPostgresFactory extends Factory {
  static final PostgresConnectionDescriptor =
      Descriptor("pip-services", "connection", "postgres", "*", "1.0");

  ///  Create a new instance of the factory.
  DefaultPostgresFactory() : super() {
    this.registerAsType(DefaultPostgresFactory.PostgresConnectionDescriptor,
        PostgresConnection);
  }
}
