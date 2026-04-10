import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MedicalRecordsScreen extends StatelessWidget {
  const MedicalRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text('Medical Records', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.userModel;
          return ListView(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildRecordCard(
                context,
                'Complete Blood Profile', 
                'Live Record • Verified', 
                'Blood Group: ${user?.bloodGroup ?? "Not set"}', 
                AppColors.success
              ),
              const SizedBox(height: 16),
              _buildRecordCard(
                context,
                'Last Blood Donation', 
                'Status Tracker', 
                user?.lastDonationDate != null ? 'Date: ${user!.lastDonationDate}' : 'No previous donations', 
                AppColors.primary
              ),
              const SizedBox(height: 16),
              _buildRecordCard(
                context,
                'Account Phone Record', 
                'Linked via API', 
                user?.phone ?? 'Not Linked', 
                AppColors.warning,
                icon: Icons.phone_android_rounded
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, String title, String subtitle, String status, Color statusColor, {IconData icon = Icons.picture_as_pdf_rounded}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
              IconButton(
                icon: Icon(icon, color: statusColor, size: 26),
                tooltip: 'Export PDF',
                onPressed: () => _generateAndShowPdf(context, title, subtitle, status),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(status, style: GoogleFonts.inter(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndShowPdf(BuildContext context, String title, String subtitle, String status) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text("BloodLink AI - Medical Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
              ),
              pw.SizedBox(height: 20),
              pw.Text("Record Details", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text("Report Type:     $title", style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.Text("Metadata:        $subtitle", style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 10),
              pw.Text("Current Status:  $status", style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 40),
              pw.Divider(),
              pw.Text("Auto-generated natively by BloodLink AI • ${DateTime.now().toString().split('.')[0]}", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );

    // This launches the built-in PDF viewer/printer/saver native to the device OS
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${title.replaceAll(' ', '_')}_Report.pdf',
    );
  }
}
