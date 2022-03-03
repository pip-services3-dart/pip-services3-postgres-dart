import 'package:pip_services3_commons/pip_services3_commons.dart';
import 'package:pip_services3_data/pip_services3_data.dart';

import 'package:pip_services3_postgres/src/persistence/PostgresPersistence.dart';

/// Abstract persistence component that stores data in Postgres
/// and implements a number of CRUD operations over data items with unique ids.
/// The data items must implement [IIdentifiable] interface.
///
/// In basic scenarios child classes shall only override [getPageByFilter_],
/// [getListByFilter_] or [deleteByFilter_] operations with specific filter function.
/// All other operations can be used out of the box.
///
/// In complex scenarios child classes can implement additional operations by
/// accessing this.connection_ and this.client_ properties.
///
/// ### Configuration parameters ###
///
/// - [table]:                  (optional) Postgres table name
/// - [schema]:                 (optional) Postgres schema name
/// - [connection(s)]:
///   - [discovery_key]:             (optional) a key to retrieve the connection from [IDiscovery]
///   - [host]:                      host name or IP address
///   - [port]:                      port number (default: 5432)
///   - [uri]:                       resource URI or connection string with all parameters in it
/// - [credential(s)]:
///   - [store_key]:                 (optional) a key to retrieve the credentials from [ICredentialStore]
///   - [username]:                  (optional) user name
///   - [password]:                  (optional) user password
/// - [options]:
///   - [connect_timeout]:      (optional) number of milliseconds to wait before timing out when connecting a new client (default: 10000)
///   - [idle_timeout]:         (optional) number of milliseconds a client must sit idle in the pool and not be checked out (default: 10000)
///   - [max_pool_size]:        (optional) maximum number of clients the pool should contain (default: 10)
///
/// ### References ###
///
/// - \*:logger:\*:\*:1.0           (optional) [ILogger] components to pass log messages
/// - \*:discovery:*:*:1.0        (optional) [IDiscovery] services
/// - \*:credential-store:\*:\*:1.0 (optional) Credential stores to resolve credentials
///
/// ### Example ###
///
///     class MyPostgresPersistence extends IdentifiablePostgresPersistence<MyData, String> {
///       MyPostgresPersistence() : super('mydata', null);
///
///       @override
///       void defineSchema_() {
///         this.clearSchema();
///         this.ensureSchema_('CREATE TABLE ' +
///             this.tableName_! +
///             ' (id TEXT PRIMARY KEY, key TEXT, content TEXT)');
///         this.ensureIndex_(this.tableName_! + '_key', {'key': 1}, {'unique': true});
///       }
///
///       Future<DataPage<Dummy>> getPageByFilter(
///           String? correlationId, FilterParams? filter, PagingParams? paging) {
///         filter = filter ?? FilterParams();
///         var key = filter.getAsNullableString('key');
///         var filterCondition = "";
///         if (key != null) filterCondition += "key='" + key + "'";
///         return super
///             .getPageByFilter_(correlationId, filterCondition, paging, null, null);
///       }
///     }
///     var persistence = MyPostgresPersistence();
///     persistence
///         .configure(ConfigParams.fromTuples(["host", "localhost", "port", 5432]));
///     await persistence.open(null);
///     var item = await persistence.create(null, MyData());
///     var page = await persistence.getPageByFilter(
///         null, FilterParams.fromTuples(["key", "ABC"]), null);
///     print(page.data);
///     var deleted = await persistence.deleteById(null, '1');
///
///
class IdentifiablePostgresPersistence<T extends IIdentifiable<K>, K>
    extends PostgresPersistence<T>
    implements IWriter<T, K>, IGetter<T, K>, ISetter<T> {
  // Flag to turn on auto generation of object ids.
  bool autoGenerateId_ = true;

  /// Creates a new instance of the persistence component.
  ///
  /// - [tableName]    (optional) a table name.
  /// - [schemaName]   (optional) a schema name
  IdentifiablePostgresPersistence(String? tableName, String? schemaName)
      : super(tableName, schemaName);

  /// Converts the given object from the public partial format.
  ///
  /// - [value]     the object to convert from the public partial format.
  /// Return the initial object.
  dynamic convertFromPublicPartial_(value) {
    return this.convertFromPublic_(value);
  }

  /// Gets a list of data items retrieved by given unique ids.
  ///
  /// - [correlationId]     (optional) transaction id to trace execution through call chain.
  /// - [ids]               ids of data items to be retrieved
  /// Return a list with requested data items.
  Future<List<T>> getListByIds(String? correlationId, List<K> ids) async {
    var params = this.generateParameters_(ids);
    var query = "SELECT * FROM " +
        this.quotedTableName_() +
        " WHERE \"id\" IN(" +
        params +
        ")";

    var values = generateValues_(ids);

    var res = await client_!.query(query, substitutionValues: values);

    if (res.isNotEmpty) {
      this.logger_.trace(
          correlationId, "Retrieved %d from %s", [res.length, this.tableName_]);
    } else {
      return [];
    }

    var items = res
        .map((e) => convertToPublic_(Map<String, dynamic>.fromIterables(
            res.columnDescriptions.map((e) => e.columnName), e.toList())) as T)
        .toList();
    return items;
  }

  /// Gets a data item by its unique id.
  ///
  /// - [correlationId]     (optional) transaction id to trace execution through call chain.
  /// - [id]                an id of data item to be retrieved.
  /// Return a requested data item or `null if nothing was found.
  @override
  Future<T?> getOneById(String? correlationId, K id) async {
    var query = "SELECT * FROM " + this.quotedTableName_() + " WHERE \"id\"=@1";
    var params = {'1': id};

    var res = await client_!.query(query, substitutionValues: params);

    if (res.toList().isEmpty)
      this.logger_.trace(correlationId, "Nothing found from %s with id = %s",
          [this.tableName_, id]);
    else
      this.logger_.trace(correlationId, "Retrieved from %s with id = %s",
          [this.tableName_, id]);

    var resValues = res.isNotEmpty
        ? Map<String, dynamic>.fromIterables(
            res.columnDescriptions.map((e) => e.columnName), res.first.toList())
        : null;

    var item = this.convertToPublic_(resValues);

    return item as T?;
  }

  /// Creates a data item.
  ///
  /// - [correlation_id]    (optional) transaction id to trace execution through call chain.
  /// - [item]              an item to be created.
  /// Return  a created item.
  @override
  Future<T?> create(String? correlationId, T? item) async {
    if (item == null) {
      return null;
    }

    // Assign unique id
    dynamic newItem = item;
    if (newItem.id == null && this.autoGenerateId_) {
      newItem = (newItem as ICloneable).clone();
      newItem.id = item.id ?? IdGenerator.nextLong();
    }

    return super.create(correlationId, newItem);
  }

  /// Sets a data item. If the data item exists it updates it,
  /// otherwise it create a new data item.
  ///
  /// - [correlation_id]    (optional) transaction id to trace execution through call chain.
  /// - [item]              a item to be set.
  /// Return the updated item.
  @override
  Future<T?> set(String? correlationId, T? item) async {
    if (item == null) {
      return null;
    }

    // Assign unique id
    dynamic newItem = item;
    if (newItem.id == null && this.autoGenerateId_) {
      newItem = (newItem as ICloneable).clone();
      newItem.id = IdGenerator.nextLong();
    }

    var row = this.convertFromPublic_(item);
    var columns = this.generateColumns_(row);
    var params = this.generateParameters_(row);
    var setParams = this.generateSetParameters_(row);
    var values = this.generateValues_(row);

    var query = "INSERT INTO " +
        this.quotedTableName_() +
        " (" +
        columns +
        ")" +
        " VALUES (" +
        params +
        ")" +
        " ON CONFLICT (\"id\") DO UPDATE SET " +
        setParams +
        " RETURNING *";

    var res = await client_!.query(query, substitutionValues: values);

    var resValues = res.isNotEmpty
        ? Map<String, dynamic>.fromIterables(
            res.columnDescriptions.map((e) => e.columnName), res.first.toList())
        : null;
    newItem = this.convertToPublic_(resValues);

    if (newItem != null) {
      logger_.trace(correlationId, "Set in %s with id = %s",
          [this.quotedTableName_(), newItem.id]);
    }

    return newItem;
  }

  /// Updates a data item.
  ///
  /// - [correlation_id]    (optional) transaction id to trace execution through call chain.
  /// - [item]              an item to be updated.
  /// Return the updated item.
  @override
  Future<T?> update(String? correlationId, T? item) async {
    if (item == null || item.id == null) {
      return null;
    }

    var row = this.convertFromPublic_(item);
    var params = this.generateSetParameters_(row);
    var values = this.generateValues_(row);
    values[(values.length + 1).toString()] = item.id;

    var query = "UPDATE " +
        this.quotedTableName_() +
        " SET " +
        params +
        " WHERE \"id\"=@" +
        values.length.toString() +
        " RETURNING *";

    var res = await client_!.query(query, substitutionValues: values);

    var resValues = res.isNotEmpty
        ? Map<String, dynamic>.fromIterables(
            res.columnDescriptions.map((e) => e.columnName), res.first.toList())
        : null;

    var newItem = this.convertToPublic_(resValues);

    if (newItem != null) {
      logger_.trace(correlationId, "Updated in %s with id = %s",
          [this.tableName_, item.id]);
    }

    return newItem as T?;
  }

  /// Updates only few selected fields in a data item.
  ///
  /// - [correlation_id]    (optional) transaction id to trace execution through call chain.
  /// - [id]                an id of data item to be updated.
  /// - [data]              a map with fields to be updated.
  /// Return the updated item.
  Future<T?> updatePartially(
      String? correlationId, K? id, AnyValueMap? data) async {
    if (data == null || id == null) {
      return null;
    }

    var row = this.convertFromPublic_(data.getAsObject());
    var params = this.generateSetParameters_(row);
    var values = this.generateValues_(row);
    values[(values.length + 1).toString()] = id;

    var query = "UPDATE " +
        this.quotedTableName_() +
        " SET " +
        params +
        " WHERE \"id\"=@" +
        values.length.toString() +
        " RETURNING *";

    var res = await client_!.query(query, substitutionValues: values);

    var resValues = res.isNotEmpty
        ? Map<String, dynamic>.fromIterables(
            res.columnDescriptions.map((e) => e.columnName), res.first.toList())
        : null;

    var newItem = this.convertToPublic_(resValues);

    if (newItem != null) {
      logger_.trace(correlationId, "Updated partially in %s with id = %s",
          [this.tableName_, id]);
    }

    return newItem as T?;
  }

  /// Deleted a data item by it's unique id.
  ///
  /// - [correlation_id]    (optional) transaction id to trace execution through call chain.
  /// - [id]                an id of the item to be deleted
  /// Return the deleted item.
  @override
  Future<T?> deleteById(String? correlationId, K? id) async {
    var values = {'1': id};

    var query = "DELETE FROM " +
        this.quotedTableName_() +
        " WHERE \"id\"=@1 RETURNING *";

    var res = await client_!.query(query, substitutionValues: values);

    var resValues = res.isNotEmpty
        ? Map<String, dynamic>.fromIterables(
            res.columnDescriptions.map((e) => e.columnName), res.first.toList())
        : null;

    var newItem = this.convertToPublic_(resValues);

    if (newItem != null) {
      logger_.trace(
          correlationId, "Deleted from %s with id = %s", [this.tableName_, id]);
    }

    return newItem;
  }

  /// Deletes multiple data items by their unique ids.
  ///
  /// - [correlationId]     (optional) transaction id to trace execution through call chain.
  /// - [ids]               ids of data items to be deleted.
  Future<void> deleteByIds(String? correlationId, List<K> ids) async {
    var params = this.generateParameters_(ids);
    var query = "DELETE FROM " +
        this.quotedTableName_() +
        " WHERE \"id\" IN(" +
        params +
        ")";

    var values = generateValues_(ids);

    var res = await client_!.query(query, substitutionValues: values); // todo

    var count = res.affectedRowCount;

    logger_.trace(
        correlationId, "Deleted %d items from %s", [count, this.tableName_]);
  }
}
