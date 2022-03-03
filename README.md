# <img src="https://uploads-ssl.webflow.com/5ea5d3315186cf5ec60c3ee4/5edf1c94ce4c859f2b188094_logo.svg" alt="Pip.Services Logo" width="200"> <br/> PostgreSQL components for Pip.Service in Dart

This module is a part of the [Pip.Services](http://pipservices.org) polyglot microservices toolkit. It provides a set of components to implement PostgreSQL persistence.

The module contains the following packages:
- **Build** - Factory to create PostreSQL persistence components.
- **Connect** - Connection component to configure PostgreSQL connection to database.
- **Persistence** - abstract persistence components to perform basic CRUD operations.

<a name="links"></a> Quick links:

* [Configuration](http://docs.pipservices.org/toolkit/getting_started/configurations/)
* [API Reference](https://pub.dev/documentation/pip_services3_postgres/latest/pip_services3_postgres/pip_services3_postgres-library.html)
* [Change Log](CHANGELOG.md)
* [Get Help](http://docs.pipservices.org/get_help/)
* [Contribute](http://docs.pipservices.org/toolkit/contribute/)

## Use

Add this to your package's pubspec.yaml file:
```yaml
dependencies:
  pip_services3_postgres: version
```

As an example, lets create persistence for the following data object.

```dart
import 'package:pip_services3_commons/pip_services3_commons.dart';

class MyObject implements IStringIdentifiable, ICloneable {
  @override
  String? id;
  String? key;
  String? content;

  MyObject();

  MyObject.from(this.id, this.key, this.content);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'key': key, 'content': content};
  }

  void fromJson(Map<String, dynamic> json) {
    id = json['id'];
    key = json['key'];
    content = json['content'];
  }

  @override
  MyObject clone() {
    return MyObject.from(id, key, content);
  }
}
```

The persistence component shall implement the following interface with a basic set of CRUD operations.

```dart
abstract class IMyPersistence {
  Future<DataPage<MyObject>> getPageByFilter(
      String? correlationId, FilterParams? filter, PagingParams? paging);

  Future<MyObject?> getOneById(String? correlationId, String id);

  Future<MyObject?> getOneByKey(String? correlationId, String key);

  Future<MyObject?> create(String? correlationId, MyObject? item);

  Future<MyObject?> update(String? correlationId, MyObject? item);

  Future<MyObject?> set(String? correlationId, MyObject? item);

  Future<MyObject?> deleteById(String? correlationId, String? id);
}
```

To implement postgresql persistence component you shall inherit `IdentifiablePostgresPersistence`. 
Most CRUD operations will come from the base class. You only need to override `getPageByFilter` method with a custom filter function.
And implement a `getOneByKey` custom persistence method that doesn't exist in the base class.

```dart
class MyPostgresPersistence
    extends IdentifiablePostgresPersistence<MyObject, String> {
  MyPostgresPersistence() : super('myobjects', null) {
    ensureSchema_(
        "CREATE TABLE myobjects (id VARCHAR(32) PRIMARY KEY, key VARCHAR(50), content VARCHAR(255))");
    ensureIndex_("myobjects_key", {'key': 1}, {'unique': true});
  }

  @override
  void defineSchema_() {
    // pass
  }

  String? _composeFilter(FilterParams? filter) {
    filter = filter ?? FilterParams();

    var criteria = [];

    var id = filter.getAsNullableString('id');
    if (id != null) criteria.add("id='" + id + "'");

    var tempIds = filter.getAsNullableString("ids");
    if (tempIds != null) {
      var ids = tempIds.split(",");
      criteria.add("id IN ('" + ids.join("','") + "')");
    }

    var key = filter.getAsNullableString("key");
    if (key != null) criteria.add("key='" + key + "'");

    return criteria.length > 0 ? criteria.join(" AND ") : null;
  }

  Future<DataPage<MyObject>> getPageByFilter(
      String? correlationId, FilterParams? filter, PagingParams? paging) {
    return super.getPageByFilter_(
        correlationId, _composeFilter(filter), paging, null, null);
  }

  Future<MyObject?> getOneByKey(String? correlationId, String key) async {
    var query =
        "SELECT * FROM " + this.quotedTableName_() + " WHERE \"key\"=@1";
    var params = {'1': key};

    var res = await client_!.query(query, substitutionValues: params);

    var resValues = res.isNotEmpty ? res.first[0][1] : null;

    var item = this.convertToPublic_(resValues);

    if (item == null)
      this.logger_.trace(correlationId, "Nothing found from %s with key = %s",
          [this.tableName_, key]);
    else
      this.logger_.trace(correlationId, "Retrieved from %s with key = %s",
          [this.tableName_, key]);

    item = this.convertToPublic_(item);
    return item;
  }
}
```

Alternatively you can store data in non-relational format using `IdentificableJsonPostgresPersistence`.
It stores data in tables with two columns - `id` with unique object id and `data` with object data serialized as JSON.
To access data fields you shall use `data->'field'` expression or `data->>'field'` expression for string values.

```dart
class MyPostgresJsonPersistence
    extends IdentifiableJsonPostgresPersistence<MyObject, String> {
  MyPostgresJsonPersistence() : super('myobjects_json', null) {
    clearSchema();
    ensureTable_(idType: "VARCHAR(32)", dataType: "JSONB");
    ensureIndex_(this.tableName_! + '_json_key', {"(data->>'key')": 1},
        {'unique': true});
  }

  @override
  void defineSchema_() {
    // pass
  }

  String? _composeFilter(FilterParams? filter) {
    filter = filter ?? FilterParams();

    var criteria = [];

    var id = filter.getAsNullableString('id');
    if (id != null) criteria.add("data->>'id'='" + id + "'");

    var tempIds = filter.getAsNullableString("ids");
    if (tempIds != null) {
      var ids = tempIds.split(",");
      criteria.add("data->>'id' IN ('" + ids.join("','") + "')");
    }

    var key = filter.getAsNullableString("key");
    if (key != null) criteria.add("data->>'key'='" + key + "'");

    return criteria.length > 0 ? criteria.join(" AND ") : null;
  }

  Future<DataPage<MyObject>> getPageByFilter(
      String? correlationId, FilterParams? filter, PagingParams? paging) {
    return super.getPageByFilter_(
        correlationId, _composeFilter(filter), paging, 'id', null);
  }

  Future<MyObject?> getOneByKey(String? correlationId, String key) async {
    var query =
        "SELECT * FROM " + this.quotedTableName_() + " WHERE data->>'key'=@1";
    var params = {'1': key};

    var res = await client_!.query(query, substitutionValues: params);

    var resValues = res.isNotEmpty ? res.first[0][1] : null;

    var item = this.convertToPublic_(resValues);

    if (item == null)
      this.logger_.trace(correlationId, "Nothing found from %s with key = %s",
          [this.tableName_, key]);
    else
      this.logger_.trace(correlationId, "Retrieved from %s with key = %s",
          [this.tableName_, key]);

    item = this.convertToPublic_(item);
    return item;
  }
}
```

Configuration for your microservice that includes postgresql persistence may look the following way.

```yaml
...
{{#if POSTGRES_ENABLED}}
- descriptor: pip-services:connection:postgres:con1:1.0
  connection:
    uri: {{{POSTGRES_SERVICE_URI}}}
    host: {{{POSTGRES_SERVICE_HOST}}}{{#unless POSTGRES_SERVICE_HOST}}localhost{{/unless}}
    port: {{POSTGRES_SERVICE_PORT}}{{#unless POSTGRES_SERVICE_PORT}}5432{{/unless}}
    database: {{POSTGRES_DB}}{{#unless POSTGRES_DB}}app{{/unless}}
  credential:
    username: {{POSTGRES_USER}}
    password: {{POSTGRES_PASS}}
    
- descriptor: myservice:persistence:postgres:default:1.0
  dependencies:
    connection: pip-services:connection:postgres:con1:1.0
  table: {{POSTGRES_TABLE}}{{#unless POSTGRES_TABLE}}myobjects{{/unless}}
{{/if}}
...
```


Now you can install package from the command line:
```bash
pub get
```

## Develop

For development you shall install the following prerequisites:
* Dart SDK 2
* Visual Studio Code or another IDE of your choice
* Docker

Install dependencies:
```bash
pub get
```

Run automated tests:
```bash
pub run test
```

Generate API documentation:
```bash
./docgen.ps1
```

Before committing changes run dockerized build and test as:
```bash
./build.ps1
./test.ps1
./clear.ps1
```

## Contacts

The module is created and maintained by 
- **Sergey Seroukhov**
- **Danil Prisiazhnyi**