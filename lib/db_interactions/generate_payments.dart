import 'package:flutter/material.dart';
import 'package:flutter_application_1/global/payment_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
class PaymentGenerationPage extends StatefulWidget {
  const PaymentGenerationPage({super.key});

  @override
  State<PaymentGenerationPage> createState() => _PaymentGenerationPageState();
}

class _PaymentGenerationPageState extends State<PaymentGenerationPage> {
  final PaymentService _service = PaymentService();
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  
  List<Map<String, dynamic>> previewData = [];
  bool isLoading = false;

  final List<String> months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  // 1. Fetch preview (Already ordered by ID from your SQL RPC)
  Future<void> loadPreview() async {
    setState(() => isLoading = true);
    try {
      final data = await _service.getGeneratedBillData(selectedMonth, selectedYear);
      setState(() => previewData = data);
    } catch (e) {
      _showSnack("Error loading preview: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 2. Save to DB (Maintains the list order)
  Future<void> saveToDb() async {
    if (previewData.isEmpty) return;
    setState(() => isLoading = true);
    try {
      // Passing the sorted previewData list directly
      await _service.saveBillsToDatabase(previewData, selectedMonth, selectedYear);
      _showSnack("Bills successfully saved in order!");
    } catch (e) {
      _showSnack("Save failed: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 3. PDF Generation Placeholder

  Future<void> generatePDF() async {
  if (previewData.isEmpty) {
    _showSnack("No data to generate PDF");
    return;
  }

  final pdf = pw.Document();

  // 1. Calculate Totals (Matches your Preview Table logic)
  double totalUnits = 0;
  double totalElec = 0;
  double totalWater = 0;
  double totalRent = 0;
  double totalAll = 0;

  for (var item in previewData) {
    totalUnits += double.tryParse(item['units_used']?.toString() ?? '0') ?? 0;
    totalElec += double.tryParse(item['electricity_cost']?.toString() ?? '0') ?? 0;
    totalWater += double.tryParse(item['water_charge']?.toString() ?? '0') ?? 0;
    totalRent += double.tryParse(item['rent_charge']?.toString() ?? '0') ?? 0;
    totalAll += double.tryParse(item['total_amount']?.toString() ?? '0') ?? 0;
  }

  // 2. Prepare the Data Rows for the Table
  final List<List<String>> tableData = previewData.map((item) {
    return [
      item['house_number']?.toString() ?? '-',
      item['units_used']?.toString() ?? '0',
      item['electricity_cost']?.toString() ?? '0',
      item['water_charge']?.toString() ?? '0',
      item['rent_charge']?.toString() ?? '0',
      item['total_amount']?.toString() ?? '0',
      item['house_number']?.toString() ?? '-',
    ];
  }).toList();

  // 3. Append the TOTAL Row to the table data
  tableData.add([
    'TOTAL',
    totalUnits.toStringAsFixed(0),
    totalElec.toStringAsFixed(0),
    totalWater.toStringAsFixed(0),
    totalRent.toStringAsFixed(0),
    "Rs. ${totalAll.toStringAsFixed(0)}",
    'TOTAL'
  ]);

  // 4. Build the Document
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Monthly Billing Summary", 
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('MMM yyyy').format(DateTime.now())),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          pw.TableHelper.fromTextArray(
            headers: ['House', 'Units', 'Elec', 'Water', 'Rent', 'Total', 'House'],
            data: tableData,
            border: pw.TableBorder.all(width: 0.8, color: PdfColors.grey400),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
            cellAlignment: pw.Alignment.centerLeft,
            
            // FIX: Styling for the TOTAL row (Last row)
            cellStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
              fontSize: 12,
            ),
            
            // Alignments for each column
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
          ),
          
          pw.SizedBox(height: 30),
          pw.Divider(),
          pw.Text("End of Report", style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
        ];
      },
    ),
  );

  // 5. Preview and Save/Print
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
    name: 'Summary_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
}

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Generate Monthly Bills")),
      body: Column(
        children: [
          _buildSelector(),
          const Divider(),
          // Scrollable table to see all houses in order
          Expanded(child: _buildPreviewTable()),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: selectedMonth,
              decoration: const InputDecoration(labelText: "Month"),
              items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i]))),
              onChanged: (v) => setState(() => selectedMonth = v!),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: selectedYear,
              decoration: const InputDecoration(labelText: "Year"),
              items: List.generate(3, (i) => DropdownMenuItem(value: 2025 + i, child: Text("${2025 + i}"))),
              onChanged: (v) => setState(() => selectedYear = v!),
            ),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.small(
            onPressed: loadPreview,
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

Widget _buildPreviewTable() {
  if (isLoading) return const Center(child: CircularProgressIndicator());
  if (previewData.isEmpty) return const Center(child: Text("No data. Click refresh to preview."));

  // 1. Calculate Totals
  double totalUnits = 0;
  double totalElec = 0;
  double totalWater = 0;
  double totalRent = 0;
  double totalAll = 0;

  for (var item in previewData) {
    totalUnits += double.tryParse(item['units_used']?.toString() ?? '0') ?? 0;
    totalElec += double.tryParse(item['electricity_cost']?.toString() ?? '0') ?? 0;
    totalWater += double.tryParse(item['water_charge']?.toString() ?? '0') ?? 0;
    totalRent += double.tryParse(item['rent_charge']?.toString() ?? '0') ?? 0;
    totalAll += double.tryParse(item['total_amount']?.toString() ?? '0') ?? 0;
  }

  // 2. Map existing rows
  List<DataRow> rows = previewData.map((item) {
    return DataRow(cells: [
      DataCell(Text(item['house_number']?.toString() ?? '-')),
      DataCell(Text(item['units_used']?.toString() ?? '0')),
      DataCell(Text(item['electricity_cost']?.toString() ?? '0')),
      DataCell(Text(item['water_charge']?.toString() ?? '0')),
      DataCell(Text(item['rent_charge']?.toString() ?? '0')),
      DataCell(Text(
        item['total_amount']?.toString() ?? '0',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
      )),
    ]);
  }).toList();

  // 3. Add the Summary (Total) Row
  rows.add(
    DataRow(
      color: WidgetStateProperty.all(Colors.blue.withValues(alpha: 0.1)), // Highlight total row
      cells: [
        const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(totalUnits.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(totalElec.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(totalWater.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(totalRent.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(
          "₹${totalAll.toStringAsFixed(0)}",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16),
        )),
      ],
    ),
  );

  return SingleChildScrollView(
    scrollDirection: Axis.vertical,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
        columns: const [
          DataColumn(label: Text('House', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Units', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Elec Cost', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Water', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Rent', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: rows,
      ),
    ),
  );
}

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: previewData.isEmpty || isLoading ? null : saveToDb,
              icon: const Icon(Icons.save_alt),
              label: const Text("CONFIRM & SAVE ALL"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700], 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)
              ),
            ),
          ),
          const SizedBox(width: 15),
         FloatingActionButton.extended(
          onPressed: generatePDF,
          label: const Text("Export PDF"),
          icon: const Icon(Icons.picture_as_pdf),
          backgroundColor: Colors.redAccent,
        ),
        ],
      ),
    );
  }
}

