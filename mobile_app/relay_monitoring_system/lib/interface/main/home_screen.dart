import 'package:flutter/services.dart';
import 'package:relay_monitoring_system/model/data.dart';
import 'package:relay_monitoring_system/model/threshold.dart' as my_threshold;
import 'package:relay_monitoring_system/myconfig.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
  enum ChartDisplayType {
  line,
  column,
  area,
  bar,
  }

class _HomeScreenState extends State<HomeScreen> {
  List<my_threshold.Threshold> thresholdList = [];  
  List<Data> dataList = [];
  String status = "Loading...";
  bool isLoading = false;
  bool showTemperatureChart = true;
  DateTimeRange dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 1)),
    end: DateTime.now(),
  );
  String selectedDevice = 'All';
  Set<String> deviceIds = {'All'};
  String timeGranularity = 'Hourly'; // 'Hourly', 'Daily', 'Weekly'

  // Pagination variables
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int _totalPages = 1;


  ChartDisplayType chartDisplayType = ChartDisplayType.line;

  @override
  void initState() {
    super.initState();
    loadRelayData();
    _fetchThresholds();
  }

  Future<void> _fetchThresholds() async {
    try {
      final response = await http.get(
        Uri.parse("${MyConfig.servername}/threshold_data/load_threshold.php"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            // Use the fully qualified name with the prefix
            thresholdList = [my_threshold.Threshold.fromJson(data)];
          });
        }
      }
    } catch (e) {
      developer.log("Error fetching thresholds: $e");
    }
  }

  Future<void> _updateThresholds(double temp, double hum) async {
    try {
      final response = await http.post(
        Uri.parse("${MyConfig.servername}/threshold_data/update_threshold.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'temp_threshold': temp,
          'hum_threshold': hum,
        }),
      );

      developer.log("Update response: ${response.statusCode}");
      developer.log("Update body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Thresholds updated successfully")),
          );
          await _fetchThresholds(); // Refresh the thresholds
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Update failed: ${data['error'] ?? 'Unknown error'}")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("HTTP error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      developer.log("Update error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update: ${e.toString()}")),
      );
    }
  }

  Future<void> _showThresholdDialog(BuildContext context) async {
    final tempController = TextEditingController(
      text: thresholdList.isNotEmpty 
          ? thresholdList.first.tempThreshold ?? '0' 
          : '0'
    );
    final humController = TextEditingController(
      text: thresholdList.isNotEmpty 
          ? thresholdList.first.humThreshold ?? '0' 
          : '0'
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Thresholds'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tempController,
              decoration: const InputDecoration(
                labelText: 'Temperature Threshold (°C)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: humController,
              decoration: const InputDecoration(
                labelText: 'Humidity Threshold (%)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final temp = double.tryParse(tempController.text);
              final hum = double.tryParse(humController.text);
              
              if (temp == null || hum == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter valid numbers")),
                );
                return;
              }
              
              await _updateThresholds(temp, hum);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> loadRelayData() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
            "${MyConfig.servername}/relay_data/load_data.php?"
            "start_date=${DateFormat('yyyy-MM-dd').format(dateRange.start)}"
            "&end_date=${DateFormat('yyyy-MM-dd').format(dateRange.end)}"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == "success") {
          final loadedData = (data['data'] as List)
              .map((item) => Data.fromJson(item))
              .toList();
            
          final ids = loadedData.map((d) => d.deviceId ?? '').toSet();
            
          setState(() {
            dataList = loadedData;
            deviceIds = {'All'}..addAll(ids.where((id) => id.isNotEmpty));
            status = "Loaded ${dataList.length} records";
            _calculateTotalPages();
          });
        }
      }
    } catch (e) {
      developer.log(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load data: ${e.toString()}")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _calculateTotalPages() {
    final filteredData = _getFilteredData();
    final displayData = timeGranularity == 'Hourly'
        ? filteredData
        : _aggregateTableData(filteredData);
    
    _totalPages = (displayData.length / _rowsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;
    if (_currentPage >= _totalPages) {
      _currentPage = _totalPages - 1;
    }
  }

   @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F2027),  // Dark blue
            Color(0xFF203A43),  // Medium blue
            Color(0xFF2C5364),  // Lighter blue
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,  // Make scaffold transparent to show background
        appBar: AppBar(
          title: const Text('DHT11 MONITOR', style: TextStyle(
            fontFamily: 'StarJedi',
            fontSize: 23,
            letterSpacing: 1,
            color: Colors.white,
          )),
          backgroundColor: Colors.black,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.yellow),
              onPressed: () => _showThresholdDialog(context),
              tooltip: 'Configure Thresholds',
            ),
            IconButton(
              icon: const Icon(Icons.filter_alt, color: Colors.yellow),
              onPressed: () => _showFiltersDialog(context),
              tooltip: 'Configure Holo-Filters',
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.yellow),
              onPressed: loadRelayData,
              tooltip: 'Scan for Rebel Activity',
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildStatsHeader(),
                    _buildChartControls(),
                    _buildMainChart(),
                    _buildDetailedReadingsSection(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    final filteredData = _getFilteredData();
    final latestData = filteredData.isNotEmpty ? filteredData.last : null;
    
    // Get the latest temperature value as double
    final tempValue = latestData?.temperature != null 
        ? double.tryParse(latestData!.temperature!) ?? 0.0 
        : 0.0;
    
    // Get threshold as double
    final tempThreshold = thresholdList.isNotEmpty 
        ? thresholdList.first.tempThresholdAsDouble?.toDouble() ?? 0.0 
        : 0.0;
    final isTempExceeded = tempValue > tempThreshold;
    
    // Get the latest humidity value as double
    final humValue = latestData?.humidity != null 
        ? double.tryParse(latestData!.humidity!) ?? 0.0 
        : 0.0;
    
    // Get threshold as double
    final humThreshold = thresholdList.isNotEmpty 
        ? thresholdList.first.humThresholdAsDouble?.toDouble() ?? 0.0 
        : 0.0;
    final isHumExceeded = humValue > humThreshold;

    // Relay turns ON if either temperature OR humidity exceeds threshold
    final isRelayOn = isTempExceeded || isHumExceeded;
    
    // Determine alert message based on what's exceeded
    String alertMessage = '';
    if (isTempExceeded && isHumExceeded) {
      alertMessage = 'ALERT: HIGH TEMPERATURE & HUMIDITY!';
    } else if (isTempExceeded) {
      alertMessage = 'ALERT: HIGH TEMPERATURE!';
    } else if (isHumExceeded) {
      alertMessage = 'ALERT: HIGH HUMIDITY!';
    }

    return Container(
      margin: EdgeInsets.all(10),
      padding: EdgeInsets.all(10),      
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black, Colors.blueGrey.shade900],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(12),
          bottom: Radius.circular(12),
        ),
        border: Border.all(color: Colors.yellow.shade700, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                Icons.device_thermostat, 
                latestData?.temperature ?? '--', 
                'TEMP', 
                '°C',
                threshold: tempThreshold,
                isExceeded: isTempExceeded,
              ),
              _buildStatCard(
                Icons.water_drop, 
                latestData?.humidity ?? '--', 
                'HUM', 
                '%',
                threshold: humThreshold,
                isExceeded: isHumExceeded,
              ),
              _buildStatCard(
                Icons.power, 
                isRelayOn ? 'ON' : 'OFF', 
                'RELAY', 
                isRelayOn ? 'ALERT!' : 'Normal',
                isExceeded: isRelayOn,
              ),
            ],
          ),
        if (alertMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red, width: 1),
                ),
                child: Text(
                  alertMessage,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'LATEST SCAN: ${latestData != null ? DateFormat('MMM d, HH:mm:ss').format(DateTime.parse(latestData.timestamp!)) : '--'}',
            style: TextStyle(
              color: Colors.yellow.shade400,
              fontFamily: 'StarJedi',
            ),
          ),
          if (selectedDevice != 'All')
            Text(
              'DEVICE: $selectedDevice',
              style: TextStyle(
                color: Colors.yellow.shade400,
                fontFamily: 'StarJedi',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String title, String unit, 
      {double? threshold, bool? isExceeded}) {
    
    final isRelayCard = title == 'RELAY';
    final numValue = isRelayCard ? 0.0 : double.tryParse(value) ?? 0.0;
    final showExceeded = isExceeded ?? (threshold != null && numValue > threshold);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: showExceeded ? Colors.red : Colors.yellow.shade700, 
          width: 2,
        ),
      ),
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 30, color: showExceeded ? Colors.red : Colors.yellow),
            const SizedBox(height: 8),
            // Main value (ON/OFF or temperature/humidity reading)
            Text(
              isRelayCard ? value : numValue.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: showExceeded ? Colors.red : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            // RELAY title (only for relay card)
            if (isRelayCard) Text(
              'RELAY',
              style: TextStyle(
                fontSize: 16,
                color: Colors.yellow.shade400,
                fontFamily: 'StarJedi',
              ),
            ),
            // Status (Normal/ALERT! or unit for other cards)
            Text(
              isRelayCard ? unit : title,
              style: TextStyle(
                fontSize: isRelayCard ? 10 : 16,
                color: isRelayCard 
                    ? (showExceeded ? Colors.red : Colors.yellow.shade600)
                    : Colors.yellow.shade400,
                fontFamily: isRelayCard ? null : 'StarJedi',
              ),
            ),
            // Threshold display (only for non-relay cards)
            if (!isRelayCard && threshold != null) Text(
              'Threshold: ${threshold.toStringAsFixed(1)}$unit',
              style: TextStyle(
                fontSize: 10,
                color: Colors.yellow.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHART CONTROLS',
            style: TextStyle(
              fontFamily: 'StarJedi',
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              // Toggle Buttons Box
              Expanded(
                flex: 2,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.yellow.shade700),
                  ),
                  child: Row(
                    children: [
                      _buildToggleTab('TEMP', showTemperatureChart, () {
                        setState(() => showTemperatureChart = true);
                      }),
                      _buildToggleTab('HUMID', !showTemperatureChart, () {
                        setState(() => showTemperatureChart = false);
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Dropdown Box
              Expanded(
                flex: 1,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.yellow.shade700),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ChartDisplayType>(
                      value: chartDisplayType,
                      dropdownColor: Colors.black,
                      iconEnabledColor: Colors.yellow.shade400,
                      style: TextStyle(
                        fontFamily: 'StarJedi',
                        fontSize: 12,
                        color: Colors.yellow.shade400,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ChartDisplayType.line,
                          child: Text('LINE'),
                        ),
                        DropdownMenuItem(
                          value: ChartDisplayType.column,
                          child: Text('COLUMN'),
                        ),
                        DropdownMenuItem(
                          value: ChartDisplayType.area,
                          child: Text('AREA'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => chartDisplayType = value);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTab(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.yellow.shade400 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'StarJedi',
              fontSize: 12,
              color: isSelected ? Colors.black : Colors.yellow.shade400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainChart() {
    final filteredData = _getFilteredData();
    final chartData = _aggregateChartData(filteredData);

    final isTemp = showTemperatureChart;
    final yAxisTitle = isTemp ? 'TEMP (°C)' : 'HUM (%)';
    final seriesColor = isTemp ? Colors.redAccent : Colors.lightBlueAccent;
    final seriesName = isTemp ? 'Temperature' : 'Humidity';

    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black87, Colors.blueGrey.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.yellow.shade700, width: 1),
      ),
      child: SizedBox(
        height: 260,
        child: SfCartesianChart(
          backgroundColor: Colors.transparent, // let container bg show through
          plotAreaBorderColor: const Color.fromRGBO(251, 192, 45, 1),
          primaryXAxis: DateTimeAxis(
            title: AxisTitle(
              text: 'TIME',
              textStyle: TextStyle(color: Colors.yellow.shade400, fontSize: 12, fontFamily: 'StarJedi'),
            ),
            labelStyle: TextStyle(color: Colors.yellow.shade400, fontSize: 12, fontFamily: 'StarJedi'),
            axisLine: const AxisLine(color: Colors.yellow),
          ),
          primaryYAxis: NumericAxis(
            title: AxisTitle(
              text: yAxisTitle,
              textStyle: TextStyle(color: Colors.yellow.shade400, fontFamily: 'StarJedi'),
            ),
            labelStyle: TextStyle(color: Colors.yellow.shade400, fontFamily: 'StarJedi'),
            axisLine: const AxisLine(color: Colors.yellow),
          ),
          series: _getChartSeries(chartData, seriesColor, seriesName),
          tooltipBehavior: TooltipBehavior(
            enable: true,
            color: Colors.black,
            textStyle: TextStyle(color: Colors.yellow.shade300, fontFamily: 'StarJedi'),
          ),
        ),
      ),
    );
  }

  List<ChartSeries<ChartDataPoint, DateTime>> _getChartSeries(
    List<ChartDataPoint> data,
    Color color,
    String name,
  ) {
    switch (chartDisplayType) {
      case ChartDisplayType.column:
        return [
          ColumnSeries<ChartDataPoint, DateTime>(
            dataSource: data,
            xValueMapper: (point, _) => point.time,
            yValueMapper: (point, _) => point.value,
            name: name,
            color: color,
          ),
        ];
      case ChartDisplayType.area:
        return [
          AreaSeries<ChartDataPoint, DateTime>(
            dataSource: data,
            xValueMapper: (point, _) => point.time,
            yValueMapper: (point, _) => point.value,
            name: name,
            color: color,
          ),
        ];
      default:
        return [
          LineSeries<ChartDataPoint, DateTime>(
            dataSource: data,
            xValueMapper: (point, _) => point.time,
            yValueMapper: (point, _) => point.value,
            name: name,
            color: color,
            markerSettings: const MarkerSettings(isVisible: true),
          ),
        ];
    }
  }

  Widget _buildDetailedReadingsSection() {
    final filteredData = _getFilteredData();
    final displayData = timeGranularity == 'Hourly'
        ? filteredData
        : _aggregateTableData(filteredData);

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    final paginatedData = displayData.sublist(
      startIndex.clamp(0, displayData.length),
      endIndex.clamp(0, displayData.length),
    );
    final actualEndIndex = endIndex > displayData.length ? displayData.length : endIndex;

    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                const Text(
                  'Past Readings',
                  style: TextStyle(
                    fontFamily: 'StarJedi',
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade800.withOpacity(0.2),
                    border: Border.all(color: Colors.yellow.shade600, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Granularity: $timeGranularity',
                    style: const TextStyle(
                      fontFamily: 'RussoOne',
                      fontSize: 13,
                      color: Color(0xFFFFEE58),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Data Table
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Card(
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.yellow, width: 1),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 28,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF1F1F1F)),
                  dataRowColor: WidgetStateProperty.all(const Color(0xFF121212)),
                  columns: [
                    DataColumn(label: _buildColumnLabel('🕒 TIME')),
                    DataColumn(label: _buildColumnLabel('🛰 DEVICE')),
                    DataColumn(label: _buildColumnLabel('🌡 TEMP (°C)')),
                    DataColumn(label: _buildColumnLabel('💧 HUM (%)')),
                    DataColumn(label: _buildColumnLabel('🛡 STATUS')),
                  ],
                  rows: paginatedData.map((data) {
                    return DataRow(
                      cells: [
                        DataCell(_buildDataCell(_formatTime(data.timestamp))),
                        DataCell(_buildDataCell(data.deviceId ?? '--')),
                        DataCell(_buildDataCell(data.temperature?.toString() ?? '--')),
                        DataCell(_buildDataCell(data.humidity?.toString() ?? '--')),
                        DataCell(
                          Chip(
                            label: Text(
                              data.relayStatus == '1' ? 'ONLINE' : 'OFFLINE',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'RussoOne',
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: data.relayStatus == '1'
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            elevation: 3,
                            shadowColor: Colors.yellow,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Pagination Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  const Text(
                    'Rows per page:',
                    style: TextStyle(
                      color: Color(0xFFBBBBBB),
                      fontFamily: 'RussoOne',
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    dropdownColor: const Color(0xFF0D0D0D),
                    value: _rowsPerPage,
                    iconEnabledColor: const Color(0xFF00FFE4),
                    style: TextStyle(
                      fontFamily: 'RussoOne',
                      color: Colors.yellow.shade600,
                    ),
                    items: [5, 10, 15, 20, 25].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _rowsPerPage = value;
                          _calculateTotalPages();
                          _currentPage = 0;
                        });
                      }
                    },
                  ),
                  const Spacer(),
                  Text(
                    '${startIndex + 1}–$actualEndIndex of ${displayData.length}',
                    style: const TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontFamily: 'RussoOne',
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    color: _currentPage > 0
                        ? const Color(0xFF00FFE4)
                        : Colors.grey.shade700,
                    onPressed: _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    color: _currentPage < _totalPages - 1
                        ? const Color(0xFF00FFE4)
                        : Colors.grey.shade700,
                    onPressed: _currentPage < _totalPages - 1
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFFFEE58),
        fontFamily: 'RussoOne',
        fontWeight: FontWeight.bold,
        shadows: [Shadow(blurRadius: 4, color: Color(0xFFFFEE58))],
      ),
    );
  }

  Widget _buildDataCell(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'RussoOne',
      ),
    );
  }

  Future<void> _showFiltersDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Filter Data'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Date Range'),
                    subtitle: Text(
                        '${DateFormat('MMM d, y').format(dateRange.start)} - '
                        '${DateFormat('MMM d, y').format(dateRange.end)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: dateRange,
                      );
                      if (picked != null) {
                        setState(() => dateRange = picked);
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Device'),
                    trailing: DropdownButton<String>(
                      value: selectedDevice,
                      items: deviceIds.map((id) {
                        return DropdownMenuItem(
                          value: id,
                          child: Text(id),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedDevice = value);
                        }
                      },
                    ),
                  ),
                  const Divider(),
                  const Text('Time Granularity'),
                  ToggleButtons(
                    isSelected: [
                      timeGranularity == 'Hourly',
                      timeGranularity == 'Daily',
                      timeGranularity == 'Weekly',
                    ],
                    onPressed: (index) {
                      setState(() {
                        timeGranularity = 
                          index == 0 ? 'Hourly' : index == 1 ? 'Daily' : 'Weekly';
                      });
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Hourly'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Daily'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Weekly'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  loadRelayData();
                },
                child: const Text('Apply Filters'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Data> _getFilteredData() {
    return dataList.where((data) {
      final isDeviceMatch = selectedDevice == 'All' || 
          data.deviceId == selectedDevice;
      final dataTime = DateTime.parse(data.timestamp ?? '');
      return isDeviceMatch && 
          dataTime.isAfter(dateRange.start) && 
          dataTime.isBefore(dateRange.end.add(const Duration(days: 1)));
    }).toList();
  }

  List<ChartDataPoint> _aggregateChartData(List<Data> filteredData) {
    if (timeGranularity == 'Hourly') {
      return filteredData.map((data) {
        return ChartDataPoint(
          time: DateTime.parse(data.timestamp ?? DateTime.now().toString()),
          value: double.parse(
              (showTemperatureChart ? data.temperature ?? '0' : data.humidity ?? '0')),
        );
      }).toList();
    }

    // Group by day/week
    final Map<String, List<Data>> groupedData = {};
    for (final data in filteredData) {
      final date = DateTime.parse(data.timestamp ?? '');
      final key = timeGranularity == 'Daily'
          ? '${date.year}-${date.month}-${date.day}'
          : '${date.year}-${date.weekOfYear}';

      groupedData.putIfAbsent(key, () => []).add(data);
    }

    return groupedData.entries.map((entry) {
      final values = entry.value
          .map((d) => double.parse(
              showTemperatureChart ? (d.temperature ?? '0') : (d.humidity ?? '0')))
          .toList();
      final avgValue = values.reduce((a, b) => a + b) / values.length;
      
      return ChartDataPoint(
        time: DateTime.parse(entry.value.first.timestamp ?? ''),
        value: avgValue,
      );
    }).toList();
  }

  List<Data> _aggregateTableData(List<Data> filteredData) {
    if (timeGranularity == 'Hourly') return filteredData;

    final Map<String, Data> aggregatedData = {};
    for (final data in filteredData) {
      final date = DateTime.parse(data.timestamp ?? '');
      final key = timeGranularity == 'Daily'
          ? '${date.year}-${date.month}-${date.day}'
          : '${date.year}-${date.weekOfYear}';

      if (!aggregatedData.containsKey(key)) {
        aggregatedData[key] = Data(
          deviceId: data.deviceId,
          timestamp: data.timestamp,
          temperature: data.temperature,
          humidity: data.humidity,
          relayStatus: data.relayStatus,
        );
      } else {
        // For demo purposes - in real app you'd want proper aggregation
        final existing = aggregatedData[key]!;
        aggregatedData[key] = Data(
          deviceId: existing.deviceId,
          timestamp: existing.timestamp,
          temperature: _averageValues(existing.temperature, data.temperature),
          humidity: _averageValues(existing.humidity, data.humidity),
          relayStatus: existing.relayStatus,
        );
      }
    }

    return aggregatedData.values.toList();
  }

  String _averageValues(String? val1, String? val2) {
    try {
      final num1 = double.tryParse(val1 ?? '0') ?? 0;
      final num2 = double.tryParse(val2 ?? '0') ?? 0;
      return ((num1 + num2) / 2).toStringAsFixed(1);
    } catch (e) {
      return '0'; // Return default value instead of null
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '--';
    try {
      final date = DateTime.parse(timestamp);
      if (timeGranularity == 'Daily') {
        return DateFormat('MMM d, y').format(date);
      } else if (timeGranularity == 'Weekly') {
        return 'Week ${date.weekOfYear}, ${date.year}';
      }
      return DateFormat('MMM d, HH:mm').format(date);
    } catch (e) {
      return '--';
    }
  }
}

class ChartDataPoint {
  final DateTime time;
  final double value;

  ChartDataPoint({required this.time, required this.value});
}

extension DateTimeExtension on DateTime {
  int get weekOfYear {
    final firstDay = DateTime(year, 1, 1);
    final daysDiff = difference(firstDay).inDays;
    return ((daysDiff + firstDay.weekday - 1) / 7).floor() + 1;
  }
}