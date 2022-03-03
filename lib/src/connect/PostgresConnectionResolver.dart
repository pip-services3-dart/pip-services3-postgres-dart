import 'package:pip_services3_commons/pip_services3_commons.dart';
import 'package:pip_services3_components/pip_services3_components.dart';

/// Helper class that resolves PostgreSQL connection and credential parameters,
/// validates them and generates a connection URI.
///
/// It is able to process multiple connections to PostgreSQL cluster nodes.
///
/// ### Configuration parameters ###
///
/// - [connection(s)]:
///   - [discovery_key]:               (optional) a key to retrieve the connection from [IDiscovery]
///   - [host]:                        host name or IP address
///   - [port]:                        port number (default: 5432)
///   - [database]:                    database name
///   - [uri]:                         resource URI or connection string with all parameters in it
/// - [credential(s)]:
///   - [store_key]:                   (optional) a key to retrieve the credentials from [ICredentialStore]
///   - [username]:                    user name
///   - [password]:                    user password
///
/// ### References ###
///
/// - \*:discovery:\*:\*:1.0            (optional) [IDiscovery] services
/// - \*:credential-store:\*:\*:1.0     (optional) Credential stores to resolve credentials
///
class PostgresConnectionResolver implements IReferenceable, IConfigurable {
  // The connections resolver.
  ConnectionResolver connectionResolver_ = ConnectionResolver();
  // The credentials resolver.
  CredentialResolver credentialResolver_ = CredentialResolver();

  /// Configures component by passing configuration parameters.
  ///
  /// - [config]    configuration parameters to be set.
  @override
  void configure(ConfigParams config) {
    connectionResolver_.configure(config);
    credentialResolver_.configure(config);
  }

  /// Sets references to dependent components.
  ///
  /// - [references] 	references to locate the component dependencies.
  @override
  void setReferences(IReferences references) {
    connectionResolver_.setReferences(references);
    credentialResolver_.setReferences(references);
  }

  void _validateConnection(String? correlationId, ConnectionParams connection) {
    var uri = connection.getUri();
    if (uri != null) return;

    var host = connection.getHost();
    if (host == null) {
      throw new ConfigException(
          correlationId, "NO_HOST", "Connection host is not set");
    }

    var port = connection.getPort();
    if (port == 0) {
      throw new ConfigException(
          correlationId, "NO_PORT", "Connection port is not set");
    }

    var database = connection.getAsNullableString("database");
    if (database == null) {
      throw new ConfigException(
          correlationId, "NO_DATABASE", "Connection database is not set");
    }
  }

  void _validateConnections(
      String? correlationId, List<ConnectionParams>? connections) {
    if (connections == null || connections.length == 0) {
      throw new ConfigException(
          correlationId, "NO_CONNECTION", "Database connection is not set");
    }

    for (var connection in connections) {
      _validateConnection(correlationId, connection);
    }
  }

  Map<String, dynamic> _composeConfig(
      List<ConnectionParams> connections, CredentialParams? credential) {
    Map<String, dynamic> config = {};

    // Define connection part
    for (var connection in connections) {
      var uri = connection.getUri();
      if (uri != null) config['connectionString'] = uri;

      var host = connection.getHost();
      if (host != null) config['host'] = host;

      var port = connection.getPort();
      if (port != null) config['port'] = port;

      var database = connection.getAsNullableString("database");
      if (database != null) config['database'] = database;
    }

    // Define authentication part
    if (credential != null) {
      var username = credential.getUsername();
      if (username != null) config['user'] = username;

      var password = credential.getPassword();
      if (password != null) config['password'] = password;
    }

    return config;
  }

  /// Resolves PostgreSQL config from connection and credential parameters.
  ///
  /// - [correlationId]     (optional) transaction id to trace execution through call chain.
  /// Return resolved connection config.
  Future<Map<String, dynamic>> resolve(String? correlationId) async {
    var connections = await connectionResolver_.resolveAll(correlationId);
    // Validate connections
    _validateConnections(correlationId, connections);

    var credential = await credentialResolver_.lookup(correlationId);
    // Credentials are not validated right now

    var config = _composeConfig(connections, credential);
    return config;
  }
}
