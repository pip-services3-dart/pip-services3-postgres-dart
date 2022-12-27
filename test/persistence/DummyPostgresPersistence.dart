import 'package:pip_services3_commons/src/data/PagingParams.dart';
import 'package:pip_services3_commons/src/data/FilterParams.dart';
import 'package:pip_services3_commons/src/data/DataPage.dart';
import 'package:pip_services3_postgres/src/persistence/persistence.dart';

import '../fixtures/Dummy.dart';
import '../fixtures/IDummyPersistence.dart';

class DummyPostgresPersistence
    extends IdentifiablePostgresPersistence<Dummy, String>
    implements IDummyPersistence {
  DummyPostgresPersistence() : super('dummies', null);

  @override
  void defineSchema_() {
    this.clearSchema();
    this.ensureSchema_('CREATE TABLE ' +
        this.tableName_! +
        ' (id TEXT PRIMARY KEY, key TEXT, content TEXT)');
    this.ensureIndex_(this.tableName_! + '_key', {'key': 1}, {'unique': true});
  }

  Future<DataPage<Dummy>> getPageByFilter(
      String? correlationId, FilterParams? filter, PagingParams? paging) {
    filter = filter ?? FilterParams();
    var key = filter.getAsNullableString('key');

    var filterCondition = "";
    if (key != null) filterCondition += "key='" + key + "'";

    return super
        .getPageByFilter_(correlationId, filterCondition, paging, null, null);
  }

  @override
  Future<int> getCountByFilter(String? correlationId, FilterParams? filter) {
    filter = filter ?? new FilterParams();
    var key = filter.getAsNullableString('key');

    var filterCondition = "";
    if (key != null) filterCondition += "key='" + key + "'";

    return super.getCountByFilter_(correlationId, filterCondition);
  }
}
