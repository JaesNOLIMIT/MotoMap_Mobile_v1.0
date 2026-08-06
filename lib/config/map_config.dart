class MapConfig {
  const MapConfig._();

  static const styleUrl = String.fromEnvironment(
    'MOTOMAP_MAP_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
  );

  static const geocoderUrl = String.fromEnvironment(
    'MOTOMAP_GEOCODER_URL',
    defaultValue: 'https://nominatim.openstreetmap.org',
  );

  static const routerUrl = String.fromEnvironment(
    'MOTOMAP_ROUTER_URL',
    defaultValue: 'https://valhalla1.openstreetmap.de',
  );

  static const userAgent = 'MotoMap/1.0 (io.motomap.app)';
}
