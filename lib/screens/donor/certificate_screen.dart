import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';

class CertificateScreen extends StatefulWidget {
  const CertificateScreen({super.key});

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  bool _isGenerating = false;

  Future<void> _downloadCertificate(UserModel user) async {
    setState(() => _isGenerating = true);
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(40),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.red900, width: 4),
              ),
              child: pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('CERTIFICATE OF APPRECIATION',
                        style: pw.TextStyle(
                            fontSize: 32,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900,
                            letterSpacing: 2)),
                    pw.SizedBox(height: 30),
                    pw.Text('This certificate is proudly presented to',
                        style: const pw.TextStyle(fontSize: 18)),
                    pw.SizedBox(height: 20),
                    pw.Text(user.name.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 48,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black)),
                    pw.SizedBox(height: 10),
                    pw.Text('🏆 ${user.rank} Donor (${user.creditPoints} PTS)',
                        style: pw.TextStyle(
                            fontSize: 18, color: PdfColors.amber800)),
                    pw.SizedBox(height: 30),
                    pw.Text(
                      'For your outstanding commitment and selflessness in saving lives through blood donation. The hospitals and patients are forever grateful.',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 16),
                    ),
                    pw.SizedBox(height: 50),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          children: [
                            pw.Container(width: 100, height: 1, color: PdfColors.black),
                            pw.SizedBox(height: 8),
                            pw.Text('Date Awarded',
                                style: const pw.TextStyle(fontSize: 14)),
                            pw.Text(DateTime.now().toLocal().toString().split(' ')[0],
                                style: pw.TextStyle(
                                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Container(width: 100, height: 1, color: PdfColors.black),
                            pw.SizedBox(height: 8),
                            pw.Text('Hospitals Network',
                                style: const pw.TextStyle(fontSize: 14)),
                            pw.Text('BloodLink AI',
                                style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.red900)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'BloodLink_Certificate_${user.name}.pdf',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Pdf ready! Opened sharing tool.'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to generate PDF: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) {
      return const Scaffold(backgroundColor: AppColors.bgDark);
    }

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const Text('Certificate of Appreciation'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 70),
                    const SizedBox(height: 16),
                    Text(
                      'CERTIFICATE OF APPRECIATION',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'This certificate is proudly presented to',
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.name.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '🏆 ${user.rank} Donor (${user.creditPoints} PTS)',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'For your outstanding commitment and selflessness in saving lives through blood donation. The hospitals and patients are forever grateful.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Container(width: 80, height: 2, color: AppColors.textSecondary),
                            const SizedBox(height: 8),
                            Text('Date Awarded', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                            Text(DateTime.now().toLocal().toString().split(' ')[0], style: GoogleFonts.inter(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Container(
                          width: 80, 
                          height: 80, 
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
                          ),
                          child: const Center(
                            child: Icon(Icons.health_and_safety_rounded, color: AppColors.primary, size: 40),
                          ),
                        ),
                        Column(
                          children: [
                            Container(width: 80, height: 2, color: AppColors.textSecondary),
                            const SizedBox(height: 8),
                            Text('Hospitals Network', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                            Text('BloodLink AI', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fade(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : () => _downloadCertificate(user),
                icon: _isGenerating 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.download_rounded),
                label: Text(_isGenerating ? 'Generating PDF...' : 'Download PDF', style: const TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ).animate().fade(delay: 400.ms).slideY(begin: 0.2),
            ],
          ),
        ),
      ),
    );
  }
}
