/// Registration screen — Crimson Ember theme with premium step-based design
/// Optimized: added same unified login_logo, fast staggered animations
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/blood_group_selector.dart';
import '../../providers/auth_provider.dart';

// ─── Register Theme Colors (Crimson Ember) ────────────────────────
class _RegColors {
  static const Color bg = Color(0xFF0F0508);
  static const Color accent1 = Color(0xFFE11D48); // Rose
  static const Color accent2 = Color(0xFFDC2626); // Crimson
  static const Color accent3 = Color(0xFFF59E0B); // Amber
  static const Color glow = Color(0xFFFF4757); // Bright rose
  static const Color cardBg = Color(0xFF1A0A10);
  static const Color inputBg = Color(0xFF1C0E14);
  static const Color borderColor = Color(0xFF3D1825);
  static const Color success = Color(0xFF22C55E);
}

// ─── Cached text styles ──────────────────────────────────────────
class _Styles {
  static final outfitBold30 = GoogleFonts.outfit(
      fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5);
  static final outfitBold20 = GoogleFonts.outfit(
      fontWeight: FontWeight.w700, fontSize: 20);
  static final outfitBold17 = GoogleFonts.outfit(
      fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white);
  static final outfitBold16 = GoogleFonts.outfit(
      fontSize: 16, fontWeight: FontWeight.w700);
  static final inter15w500 = GoogleFonts.inter(
      color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500);
  static final inter14w500 = GoogleFonts.inter(
      color: Colors.white30, fontSize: 14, fontWeight: FontWeight.w500);
  static final inter14wSub = GoogleFonts.inter(
      color: Colors.white38, fontSize: 14, height: 1.5);
  static final inter14w600 = GoogleFonts.inter(
      fontSize: 14, fontWeight: FontWeight.w600);
  static final inter15w700 = GoogleFonts.inter(
      fontSize: 15, fontWeight: FontWeight.w700);
  static final inter15w600 = GoogleFonts.inter(
      fontWeight: FontWeight.w600, fontSize: 15);
  static final inter13w600 = GoogleFonts.inter(fontWeight: FontWeight.w600);
  static final inter12Muted = GoogleFonts.inter(
      fontSize: 12, color: Colors.white38);
  static final inter12Summary = GoogleFonts.inter(
      color: Colors.white38, fontSize: 12);
  static final inter14w600Sum = GoogleFonts.inter(
      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600);
  static final inter10w500 = GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500);
  static final inter10w700 = GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700);
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedRole = AppConstants.roleDonor;
  String _selectedBloodGroup = 'O+';
  bool _obscurePassword = true;
  int _currentStep = 0;

  bool get _isDonor => _selectedRole == AppConstants.roleDonor;

  String _savedName = '';
  String _savedEmail = '';
  String _savedPhone = '';
  String _savedPassword = '';

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final Map<String, bool> _focusStates = {};

  final List<Map<String, dynamic>> _roles = [
    {
      'value': AppConstants.roleDonor,
      'label': 'Donor',
      'icon': Icons.volunteer_activism_rounded,
      'color': const Color(0xFF22C55E),
      'gradient': [const Color(0xFF22C55E), const Color(0xFF16A34A)],
      'desc': 'Donate blood & save lives',
      'emoji': '💚',
    },
    {
      'value': AppConstants.roleHospital,
      'label': 'Hospital',
      'icon': Icons.local_hospital_rounded,
      'color': const Color(0xFF3B82F6),
      'gradient': [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
      'desc': 'Request blood for patients',
      'emoji': '🏥',
    },
    {
      'value': AppConstants.roleBloodBank,
      'label': 'Blood Bank',
      'icon': Icons.bloodtype_rounded,
      'color': _RegColors.accent2,
      'gradient': [_RegColors.accent2, const Color(0xFFB91C1C)],
      'desc': 'Manage blood inventory',
      'emoji': '🩸',
    },
  ];

  @override
  void initState() {
    super.initState();
    for (final n in [_nameFocus, _emailFocus, _phoneFocus, _passwordFocus]) {
      n.addListener(() =>
          setState(() => _focusStates[n.hashCode.toString()] = n.hasFocus));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool _isFocused(FocusNode n) => _focusStates[n.hashCode.toString()] ?? false;

  void _saveFormValues() {
    _savedName = _nameController.text.trim();
    _savedEmail = _emailController.text.trim();
    _savedPhone = _phoneController.text.trim();
    _savedPassword = _passwordController.text;
  }

  void _restoreFormValues() {
    _nameController.text = _savedName;
    _emailController.text = _savedEmail;
    _phoneController.text = _savedPhone;
    _passwordController.text = _savedPassword;
  }

  void _goToStep(int step) {
    if (_currentStep == 1) _saveFormValues();
    setState(() => _currentStep = step);
    if (step == 1) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _restoreFormValues());
    }
  }

  Future<void> _handleRegister() async {
    if (_savedName.isEmpty ||
        _savedEmail.isEmpty ||
        _savedPassword.isEmpty ||
        !_savedEmail.contains('@') ||
        _savedPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please fill all required fields correctly.',
            style: _Styles.inter13w600),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.only(bottom: 80, left: 24, right: 24),
      ));
      return;
    }
    final auth = context.read<AuthProvider>();
    final nav = Navigator.of(context);
    final scaffold = ScaffoldMessenger.of(context);
    final success = await auth.signUpWithEmail(
      email: _savedEmail,
      password: _savedPassword,
      name: _savedName,
      role: _selectedRole,
      bloodGroup: _isDonor ? _selectedBloodGroup : '',
      phone: _savedPhone,
    );
    if (!mounted) return;
    if (success) {
      nav.pushReplacementNamed('/home');
    } else if (auth.error != null) {
      scaffold.showSnackBar(SnackBar(
        content: Text(auth.error!, style: _Styles.inter15w600),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.only(bottom: 80, left: 24, right: 24),
        duration: const Duration(seconds: 4),
      ));
      _goToStep(1);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _RegColors.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Create Account', style: _Styles.outfitBold20),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _RegColors.accent1.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: _RegColors.accent1.withValues(alpha: 0.15)),
            ),
            child: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          ),
          onPressed: () {
            if (_currentStep > 0) {
              _goToStep(_currentStep - 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Stack(
        children: [
          // ── Static crimson background (no continuous animation) ──
          const _StaticCrimsonBackground(),

          SafeArea(
            child: Column(
              children: [
                // Unified logo dynamically added at top for cohesive branding
                _buildUnifiedLogo()
                  .animate()
                  .fade(duration: 500.ms)
                  .scale(begin: const Offset(0.9, 0.9)),

                // Step indicator
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  child: _buildStepIndicator()
                      .animate()
                      .fade(duration: 500.ms, delay: 100.ms)
                      .slideY(begin: 0.2),
                ),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.15, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: SingleChildScrollView(
                      key: ValueKey<int>(_currentStep),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_currentStep == 0) _buildRoleSelection(),
                          if (_currentStep == 1) _buildProfileForm(),
                          if (_currentStep == 2 && _isDonor)
                            _buildBloodGroupAndConfirm(),
                          if (_currentStep == 2 && !_isDonor) _buildConfirmOnly(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),

                _buildBottomBar()
                    .animate()
                    .fade(duration: 600.ms, delay: 300.ms)
                    .slideY(begin: 0.3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Unified Logo exactly matching Login ─────────────────────────
  Widget _buildUnifiedLogo() {
    return Container(
      width: 70, // Slightly smaller than login screen so it fits form well
      height: 70,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _RegColors.glow.withValues(alpha: 0.35),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _RegColors.glow.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: Image.asset(
            'assets/images/bloodlink_modern_icon.png', // Uses exact unified modern icon
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  // ─── Bottom Action Bar ──────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _RegColors.bg.withValues(alpha: 0),
            _RegColors.bg,
          ],
          stops: const [0.0, 0.4],
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _RegColors.accent1.withValues(alpha: 0.2)),
                ),
                child: OutlinedButton(
                  onPressed: () => _goToStep(_currentStep - 1),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    foregroundColor: Colors.white70,
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_back_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text('Back', style: _Styles.inter14w600),
                      ]),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final isLast = _currentStep >= 2;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: isLast
                          ? [_RegColors.success, const Color(0xFF16A34A)]
                          : [_RegColors.accent1, _RegColors.accent2],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isLast ? _RegColors.success : _RegColors.accent1)
                            .withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: isLast && auth.isLoading
                        ? null
                        : () {
                            if (isLast) {
                              _handleRegister();
                            } else {
                              if (_currentStep == 1) {
                                if (!_formKey.currentState!.validate()) return;
                                _saveFormValues();
                              }
                              _goToStep(_currentStep + 1);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isLast && auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isLast)
                                const Icon(Icons.check_circle_rounded, size: 20),
                              if (!isLast)
                                Text('Continue', style: _Styles.inter15w700),
                              if (isLast) const SizedBox(width: 8),
                              if (isLast)
                                Text('Create Account', style: _Styles.inter15w700),
                              if (!isLast) const SizedBox(width: 6),
                              if (!isLast)
                                const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step Indicator ─────────────────────────────────────────────
  Widget _buildStepIndicator() {
    final labels = _isDonor
        ? ['Role', 'Profile', 'Blood & Confirm']
        : ['Role', 'Profile', 'Confirm'];
    final icons = [
      Icons.badge_rounded,
      Icons.person_rounded,
      Icons.verified_rounded
    ];
    return Row(
      children: List.generate(3, (i) {
        final active = i <= _currentStep;
        final current = i == _currentStep;
        final done = i < _currentStep;
        return Expanded(
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 3.5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: active
                    ? const LinearGradient(
                        colors: [_RegColors.accent1, _RegColors.accent2])
                    : null,
                color: active ? null : Colors.white.withValues(alpha: 0.06),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: _RegColors.accent1.withValues(alpha: 0.3),
                            blurRadius: 6)
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 7),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                done ? Icons.check_circle_rounded : icons[i],
                size: 12,
                color: done
                    ? _RegColors.success.withValues(alpha: 0.8)
                    : current
                        ? _RegColors.accent1
                        : Colors.white24,
              ),
              const SizedBox(width: 4),
              Text(labels[i],
                  style: current
                      ? _Styles.inter10w700.copyWith(color: _RegColors.accent1)
                      : _Styles.inter10w500.copyWith(
                          color: done ? Colors.white54 : Colors.white24)),
            ]),
          ]),
        );
      }),
    );
  }

  // ─── Step 0: Role Selection ─────────────────────────────────────
  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [_RegColors.glow, _RegColors.accent3],
          ).createShader(b),
          child: Text('I am a...', style: _Styles.outfitBold30),
        ),
        const SizedBox(height: 8),
        Text('Choose your role to join BloodLink AI',
            style: _Styles.inter14wSub),
        const SizedBox(height: 28),
        ..._roles.asMap().entries.map((entry) {
          final int index = entry.key;
          final role = entry.value;
          final sel = _selectedRole == role['value'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedRole = role['value']),
                borderRadius: BorderRadius.circular(18),
                splashColor: (role['color'] as Color).withValues(alpha: 0.08),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: sel
                        ? LinearGradient(colors: [
                            (role['color'] as Color).withValues(alpha: 0.12),
                            (role['color'] as Color).withValues(alpha: 0.03),
                          ])
                        : LinearGradient(colors: [
                            _RegColors.cardBg.withValues(alpha: 0.6),
                            _RegColors.cardBg.withValues(alpha: 0.3),
                          ]),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: sel
                          ? (role['color'] as Color).withValues(alpha: 0.45)
                          : _RegColors.borderColor.withValues(alpha: 0.4),
                      width: sel ? 1.5 : 1,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                                color: (role['color'] as Color)
                                    .withValues(alpha: 0.12),
                                blurRadius: 20,
                                spreadRadius: -2),
                          ]
                        : null,
                  ),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: sel
                            ? LinearGradient(
                                colors: role['gradient'] as List<Color>)
                            : null,
                        color: sel
                            ? null
                            : (role['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                    color: (role['color'] as Color)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3))
                              ]
                            : null,
                      ),
                      child: Icon(role['icon'] as IconData,
                          color:
                              sel ? Colors.white : role['color'] as Color,
                          size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(role['label'] as String,
                                style: _Styles.outfitBold16.copyWith(
                                    color: sel
                                        ? Colors.white
                                        : Colors.white60)),
                            const SizedBox(width: 5),
                            Text(role['emoji'] as String,
                                style: const TextStyle(fontSize: 15)),
                          ]),
                          const SizedBox(height: 3),
                          Text(role['desc'] as String,
                              style: _Styles.inter12Muted),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: sel
                            ? LinearGradient(
                                colors: role['gradient'] as List<Color>)
                            : null,
                        border: Border.all(
                            color: sel ? Colors.transparent : Colors.white12,
                            width: 2),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                    color: (role['color'] as Color)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 6)
                              ]
                            : null,
                      ),
                      child: sel
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14)
                          : null,
                    ),
                  ]),
                ),
              ),
            ),
          )
          .animate()
          .fade(duration: 400.ms, delay: (100 * index).ms)
          .slideX(begin: 0.1);
        }),
      ],
    );
  }

  // ─── Step 1: Profile Form ───────────────────────────────────────
  Widget _buildProfileForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Colors.white, Color(0xFFFFCDD2)],
            ).createShader(b),
            child: Text('Your Profile', style: _Styles.outfitBold30),
          )
              .animate()
              .fade(duration: 400.ms)
              .slideX(begin: 0.1),
          const SizedBox(height: 8),
          Text('Fill in your details to join the network',
              style: _Styles.inter14wSub)
              .animate()
              .fade(duration: 400.ms, delay: 50.ms),
          const SizedBox(height: 28),

          _buildField(
            controller: _nameController,
            focusNode: _nameFocus,
            isFocused: _isFocused(_nameFocus),
            label: _selectedRole == AppConstants.roleHospital
                ? 'Hospital Name'
                : _selectedRole == AppConstants.roleBloodBank
                    ? 'Blood Bank Name'
                    : 'Full Name',
            icon: Icons.person_rounded,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Name is required' : null,
          )
              .animate()
              .fade(duration: 400.ms, delay: 100.ms)
              .slideY(begin: 0.1),
          const SizedBox(height: 14),

          _buildField(
            controller: _emailController,
            focusNode: _emailFocus,
            isFocused: _isFocused(_emailFocus),
            label: 'Email Address',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!v.contains('@')) return 'Invalid email';
              return null;
            },
          )
              .animate()
              .fade(duration: 400.ms, delay: 150.ms)
              .slideY(begin: 0.1),
          const SizedBox(height: 14),

          _buildField(
            controller: _phoneController,
            focusNode: _phoneFocus,
            isFocused: _isFocused(_phoneFocus),
            label: 'Phone Number',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          )
              .animate()
              .fade(duration: 400.ms, delay: 200.ms)
              .slideY(begin: 0.1),
          const SizedBox(height: 14),

          _buildField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            isFocused: _isFocused(_passwordFocus),
            label: 'Create Password',
            icon: Icons.lock_rounded,
            obscureText: _obscurePassword,
            isPassword: true,
            onToggle: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v.length < 6) return 'Min 6 characters';
              return null;
            },
          )
              .animate()
              .fade(duration: 400.ms, delay: 250.ms)
              .slideY(begin: 0.1),
        ],
      ),
    );
  }

  // ─── Step 2 ─────────────────────────────────────────────────────
  Widget _buildBloodGroupAndConfirm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
              colors: [_RegColors.glow, _RegColors.accent3])
              .createShader(b),
          child: Text('Blood Group', style: _Styles.outfitBold30),
        )
            .animate()
            .fade(duration: 400.ms)
            .slideX(begin: 0.1),
        const SizedBox(height: 8),
        Text('Select your blood group to save matching lives',
            style: _Styles.inter14wSub)
            .animate()
            .fade(duration: 400.ms, delay: 50.ms),
        const SizedBox(height: 24),
        BloodGroupSelector(
          selectedGroup: _selectedBloodGroup,
          onSelected: (g) => setState(() => _selectedBloodGroup = g),
        )
            .animate()
            .fade(duration: 400.ms, delay: 100.ms)
            .slideY(begin: 0.1),
        const SizedBox(height: 28),
        _buildSummary()
            .animate()
            .fade(duration: 400.ms, delay: 200.ms)
            .slideY(begin: 0.1),
      ],
    );
  }

  Widget _buildConfirmOnly() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
              colors: [Colors.white, Color(0xFFFFCDD2)])
              .createShader(b),
          child: Text('Confirm Details', style: _Styles.outfitBold30),
        )
            .animate()
            .fade(duration: 400.ms)
            .slideX(begin: 0.1),
        const SizedBox(height: 8),
        Text('Review your information before creating your account',
            style: _Styles.inter14wSub)
            .animate()
            .fade(duration: 400.ms, delay: 50.ms),
        const SizedBox(height: 24),
        _buildSummary()
            .animate()
            .fade(duration: 400.ms, delay: 150.ms)
            .slideY(begin: 0.1),
      ],
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          _RegColors.accent1.withValues(alpha: 0.08),
          _RegColors.cardBg.withValues(alpha: 0.6),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _RegColors.accent1.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: _RegColors.accent1.withValues(alpha: 0.06),
              blurRadius: 25,
              spreadRadius: -2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  _RegColors.accent1.withValues(alpha: 0.2),
                  _RegColors.accent1.withValues(alpha: 0.08),
                ]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_rounded,
                  color: _RegColors.accent1, size: 18),
            ),
            const SizedBox(width: 12),
            Text('Account Summary', style: _Styles.outfitBold17),
          ]),
          const SizedBox(height: 18),
          _infoRow(Icons.person_rounded, 'Name', _savedName),
          _infoRow(Icons.email_rounded, 'Email', _savedEmail),
          _infoRow(Icons.badge_rounded, 'Role',
              _selectedRole.replaceAll('_', ' ').toUpperCase()),
          if (_isDonor)
            _infoRow(Icons.bloodtype_rounded, 'Blood', _selectedBloodGroup),
          if (_savedPhone.isNotEmpty)
            _infoRow(Icons.phone_rounded, 'Phone', _savedPhone),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8)),
          child:
              Icon(icon, color: Colors.white.withValues(alpha: 0.45), size: 15),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: Text(label, style: _Styles.inter12Summary),
        ),
        Expanded(
          child: Text(value.isEmpty ? '—' : value,
              style: _Styles.inter14w600Sum),
        ),
      ]),
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
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final accent = _RegColors.accent1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isFocused
            ? [
                BoxShadow(
                    color: accent.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: -3),
              ]
            : [],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: _Styles.inter15w500,
        cursorColor: accent,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: _Styles.inter14w500,
          floatingLabelStyle: GoogleFonts.inter(
              color: isFocused ? accent : Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w700),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Icon(icon,
                color: isFocused ? accent : Colors.white24, size: 22),
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
              isFocused ? accent.withValues(alpha: 0.05) : _RegColors.inputBg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: _RegColors.borderColor.withValues(alpha: 0.5))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: accent.withValues(alpha: 0.6), width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: AppColors.error.withValues(alpha: 0.5), width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        ),
        validator: validator,
      ),
    );
  }
}

