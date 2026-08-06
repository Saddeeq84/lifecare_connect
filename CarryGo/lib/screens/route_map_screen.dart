import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/order.dart';
import '../widgets/carrygo_brand.dart';
import 'settings_screen.dart';

class RouteMapScreen extends StatelessWidget {
  final Order order;

  const RouteMapScreen({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final hasPickupCoordinates = _hasCoordinates(order.pickupLocation);
    final hasDropoffCoordinates = _hasCoordinates(order.dropoffLocation);
    final route = Polyline(
      polylineId: const PolylineId('carrygo-route'),
      points: [order.pickupLocation, order.dropoffLocation],
      width: 5,
      color: Theme.of(context).colorScheme.primary,
    );

    return Scaffold(
      appBar: AppBar(
        title: const CarryGoAppBarTitle(label: 'Route'),
        actions: const [SettingsIconButton()],
      ),
      body: Column(
        children: [
          Expanded(
            child: hasPickupCoordinates && hasDropoffCoordinates
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: order.pickupLocation,
                      zoom: 13,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: order.pickupLocation,
                        infoWindow: InfoWindow(
                          title: context.tr('Pick-up'),
                          snippet: order.pickupAddress,
                        ),
                      ),
                      Marker(
                        markerId: const MarkerId('dropoff'),
                        position: order.dropoffLocation,
                        infoWindow: InfoWindow(
                          title: context.tr('Drop-off'),
                          snippet: order.dropoffAddress,
                        ),
                      ),
                    },
                    polylines: {route},
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.map),
                          title: Text(context.tr('Address route')),
                          subtitle: Text(
                            '${context.tr('Pick-up')}: ${order.pickupAddress}\n'
                            '${context.tr('Drop-off')}: ${order.dropoffAddress}',
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          ListTile(
            leading: const Icon(Icons.route),
            title: Text(order.distance > 0
                ? '${order.distance.toStringAsFixed(2)} km'
                : context.tr('Address based route')),
            subtitle: Text(
              '${order.estimatedDurationMinutes} ${context.tr('min estimated travel time')}',
            ),
            trailing: FilledButton.icon(
              onPressed: () => _openGoogleMaps(order),
              icon: const Icon(Icons.navigation),
              label: Text(context.tr('Open Maps')),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasCoordinates(LatLng location) {
    return location.latitude != 0 || location.longitude != 0;
  }

  Future<void> _openGoogleMaps(Order order) async {
    final hasPickup = _hasCoordinates(order.pickupLocation);
    final hasDropoff = _hasCoordinates(order.dropoffLocation);
    final Uri uri;
    if (hasPickup && hasDropoff) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${order.pickupLocation.latitude},${order.pickupLocation.longitude}'
        '&destination=${order.dropoffLocation.latitude},${order.dropoffLocation.longitude}'
        '&travelmode=driving',
      );
    } else {
      uri = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${order.pickupAddress} ${order.city} Nigeria',
      });
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
