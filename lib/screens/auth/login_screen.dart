/// Login screen — Oceanic Blue theme with premium glassmorphism design
/// Optimized: single logo, staggered entrance animations, static background
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

// ─── Login Theme Colors (Oceanic Blue) ───────────────────────────
class _LoginColors {
  static const Color bg = Color(0xFF020B18);
  static const Color accent1 = Color(0xFF00BCD4); // Cyan
  static const Color accent2 = Color(0xFF0D47A1); // Deep blue
  static const Color accent3 = Color(0xFF7C4DFF); // Violet
  static const Color glow = Color(0xFF00E5FF); // Bright cyan
  static const Color cardBg = Color(0xFF0A1628);
  static const Color inputBg = Color(0xFF0C1D35);
  static const Color borderColor = Color(0xFF1A3A5C);
}

// ─── Cached text styles to avoid repeated GoogleFonts lookups ─────
class _Styles {
  static final outfitBold42 = GoogleFonts.outfit(
      fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.5);
  static final outfitBold26 = GoogleFonts.outfit(
      fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white);
  static final outfitBold18 = GoogleFonts.outfit(
      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold);
  static final inter15w500 = GoogleFonts.inter(
      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500);
  static final inter14w500 = GoogleFonts.inter(
      color: Colors.white38, fontSize: 14, fontWeight: FontWeight.w500);
  static final inter13w600 = GoogleFonts.inter(fontWeight: FontWeight.w600);
  static final inter15w700 = GoogleFonts.inter(
      fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3);
  static final inter14w600 = GoogleFonts.inter(
      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70);
  static final inter13w700 = GoogleFonts.inter(
      fontSize: 13, fontWeight: FontWeight.w700);
  static final inter11Secure = GoogleFonts.inter(
      fontSize: 11, letterSpacing: 2.5,
      color: _LoginColors.glow.withValues(alpha: 0.9), fontWeight: FontWeight.w700);
  static final inter12w500 = GoogleFonts.inter(
      fontSize: 12, color: Colors.white30, fontWeight: FontWeight.w500);
  static final interWhite = GoogleFonts.inter(color: Colors.white);
  static final interWhite24 = GoogleFonts.inter(color: Colors.white24);
  static final interBoldWhite = GoogleFonts.inter(
      fontWeight: FontWeight.bold, color: Colors.white);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _emailFocused = false;
  bool _passwordFocused = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(
        () => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(
        () => setState(() => _passwordFocused = _passwordFocus.hasFocus));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ─── Handlers ───────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final nav = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);
    final success = await auth.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      nav.pushReplacementNamed('/home');
    } else if (auth.error != null) {
      _showError(scaffold, auth.error!);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final auth = context.read<AuthProvider>();
    final nav = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);
    final success = await auth.signInWithGoogle();
    if (!mounted) return;
    if (success) {
      nav.pushReplacementNamed('/home');
    } else if (auth.error != null) {
      if (auth.error == 'firebase_google_new_user') {
        scaffold.showSnackBar(SnackBar(
          content: Text('Please create an account first.',
              style: _Styles.inter13w600),
          backgroundColor: _LoginColors.accent1,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(20),
        ));
        auth.clearError();
        nav.pushNamed('/register');
      } else {
        _showError(scaffold, auth.error!);
      }
    }
  }

  void _showError(ScaffoldMessengerState scaffold, String error) {
    scaffold.showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(error, style: _Styles.inter13w600)),
      ]),
      backgroundColor: AppColors.error.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(20),
    ));
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final resetCtrl = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _LoginColors.cardBg,
        elevation: 24,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: _LoginColors.accent1.withValues(alpha: 0.2))),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _LoginColors.accent1.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.lock_reset_rounded, color: _LoginColors.accent1),
          ),
          const SizedBox(width: 14),
          Text('Reset Password', style: _Styles.outfitBold18),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Enter your email to receive a reset link.',
              style: GoogleFonts.inter(
                  color: Colors.white60, fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),
          TextField(
            controller: resetCtrl,
            keyboardType: TextInputType.emailAddress,
            style: _Styles.interWhite,
            decoration: InputDecoration(
              hintText: 'email@example.com',
              hintStyle: _Styles.interWhite24,
              prefixIcon: const Icon(Icons.email_rounded, color: Colors.white38),
              filled: true,
              fillColor: _LoginColors.inputBg,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: _LoginColors.accent1.withValues(alpha: 0.5))),
            ),
          ),
        ]),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 16, top: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: Colors.white38, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetCtrl.text.trim();
              if (email.isEmpty || !email.contains('@')) return;
              final sm = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                if (mounted) {
                  sm.showSnackBar(SnackBar(
                    content: Text('Reset link sent!', style: _Styles.interWhite),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    margin: const EdgeInsets.all(20),
                  ));
                }
              } catch (_) {
                if (mounted) _showError(sm, 'Failed to send reset email');
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _LoginColors.accent1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
            child: Text('Send Link', style: _Styles.interBoldWhite),
          ),
        ],
      )
      .animate()
      .fade(duration: 400.ms)
      .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutCubic),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LoginColors.bg,
      body: Stack(
        children: [
          // ── Static oceanic background (no continuous animation) ──
          const _StaticBackground(),

          // ── Main content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Logo + Branding ──
                    _buildBranding()
                        .animate()
                        .fade(duration: 600.ms)
                        .slideY(begin: -0.2, curve: Curves.easeOutCubic),
                    const SizedBox(height: 44),

                    // ── Form Card ──
                    _buildFormCard()
                        .animate()
                        .fade(duration: 600.ms, delay: 200.ms)
                        .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutCubic),
                    const SizedBox(height: 28),

                    // ── Divider ──
                    _buildDivider()
                        .animate()
                        .fade(duration: 500.ms, delay: 400.ms),
                    const SizedBox(height: 28),

                    // ── Google button ──
                    _buildGoogleButton()
                        .animate()
                        .fade(duration: 500.ms, delay: 500.ms)
                        .slideY(begin: 0.2, curve: Curves.easeOutCubic),
                    const SizedBox(height: 32),

                    // ── Register link ──
                    _buildRegisterLink()
                        .animate()
                        .fade(duration: 500.ms, delay: 600.ms),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Center(
      child: Column(children: [
        // The unified logo
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _LoginColors.glow.withValues(alpha: 0.35),
                blurRadius: 40,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: _LoginColors.accent3.withValues(alpha: 0.2),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _LoginColors.glow.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: Image.asset(
                'assets/images/bloodlink_modern_icon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

        const SizedBox(height: 26),

        // App name — oceanic gradient
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [_LoginColors.glow, Color(0xFF40C4FF), _LoginColors.accent3],
          ).createShader(b),
          child: Text('BloodLink AI', style: _Styles.outfitBold42),
        ),

        const SizedBox(height: 10),

        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: _LoginColors.glow.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _LoginColors.glow.withValues(alpha: 0.15)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _LoginColors.glow,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: _LoginColors.glow.withValues(alpha: 0.6),
                      blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('SECURE SIGN IN', style: _Styles.inter11Secure),
          ]),
        ),
      ]),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _LoginColors.accent1.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.03),
            _LoginColors.accent2.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
            color: _LoginColors.accent1.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: _LoginColors.accent2.withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Welcome Back', style: _Styles.outfitBold26),
            const SizedBox(height: 6),
            Text(
              'Sign in to access your emergency network.',
              style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.45), height: 1.5),
            ),
            const SizedBox(height: 30),

            // Email
            _buildField(
              controller: _emailController,
              focusNode: _emailFocus,
              isFocused: _emailFocused,
              label: 'Email Address',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            _buildField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              isFocused: _passwordFocused,
              label: 'Password',
              icon: Icons.fingerprint_rounded,
              obscureText: _obscurePassword,
              isPassword: true,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 6) return 'Min 6 chars';
                return null;
              },
            ),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: TextButton(
                  onPressed: () => _showForgotPasswordDialog(context),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: _LoginColors.accent1,
                  ),
                  child: Text('Forgot Password?', style: _Styles.inter13w700),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Login button — cyan gradient
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: auth.isLoading
                          ? [
                              _LoginColors.accent1.withValues(alpha: 0.5),
                              _LoginColors.accent2.withValues(alpha: 0.5),
                            ]
                          : [_LoginColors.accent1, _LoginColors.accent2],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _LoginColors.accent1.withValues(
                            alpha: auth.isLoading ? 0.1 : 0.4),
                        blurRadius: auth.isLoading ? 8 : 25,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shield_rounded, size: 20),
                              const SizedBox(width: 10),
                              Text('Sign In Securely',
                                  style: _Styles.inter15w700),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      Expanded(
          child: Container(
              height: 1,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                Colors.transparent,
                _LoginColors.accent1.withValues(alpha: 0.2),
              ])))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text('or', style: _Styles.inter12w500),
      ),
      Expanded(
          child: Container(
              height: 1,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                _LoginColors.accent1.withValues(alpha: 0.2),
                Colors.transparent,
              ])))),
    ]);
  }

  Widget _buildGoogleButton() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _LoginColors.accent1.withValues(alpha: 0.12)),
            color: _LoginColors.cardBg,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: auth.isLoading ? null : _handleGoogleSignIn,
              borderRadius: BorderRadius.circular(16),
              splashColor: _LoginColors.accent1.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('G',
                            style: GoogleFonts.inter(
                                color: const Color(0xFF4285F4),
                                fontWeight: FontWeight.w900,
                                fontSize: 15)),
                      ),
                      const SizedBox(width: 12),
                      Text('Continue with Google', style: _Styles.inter14w600),
                    ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegisterLink() {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).pushNamed('/register'),
        child: RichText(
          text: TextSpan(
              text: "New here? ",
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
              children: [
                TextSpan(
                  text: 'Create Account',
                  style: GoogleFonts.inter(
                    color: _LoginColors.glow,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationColor: _LoginColors.glow.withValues(alpha: 0.4),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final accentColor = _LoginColors.accent1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isFocused
            ? [
                BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 18,
                    spreadRadius: -3),
              ]
            : [],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: _Styles.inter15w500,
        cursorColor: accentColor,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: _Styles.inter14w500,
          floatingLabelStyle: GoogleFonts.inter(
              color: isFocused ? accentColor : Colors.white60,
              fontSize: 14,
              fontWeight: FontWeight.w700),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Icon(icon,
                color: isFocused ? accentColor : Colors.white30, size: 22),
          ),
          suffixIcon: isPassword
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: Icon(
                        obscureText
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white30,
                        size: 22),
                    onPressed: onToggle,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                )
              : null,
          filled: true,
          fillColor:
              isFocused ? accentColor.withValues(alpha: 0.06) : _LoginColors.inputBg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                  color: _LoginColors.borderColor.withValues(alpha: 0.5))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: accentColor.withValues(alpha: 0.7), width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: AppColors.error.withValues(alpha: 0.5), width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.error, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        ),
        validator: validator,
      ),
    );
  }
}

