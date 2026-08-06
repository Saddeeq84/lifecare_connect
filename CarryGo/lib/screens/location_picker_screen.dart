import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../l10n/app_localizations.dart';
import '../widgets/carrygo_brand.dart';
import 'settings_screen.dart';

class LocationSelection {
  final String address;
  final LatLng coordinates;

  const LocationSelection({
    required this.address,
    required this.coordinates,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final String title;
  final String initialAddress;
  final LatLng? initialLocation;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.initialAddress = '',
    this.initialLocation,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final TextEditingController _addressController;
  late LatLng _selectedLocation;
  GoogleMapController? _mapController;

  static const _fallbackLocation = LatLng(6.5244, 3.3792);

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialAddress);
    _selectedLocation = widget.initialLocation ?? _fallbackLocation;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    _setLocation(LatLng(position.latitude, position.longitude));
  }

  void _setLocation(LatLng location) {
    setState(() => _selectedLocation = location);
    _mapController?.animateCamera(CameraUpdate.newLatLng(location));
  }

  void _save() {
    Navigator.pop(
      context,
      LocationSelection(
        address: _addressController.text.trim(),
        coordinates: _selectedLocation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CarryGoAppBarTitle(label: widget.title),
        actions: const [SettingsIconButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText:
                        '${context.tr(widget.title)} ${context.tr('address')}',
                    suffixIcon: IconButton(
                      tooltip: context.tr('Use address text'),
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _useCurrentLocation,
                        icon: const Icon(Icons.my_location),
                        label: Text(context.tr('Current GPS')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.check),
                        label: Text(context.tr('Use location')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLocation,
                zoom: 15,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: _setLocation,
              markers: {
                Marker(
                  markerId: const MarkerId('selected-location'),
                  position: _selectedLocation,
                  draggable: true,
                  onDragEnd: _setLocation,
                ),
              },
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Lat ${_selectedLocation.latitude.toStringAsFixed(6)}, '
              'Lng ${_selectedLocation.longitude.toStringAsFixed(6)}',
            ),
          ),
        ],
      ),
    );
  }
}
