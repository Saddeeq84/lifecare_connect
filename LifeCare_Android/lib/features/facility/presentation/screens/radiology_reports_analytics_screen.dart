import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RadiologyReportsAnalyticsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const RadiologyReportsAnalyticsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<RadiologyReportsAnalyticsScreen> createState() =>
      _RadiologyReportsAnalyticsScreenState();
}

class _RadiologyReportsAnalyticsScreenState
    extends State<RadiologyReportsAnalyticsScreen> {
  int _totalImagingRequests = 0;
  int _pendingImaging = 0;
  int _imagingInProgress = 0;
  int _completedToday = 0;
  double _revenueToday = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Total imaging requests
      final totalQuery = await FirebaseFirestore.instance
          .collection('pending_imaging')
          .where('facilityId', isEqualTo: widget.facilityId)
          .get();

      // Pending imaging
      final pendingQuery = await FirebaseFirestore.instance
          .collection('pending_imaging')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'pending')
          .get();

      // In progress imaging
      final inProgressQuery = await FirebaseFirestore.instance
          .collection('pending_imaging')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'in_progress')
          .get();

      // Completed today
      final completedTodayQuery = await FirebaseFirestore.instance
          .collection('pending_imaging')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'completed')
          .where(
            'completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .get();

      // Calculate revenue today
      double revenueToday = 0.0;
      for (var doc in completedTodayQuery.docs) {
        final data = doc.data();
        final cost = (data['cost'] as num?)?.toDouble() ?? 0.0;
        revenueToday += cost;
      }

      if (mounted) {
        setState(() {
          _totalImagingRequests = totalQuery.docs.length;
          _pendingImaging = pendingQuery.docs.length;
          _imagingInProgress = inProgressQuery.docs.length;
          _completedToday = completedTodayQuery.docs.length;
          _revenueToday = revenueToday;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radiology Reports & Analytics'),
        backgroundColor: Colors.cyan.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.cyan.shade700, Colors.cyan.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Radiology Department',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      widget.facilityName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.cyan.shade100,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Last updated: ${DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.now())}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Radiology Statistics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Statistics Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.3,
                      children: [
                        _buildStatCard(
                          'Total Imaging Requests',
                          _totalImagingRequests.toString(),
                          Icons.medical_services,
                          Colors.cyan,
                          'All imaging requests received by radiology department',
                        ),
                        _buildStatCard(
                          'Pending Imaging',
                          _pendingImaging.toString(),
                          Icons.pending_actions,
                          Colors.orange,
                          'Imaging requests waiting to be processed',
                        ),
                        _buildStatCard(
                          'In Progress',
                          _imagingInProgress.toString(),
                          Icons.hourglass_empty,
                          Colors.blue,
                          'Imaging procedures currently being performed',
                        ),
                        _buildStatCard(
                          'Completed Today',
                          _completedToday.toString(),
                          Icons.check_circle,
                          Colors.green,
                          'Imaging procedures completed today',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Revenue Card
                    _buildRevenueCard(),

                    const SizedBox(height: 24),

                    // Additional Info Section
                    Text(
                      'Department Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildInfoCard(),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String description,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showStatDetails(title, value, description);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey.shade400,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.green.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.attach_money,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Revenue Today',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '₦${_revenueToday.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total revenue generated from imaging procedures completed today',
              style: TextStyle(fontSize: 13, color: Colors.green.shade100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.cyan.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'About Radiology Reports',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.check_circle_outline,
              'Track all imaging requests from OPD, Ward, and Specialist departments',
            ),
            _buildInfoRow(
              Icons.check_circle_outline,
              'Monitor pending, in-progress, and completed imaging procedures',
            ),
            _buildInfoRow(
              Icons.check_circle_outline,
              'View real-time revenue generated from radiology services',
            ),
            _buildInfoRow(
              Icons.check_circle_outline,
              'Support for X-Ray, CT, MRI, Ultrasound, and Echocardiography',
            ),
            const SizedBox(height: 12),
            Text(
              'Pull down to refresh statistics',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.cyan.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatDetails(String title, String value, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Value: $value',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
