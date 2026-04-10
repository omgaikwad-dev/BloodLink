import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../ai/ai_chat_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Text('Help & Support', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatScreen())),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA855F7)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Support Agent', style: GoogleFonts.outfit(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w800)),
                        Text('Available 24/7 for your queries', style: GoogleFonts.inter(color: Colors.white70)),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text('Frequently Asked Questions', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 16),
          _buildFaqItem('How do I donate blood?', 'You can accept an emergency request from the map, or book an appointment at the nearest Blood Bank via the dashboard.'),
          _buildFaqItem('Is my data secure?', 'Yes! BloodLink uses end-to-end encryption for all personal and medical data.'),
          _buildFaqItem('How does the Wearable integration work?', 'Go to AI Tools > Wearable. Tap Connect and link your Smartwatch via Bluetooth to sync live vitals.'),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Theme(
      data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(question, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(answer, style: GoogleFonts.inter(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}
