import 'package:postgres/postgres.dart';
import 'package:pip_services3_commons/pip_services3_commons.dart';
import 'package:pip_services3_components/pip_services3_components.dart';

import 'PostgresConnectionResolver.dart';

/// PostgreSQL connection using plain driver.
///
/// By defining a connection and sharing it through multiple persistence components
/// you can reduce number of used database connections.
///
/// ### Configuration parameters ###
///
/// - [connection(s)]:
///   - [discovery_key]:             (optional) a key to retrieve the connection from [IDiscovery]
///   - [host]:                      host name or IP address
///   - [port]:                      port number (default: 5432)
///   - [uri]:                       resource URI or connection string with all parameters in it
/// - [credential(s)]:
///   - [store_key]:                 (optional) a key to retrieve the credentials from [ICredentialStore]
///   - [username]:                  user name
///   - [password]:                  user password
/// - [options]:
///   - [connect_timeout]:      (optional) number of milliseconds to wait before timing out when connecting a new client (default: 10000)
///   - [idle_timeout]:         (optional) number of milliseconds a client must sit idle in the pool and not be checked out (default: 10000)
///   - [max_pool_size]:        (optional) maximum number of clients the pool should contain (default: 10)
///
/// ### References ###
///
/// - \*:logger:\*:\*:1.0           (optional) [ILogger] components to pass log messages
/// - \*:discovery:\*:\*:1.0        (optional) [IDiscovery] services
/// - \*:credential-store:\*:\*:1.0 (optional) Credential stores to resolve credentials
///
class PostgresConnection implements IReferenceable, IConfigurable, IOpenable {
  ConfigParams _defaultConfig = ConfigParams.fromTuples([
    "options.connect_timeout",
    10000,
    "options.idle_timeout",
    10000,
    "options.max_pool_size",
    3
  ]);

  // The logger.
  var logger_ = CompositeLogger();
  // The connection resolver.
  var connectionResolver_ = PostgresConnectionResolver();
  // The configuration options.
  var options_ = ConfigParams();
  // The Postgres connection pool object.
  PostgreSQLConnection? connection_;
  // The Postgres database name.
  String? databaseName_;

  /// Configures component by passing configuration parameters.
  ///
  /// - [config]    configuration parameters to be set.
  @override
  void configure(ConfigParams config) {
    config = config.setDefaults(this._defaultConfig);

    connectionResolver_.configure(config);

    options_ = options_.override(config.getSection("options"));
  }

  /// Sets references to dependent components.
  ///
  /// - [references] references to locate the component dependencies.
  @override
  void setReferences(IReferences references) {
    logger_.setReferences(references);
    connectionResolver_.setReferences(references);
  }

  /// Checks if the component is opened.
  ///
  /// Return true if the component has been opened and false otherwise.
  @override
  bool isOpen() {
    return connection_ != null;
  }

  Map<String, dynamic> _composeSettings() {
    var maxPoolSize = options_.getAsNullableInteger("max_pool_size");
    var connectTimeoutMS = options_.getAsNullableInteger("connect_timeout");
    var idleTimeoutMS = options_.getAsNullableInteger("idle_timeout");

    var settings = {
      "max": maxPoolSize,
      "connectionTimeoutMillis": connectTimeoutMS,
      "idleTimeoutMillis": idleTimeoutMS,
    };

    return settings;
  }

  /// Opens the component.
  ///
  /// - [correlationId] 	(optional) transaction id to trace execution through call chain.
  @override
  Future open(String? correlationId) async {
    var options = await connectionResolver_.resolve(correlationId);

    logger_.debug(correlationId, "Connecting to Postgres");

    try {
      var settings = this._composeSettings();
      options.addAll(settings);

      // Try to connect
      var connection = PostgreSQLConnection(
          options['host'], options['port'], options['database'],
          username: options['user'],
          password: options['password'],
          timeoutInSeconds: options['connectionTimeoutMillis']);
      await connection.open();

      // set idleTimeoutMillis
      await connection.query(
          "SET SESSION idle_in_transaction_session_timeout = '" +
              options['idleTimeoutMillis'].toString() +
              "'");

      connection_ = connection;

      databaseName_ = connection_!.databaseName;
    } catch (ex) {
      throw new ConnectionException(
              correlationId, "CONNECT_FAILED", "Connection to Postgres failed")
          .withCause(ex);
    }
  }

  /// Closes component and frees used resources.
  ///
  /// - [correlationId] 	(optional) transaction id to trace execution through call chain.
  @override
  Future close(String? correlationId) async {
    if (connection_ == null) {
      return;
    }

    try {
      await connection_!.close();
      logger_.debug(correlationId, "Disconnected from Postgres database %s",
          [databaseName_]);

      connection_ = null;
      databaseName_ = null;
    } catch (ex) {
      throw new ConnectionException(correlationId, 'DISCONNECT_FAILED',
              'Disconnect from Postgres failed: ')
          .withCause(ex);
    }
  }

  PostgreSQLConnection? getConnection() {
    return connection_;
  }

  String? getDatabaseName() {
    return databaseName_;
  }
}