/// Static crimson background — painted once
class _StaticCrimsonBackground extends StatelessWidget {
  const _StaticCrimsonBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return RepaintBoundary(
      child: Stack(children: [
        // Crimson glow top-right
        Positioned(
          top: -90,
          right: -40,
          child: _glow(_RegColors.accent1, 380, 0.14),
        ),
        // Amber glow bottom-left
        Positioned(
          bottom: -100,
          left: -80,
          child: _glow(_RegColors.accent3, 320, 0.09),
        ),
        // Deep red accent mid
        Positioned(
          top: size.height * 0.5,
          right: size.width * 0.35,
          child: _glow(_RegColors.accent2, 220, 0.07),
        ),
        // Static diamond grid
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _DiamondGridPainter(opacity: 0.02),
            ),
          ),
        ),
      ]),
    );
  }

  static Widget _glow(Color c, double s, double o) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            c.withValues(alpha: o),
            c.withValues(alpha: o * 0.4),
            c.withValues(alpha: 0),
          ], stops: const [0.0, 0.4, 1.0]),
        ),
      );
}

/// Static diamond grid (painted once, no offset animation)
class _DiamondGridPainter extends CustomPainter {
  final double opacity;
  _DiamondGridPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 45.0;
    const diamondSize = 12.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        final path = Path()
          ..moveTo(x, y - diamondSize)
          ..lineTo(x + diamondSize, y)
          ..lineTo(x, y + diamondSize)
          ..lineTo(x - diamondSize, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DiamondGridPainter old) => old.opacity != opacity;
}