/// Static background — painted once, no continuous animation
class _StaticBackground extends StatelessWidget {
  const _StaticBackground();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(children: [
        // Cyan glow top-right
        Positioned(
          top: -100,
          right: -30,
          child: _glow(const Color(0xFF00E5FF), 400, 0.15),
        ),
        // Deep blue glow bottom-left
        Positioned(
          bottom: -100,
          left: -100,
          child: _glow(const Color(0xFF0D47A1), 360, 0.12),
        ),
        // Violet dot center-right
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          left: MediaQuery.of(context).size.width * 0.55,
          child: _glow(const Color(0xFF7C4DFF), 200, 0.08),
        ),
        // Subtle static hex grid
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _HexGridPainter(opacity: 0.025),
            ),
          ),
        ),
      ]),
    );
  }

  static Widget _glow(Color color, double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.4),
            color.withValues(alpha: 0),
          ], stops: const [0.0, 0.4, 1.0]),
        ),
      );
}

/// Static hexagonal grid (painted once, no offset animation)
class _HexGridPainter extends CustomPainter {
  final double opacity;
  _HexGridPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const s = 50.0;
    final h = s * math.sqrt(3) / 2;

    for (double row = -1; row < size.height / h + 1; row++) {
      for (double col = -1; col < size.width / (s * 1.5) + 1; col++) {
        final cx = col * s * 1.5;
        final cy = row * h * 2 + (col.toInt().isOdd ? h : 0);
        _drawHex(canvas, Offset(cx, cy), s * 0.4, paint);
      }
    }
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * math.pi / 180;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexGridPainter old) => old.opacity != opacity;
}
