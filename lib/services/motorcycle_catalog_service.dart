import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/motorcycle_catalog.dart';

class MotorcycleCatalogService {
  MotorcycleCatalogService._();

  static final instance = MotorcycleCatalogService._();
  static const source = 'nhtsa_vpic';
  static const _baseUrl = 'https://vpic.nhtsa.dot.gov/api/vehicles';

  List<MotorcycleCatalogMake>? _makeCache;
  final Map<String, List<MotorcycleCatalogModel>> _modelCache = {};

  Future<List<MotorcycleCatalogMake>> fetchMakes() async {
    final cached = _makeCache;
    if (cached != null) return cached;
    final json = await _getJson(
      Uri.parse('$_baseUrl/GetMakesForVehicleType/motorcycle?format=json'),
    );
    final makes =
        (json['Results'] as List<dynamic>? ?? const [])
            .map(
              (item) => MotorcycleCatalogMake.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .where((make) => make.name.isNotEmpty)
            .toList(growable: false)
          ..sort((left, right) => left.name.compareTo(right.name));
    _makeCache = makes;
    return makes;
  }

  Future<List<MotorcycleCatalogModel>> fetchModels({
    required String make,
    required int year,
  }) async {
    final normalizedMake = make.trim();
    if (normalizedMake.isEmpty) return const [];
    final key = '${normalizedMake.toLowerCase()}-$year';
    final cached = _modelCache[key];
    if (cached != null) return cached;
    final encodedMake = Uri.encodeComponent(normalizedMake);
    final json = await _getJson(
      Uri.parse(
        '$_baseUrl/GetModelsForMakeYear/make/$encodedMake/modelyear/$year/'
        'vehicletype/motorcycle?format=json',
      ),
    );
    final models =
        (json['Results'] as List<dynamic>? ?? const [])
            .map(
              (item) => MotorcycleCatalogModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .where((model) => model.name.isNotEmpty)
            .toList(growable: false)
          ..sort((left, right) => left.name.compareTo(right.name));
    _modelCache[key] = models;
    return models;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError(
        'Motorcycle catalog is temporarily unavailable '
        '(HTTP ${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw StateError('Motorcycle catalog returned an invalid response.');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
