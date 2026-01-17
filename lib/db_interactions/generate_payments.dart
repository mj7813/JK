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
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  String formatAmount(num value) {
  final formatter = NumberFormat('#,##,###', 'en_IN');
  return formatter.format(value);
}

  // ================= PREVIEW =================

  Future<void> loadPreview() async {
    setState(() => isLoading = true);
    try {
      final data =
          await _service.getGeneratedBillData(selectedMonth, selectedYear);
      setState(() => previewData = data);
    } catch (e) {
      _showSnack("Error loading preview: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ================= SAVE =================

  Future<void> saveToDb() async {
    if (previewData.isEmpty) return;
    setState(() => isLoading = true);

    try {
      final sanitized = previewData.map((item) {
        final rent =
            double.tryParse(item['rent_charge']?.toString() ?? '0') ?? 0;

        if (rent == 0) {
          return {
            ...item,
            'electricity_cost': 0,
            'water_charge': 0,
            'total_amount': 0,
          };
        }
        return item;
      }).toList();

      await _service.saveBillsToDatabase(
        sanitized,
        selectedMonth,
        selectedYear,
      );

      _showSnack("Bills saved successfully");
    } catch (e) {
      _showSnack("Save failed: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  


  // ================= SUMMARY PDF =================

  Future<void> generatePDF() async {
    if (previewData.isEmpty) {
      _showSnack("No data to generate PDF");
      return;
    }

    final pdf = pw.Document();

    double totalUnits = 0;
    double totalElec = 0;
    double totalWater = 0;
    double totalRent = 0;
    double totalAll = 0;

    for (var item in previewData) {
      final rent =
          double.tryParse(item['rent_charge']?.toString() ?? '0') ?? 0;

      totalUnits += double.tryParse(item['units_used']?.toString() ?? '0') ?? 0;
      totalElec +=
          double.tryParse(item['electricity_cost']?.toString() ?? '0') ?? 0;
      totalWater +=
          double.tryParse(item['water_charge']?.toString() ?? '0') ?? 0;
      totalRent += rent;

      if (rent > 0) {
        totalAll +=
            double.tryParse(item['total_amount']?.toString() ?? '0') ?? 0;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("Monthly Billing Summary",
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.Text(DateFormat('MMM yyyy').format(DateTime.now())),
            ],
          ),
          pw.SizedBox(height: 20),

          pw.Table(
            border:
                pw.TableBorder.all(width: 0.8, color: PdfColors.grey400),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.blueGrey900),
                children: [
                  _pdfHeader('House'),
                  _pdfHeader('Units'),
                  _pdfHeader('Elec'),
                  _pdfHeader('Water'),
                  _pdfHeader('Rent'),
                  _pdfHeader('Total'),
                ],
              ),

              ...previewData.map((item) {
                final rent = double.tryParse(
                        item['rent_charge']?.toString() ?? '0') ??
                    0;
                final isZero = rent == 0;

                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: isZero
                          ? PdfColors.grey200
                          : PdfColors.white),
                  children: [
                    _pdfCell(item['house_number'].toString(), isZero),
                    _pdfCell(item['units_used'].toString(), isZero,
                        alignRight: true),
                    _pdfCell(item['electricity_cost'].toString(), isZero,
                        alignRight: true),
                    _pdfCell(item['water_charge'].toString(), isZero,
                        alignRight: true),
                    _pdfCell(
                      formatAmount(
                        double.tryParse(item['rent_charge']?.toString() ?? '0') ?? 0,
                      ),
                      isZero,
                      alignRight: true,
                    ),
                    _pdfCell(
                      isZero
                          ? '0'
                          : formatAmount(
                              double.tryParse(item['total_amount']?.toString() ?? '0') ?? 0,
                            ),
                      isZero,
                      bold: true,
                      alignRight: true,
                    ),
                  ],
                );
              }),

              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                children: [
                  _pdfTotal('TOTAL'),
                  _pdfTotal(formatAmount(totalUnits), alignRight: true),
                  _pdfTotal(formatAmount(totalElec), alignRight: true),
                  _pdfTotal(formatAmount(totalWater), alignRight: true),
                  _pdfTotal(formatAmount(totalRent), alignRight: true), 
                  _pdfTotal(
                    "Rs. ${formatAmount(totalAll)}",
                    alignRight: true,
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),
          pw.Text("Grey rows indicate vacant houses",
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey)),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Summary_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // ================= SLIP PDF (NO RENT=0) =================

  Future<void> generateSlipPDF() async {
  if (previewData.isEmpty) {
    _showSnack("No data to generate slip PDF");
    return;
  }

  final pdf = pw.Document();

  // 🔹 1. Get EB-enabled houses from DB
  final Set<String> ebHouses =
      await _service.getEBEnabledHouseNumbers();

  // 🔹 2. Get outstanding (previous months only)
  final Map<String, double> outstandingMap =
      await _service.fetchOutstandingExcludingCurrentMonth(
        currentMonth: selectedMonth,
        currentYear: selectedYear,
      );

  // 🔹 3. Filter preview data → ONLY EB houses
  final slipData = previewData.where((item) {
    final houseNo = item['house_number']?.toString();
    final rent =
        double.tryParse(item['rent_charge']?.toString() ?? '0') ?? 0;

    return houseNo != null && ebHouses.contains(houseNo) && rent > 0;
  }).toList();

  if (slipData.isEmpty) {
    _showSnack("No EB enabled houses found");
    return;
  }

  // 🔹 4. Build PDF
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(8),
      build: (context) => [
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slipData.map((item) {
            final houseNo = item['house_number'].toString();
            final outstanding = outstandingMap[houseNo] ?? 0;

            return _billSlipCard(item, outstanding);
          }).toList(),
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
    name: 'EB_Bill_Slips_${DateTime.now().millisecondsSinceEpoch}.pdf',
  );
}




  Widget _buildPreviewTable() {
  if (isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  if (previewData.isEmpty) {
    return const Center(child: Text("No data. Click refresh to preview."));
  }

  double totalUnits = 0;
  double totalElec = 0;
  double totalWater = 0;
  double totalRent = 0;
  double totalAll = 0;

  for (var item in previewData) {
    final rent =
        double.tryParse(item['rent_charge']?.toString() ?? '0') ?? 0;

    totalUnits +=
        double.tryParse(item['units_used']?.toString() ?? '0') ?? 0;
    totalElec +=
        double.tryParse(item['electricity_cost']?.toString() ?? '0') ?? 0;
    totalWater +=
        double.tryParse(item['water_charge']?.toString() ?? '0') ?? 0;
    totalRent += rent;

    if (rent > 0) {
      totalAll +=
          double.tryParse(item['total_amount']?.toString() ?? '0') ?? 0;
    }
  }

  final rows = previewData.map((item) {
    final rent =
        double.tryParse(item['rent_charge']?.toString() ?? '0') ?? 0;
    final isZeroRent = rent == 0;

    final textStyle = TextStyle(
      color: isZeroRent ? Colors.grey : Colors.black,
      fontWeight: isZeroRent ? FontWeight.normal : FontWeight.w500,
    );

    return DataRow(
      color: isZeroRent
          ? WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.15))
          : null,
      cells: [
        DataCell(Text(item['house_number'].toString(), style: textStyle)),
        DataCell(Text(item['units_used'].toString(), style: textStyle)),
        DataCell(Text(item['electricity_cost'].toString(), style: textStyle)),
        DataCell(Text(item['water_charge'].toString(), style: textStyle)),
        DataCell(Text(item['rent_charge'].toString(), style: textStyle)),
        DataCell(
          Text(
            isZeroRent ? '0' : item['total_amount'].toString(),
            style: textStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }).toList();

  // TOTAL ROW
  rows.add(
    DataRow(
      color: WidgetStateProperty.all(
        Colors.blue.withValues(alpha: 0.1),
      ),
      cells: [
        const DataCell(
            Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(totalUnits.toStringAsFixed(0),
            style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(totalElec.toStringAsFixed(0),
            style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(totalWater.toStringAsFixed(0),
            style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(totalRent.toStringAsFixed(0),
            style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(
          Text(
            "₹${totalAll.toStringAsFixed(0)}",
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                fontSize: 16),
          ),
        ),
      ],
    ),
  );

  return SingleChildScrollView(
    scrollDirection: Axis.vertical,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowColor:
            WidgetStateProperty.all(Colors.grey.shade200),
        columns: const [
          DataColumn(label: Text('House', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Units', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Elec', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Water', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Rent', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: rows,
      ),
    ),
  );
}

  // ================= UI =================

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Generate Monthly Bills")),
      body: Column(
        children: [
          _buildSelector(),
          const Divider(),
          Expanded(child: _buildPreviewTable()),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: selectedMonth,
              decoration: const InputDecoration(labelText: "Month"),
              items: List.generate(
                12,
                (i) =>
                    DropdownMenuItem(value: i + 1, child: Text(months[i])),
              ),
              onChanged: (v) => setState(() => selectedMonth = v!),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: selectedYear,
              decoration: const InputDecoration(labelText: "Year"),
              items: List.generate(
                3,
                (i) => DropdownMenuItem(
                    value: 2025 + i, child: Text("${2025 + i}")),
              ),
              onChanged: (v) => setState(() => selectedYear = v!),
            ),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.small(
            heroTag: "refresh_fab",
            onPressed: loadPreview,
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  // ================= ACTION BUTTONS =================

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // SAVE BUTTON
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: previewData.isEmpty || isLoading ? null : saveToDb,
              icon: const Icon(Icons.save, size: 18),
              label: const Text("SAVE"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // SUMMARY PDF
          Expanded(
            child: OutlinedButton(
              onPressed: previewData.isEmpty ? null : generatePDF,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Icon(
                Icons.picture_as_pdf,
                color: Colors.redAccent,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // SLIP PDF
          Expanded(
            child: OutlinedButton(
              onPressed: previewData.isEmpty ? null : generateSlipPDF,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Colors.deepPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ================= PDF HELPERS =================

  pw.Widget _pdfHeader(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text,
            style: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _pdfCell(String text, bool grey,
          {bool bold = false, bool alignRight = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Align(
          alignment:
              alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 11,
                  color:
                      grey ? PdfColors.grey600 : PdfColors.black,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      );

  pw.Widget _pdfTotal(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Align(
        alignment:
            alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 11, // 🔽 slightly smaller
          ),
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
        ),
      ),
    );
  }

  pw.Widget _billSlipCard(
  Map<String, dynamic> item,
  double outstanding,
) {
  return pw.Container(
    width: 185,
    height : 250, // 🔑 auto-fits ~3 columns on A4
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(
        color: PdfColors.grey900,
        width: 0.4, // 🔑 narrow border
      ),
      borderRadius: pw.BorderRadius.circular(2),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // HOUSE NO (CENTER)
        pw.Center(
          child: pw.Text(
            "${item['house_number']}",
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),

        pw.Divider(thickness: 0.4),

        _slipRow("Current", item['current_reading']),
        _slipRow("Previous", item['previous_reading']),
        _slipRow("Total Units", item['units_used']),

        pw.Divider(thickness: 0.3),

        _slipRow(
          "EB Charge",
          formatAmount(item['electricity_cost'] ?? 0),
        ),
        _slipRow(
          "Water",
          formatAmount(item['water_charge'] ?? 0),
        ),
        _slipRow(
          "Rent",
          formatAmount(item['rent_charge'] ?? 0),
        ),

        pw.Divider(thickness: 0.4),

        // CURRENT MONTH TOTAL
        _boldRow(
          "TOTAL",
          "Rs. ${formatAmount(item['total_amount'] ?? 0)}",
        ),

        // PREVIOUS MONTHS OUTSTANDING
        if (outstanding > 0)
          _boldRow(
            "Outstanding",
            "Rs. ${formatAmount(outstanding)}",
            color: PdfColors.grey600,
          ),
      ],
    ),
  );
}




  pw.Widget _slipRow(String label, dynamic value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 14)),
        pw.Text(
          value?.toString() ?? '0',
          style: pw.TextStyle(fontSize: 14),
        ),
      ],
    ),
  );
}

pw.Widget _boldRow(
  String label,
  String value, {
  PdfColor color = PdfColors.black,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}
}
