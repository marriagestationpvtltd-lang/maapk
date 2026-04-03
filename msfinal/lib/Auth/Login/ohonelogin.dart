import 'package:flutter/material.dart';
import 'package:ms2026/Auth/Login/LoginMain.dart';
import 'package:ms2026/Auth/Screen/Signup.dart';
import '../../ReUsable/terms_dialog.dart';

class MobileLoginScreen extends StatelessWidget {
  const MobileLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Login And Find A Partner For Yourself.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.pink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Mobile Number Field
            TextFormField(
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(25))
                ),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),

            // OTP Field
            TextFormField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'OTP',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(25))
                ),
                prefixIcon: Icon(Icons.sms),
              ),
            ),
            const SizedBox(height: 8),

            // Send OTP Button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text('Send OTP'),
              ),
            ),
            const SizedBox(height: 20),

            // Login Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFF90E18), // #F90E18
                      Color(0xFFC10810), // Slightly darker red
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFF90E18).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      // Your login logic here
                    },
                    child: Center(
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Divider with "or"
            Row(
              children: [
                Expanded(
                  child: Divider(color: Colors.grey.shade300),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'or',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                Expanded(
                  child: Divider(color: Colors.grey.shade300),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Login With Email
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreens(),));
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email),
                    SizedBox(width: 10,),
                    const Text('Login With Email'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Register Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account?"),
                TextButton(
                  onPressed: () async {
                    final accepted = await TermsConditionsBottomSheet.show(context);
                    if (!context.mounted) return;
                    if (accepted) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const IntroduceYourselfPage()));
                    }
                  },
                  child: const Text('Register'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}