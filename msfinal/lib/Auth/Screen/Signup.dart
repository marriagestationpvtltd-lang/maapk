// introduce_yourself_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../SuignupModel/signup_model.dart';
import 'SignupScreen1.dart';

class IntroduceYourselfPage extends StatefulWidget {
  const IntroduceYourselfPage({Key? key}) : super(key: key);

  @override
  State<IntroduceYourselfPage> createState() => _IntroduceYourselfPageState();
}

class _IntroduceYourselfPageState extends State<IntroduceYourselfPage> {
  // chips options
  final List<String> _profileForOptions = [
    'Myself',
    'Son',
    'Daughter',
    'Sister',
    'Friend',
    'Relative',
    'Brother',
  ];
  String _selectedProfileFor = 'Myself';

  // gender radio
  String _gender = 'Male';

  // Validation
  bool _isValid = true;
  String _errorMessage = '';

  // mapping to numeric profileForId expected by API
  final Map<String, int> _profileForMap = {
    'Myself': 1,
    'Son': 2,
    'Daughter': 3,
    'Sister': 4,
    'Friend': 5,
    'Relative': 6,
    'Brother': 7,
  };

  @override
  void initState() {
    super.initState();
    // push initial defaults into provider after first frame so context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final model = context.read<SignupModel>();
      model.setProfileForId(_profileForMap[_selectedProfileFor] ?? 1);
      model.setGender(_gender);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Top-left back icon
            Positioned(
              left: 12,
              top: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Image(
                  image: AssetImage('assets/images/back.png'),
                  height: 30,
                  width: 30,
                ),
              ),
            ),

            // Page content with SingleChildScrollView
            Positioned.fill(
              top: 0,
              left: 10,
              right: 10,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 56, bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Illustration
                    Center(
                      child: SizedBox(
                        child: ClipRect(
                          child: Image.asset(
                            'assets/images/signup.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // fallback network image if asset not found
                              return Image.network(
                                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=1400&auto=format&fit=crop&ixlib=rb-4.0.3&s=9f7b2c0f2a6c7f0d5bfc4c57f7d8a8a5',
                                fit: BoxFit.cover,
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Title
                    Text(
                      'Introduce Yourself',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Fill out the rest of the details so people can\nknow all details about you.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // "This Profile Is For *"
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This Profile Is For $_selectedProfileFor',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // small underline accent
                          Container(
                            width: 40,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Wrap of choice chips
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _profileForOptions.map((option) {
                        final bool selected = _selectedProfileFor == option;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedProfileFor = option;
                              _autoSelectGender();
                              _validateForm();
                            });

                            // update provider: profileForId and gender
                            final model = context.read<SignupModel>();
                            model.setProfileForId(_profileForMap[option] ?? 1);

                            // after auto-select we might have updated _gender; set it to provider
                            if (_gender.isNotEmpty) model.setGender(_gender);
                          },
                          child: Container(
                            height: 35,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? const LinearGradient(
                                colors: [Color(0xFFE53935), Color(0xFFEC407A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                                  : null,
                              color: selected ? null : Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: selected ? Colors.transparent : Colors.grey.shade300,
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: selected ? Colors.redAccent.withOpacity(0.25) : Colors.grey.withOpacity(0.18),
                                  offset: const Offset(0, 4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Radio selection big cards
                    _buildBigRadioOption(
                      context,
                      title: 'Male',
                      icon: Icons.person,
                      value: 'Male',
                    ),
                    const SizedBox(height: 10),
                    _buildBigRadioOption(
                      context,
                      title: 'Female',
                      icon: Icons.person_outline,
                      value: 'Female',
                    ),
                    const SizedBox(height: 10),
                    _buildBigRadioOption(
                      context,
                      title: 'Other / Not To Say',
                      icon: Icons.not_interested,
                      value: 'Other',
                    ),

                    // Error message
                    if (!_isValid)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 80,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_validateForm()) {
                            // handle continue
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Selected: $_selectedProfileFor, Gender: $_gender'),
                              ),
                            );
                            Navigator.push(context, MaterialPageRoute(builder: (context) => YourDetailsPage()));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 6,
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shadowColor: Colors.black38,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE53935), Color(0xFFEC407A)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: Text(
                              'Continue',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // bottom indicator (just visual)
                    Container(
                      width: 140,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Auto-select gender based on profile selection
  void _autoSelectGender() {
    if (_selectedProfileFor == 'Son' || _selectedProfileFor == 'Brother') {
      _gender = 'Male';
    } else if (_selectedProfileFor == 'Daughter' || _selectedProfileFor == 'Sister') {
      _gender = 'Female';
    } else {
      // Clear gender selection for Myself, Friend, Relative
      _gender = ''; // or set to a default value like 'Not Selected'
    }
  }

  // Validate form
  bool _validateForm() {
    bool isValid = true;
    String errorMessage = '';

    // Check if gender is selected for profiles that require it
    if ((_selectedProfileFor == 'Son' || _selectedProfileFor == 'Brother') && _gender != 'Male') {
      isValid = false;
      errorMessage = 'Please select Male gender for $_selectedProfileFor';
    } else if ((_selectedProfileFor == 'Daughter' || _selectedProfileFor == 'Sister') && _gender != 'Female') {
      isValid = false;
      errorMessage = 'Please select Female gender for $_selectedProfileFor';
    } else if ((_selectedProfileFor == 'Myself' || _selectedProfileFor == 'Friend' || _selectedProfileFor == 'Relative') &&
        (_gender.isEmpty || _gender == '')) {
      isValid = false;
      errorMessage = 'Please select a gender for $_selectedProfileFor';
    }

    setState(() {
      _isValid = isValid;
      _errorMessage = errorMessage;
    });

    return isValid;
  }

  Widget _buildBigRadioOption(BuildContext context,
      {required String title, required IconData icon, required String value}) {
    final bool selected = _gender == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _gender = value;
          _validateForm();
        });
        // update provider gender
        context.read<SignupModel>().setGender(value);
      },
      child: Container(
        margin: const EdgeInsets.all(5),
        height: 60,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5C8C8).withOpacity(0.65),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.12),
              offset: const Offset(0, 6),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            // circular icon background
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFEC407A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.16),
                    offset: const Offset(0, 6),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Icon(icon, color: Colors.white),
              ),
            ),

            const SizedBox(width: 16),

            // title
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // radio circle
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.redAccent : Colors.black45,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent,
                  ),
                ),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}