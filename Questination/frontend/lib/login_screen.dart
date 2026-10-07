import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color oceanBlue = Color(0xFF1684A7);
  static const Color tealGreen = Color(0xFF1B796D);
  static const Color sunnyYellow = Color(0xFFFAF179);
  static const Color cream = Color(0xFFFDFDEE);
  static const Color loginButtonFill = Color(0xFF07545A);
  static const Color loginButtonBorder = Color(0xFFE8B94F);
  static const Color loginButtonText = Color(0xFFFFF2C7);
  static const Color loginButtonShadow = Color(0xFF043D43);
  static const Color createAccountFill = Color(0xFFB97832);
  static const Color createAccountBorder = Color(0xFFFFF0B8);
  static const Color createAccountText = Color(0xFFFFF8DC);
  static const Color createAccountShadow = Color(0xFF70401F);

  bool _isSignUp = false;
  bool _isLoading = false;
  String _selectedRole = 'tourist';

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        (_isSignUp && (username.isEmpty || phone.isEmpty))) {
      _showSnackBar('PLEASE FILL IN ALL REQUIRED FIELDS');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        await ApiService.register(
          username: username,
          email: email,
          password: password,
          phone: phone,
          role: _selectedRole,
        );
      } else {
        await ApiService.login(email, password);
      }

      if (mounted) {
        widget.onLoginSuccess();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: oceanBlue,
        content: Text(
          message.toUpperCase(),
          style: GoogleFonts.pressStart2p(fontSize: 8, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/loginbg2.png', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.10)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 340,
                      child: Center(
                        child: OverflowBox(
                          maxWidth: MediaQuery.sizeOf(context).width,
                          child: Image.asset(
                            'assets/questination_heading.png',
                            width: MediaQuery.sizeOf(context).width,
                            height: 280,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    if (_isSignUp) ...[
                      _buildRetroTextField(
                        controller: _usernameController,
                        label: 'USERNAME',
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 14),
                      _buildRetroTextField(
                        controller: _phoneController,
                        label: 'PHONE',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ROLE',
                            style: GoogleFonts.pressStart2p(
                              fontSize: 7,
                              color: loginButtonFill,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: cream,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: loginButtonBorder,
                                width: 2,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedRole,
                                isExpanded: true,
                                iconEnabledColor: loginButtonFill,
                                style: GoogleFonts.pressStart2p(
                                  fontSize: 9,
                                  color: loginButtonFill,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'tourist',
                                    child: Text('TOURIST'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'seller',
                                    child: Text('SELLER'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedRole = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildRetroTextField(
                      controller: _emailController,
                      label: 'EMAIL',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    _buildRetroTextField(
                      controller: _passwordController,
                      label: 'PASSWORD',
                      icon: Icons.lock,
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: loginButtonShadow,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: loginButtonFill,
                            disabledBackgroundColor: loginButtonFill,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(
                                color: loginButtonBorder,
                                width: 2,
                              ),
                            ),
                          ),
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: loginButtonText,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'LOG IN',
                                  style: GoogleFonts.pressStart2p(
                                    fontSize: 10,
                                    color: loginButtonText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: createAccountShadow,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: createAccountFill,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(
                                color: createAccountBorder,
                                width: 2,
                              ),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _isSignUp = true;
                            });
                          },
                          child: Text(
                            'CREATE NEW ACCOUNT',
                            style: GoogleFonts.pressStart2p(
                              fontSize: 8,
                              color: createAccountText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetroTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.pressStart2p(
            fontSize: 7,
            color: loginButtonFill,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: cream,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: loginButtonBorder, width: 2),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            cursorColor: loginButtonFill,
            style: GoogleFonts.pressStart2p(
              fontSize: 9,
              color: loginButtonFill,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: loginButtonFill, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
