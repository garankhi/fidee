import 'package:flutter/material.dart';
import '../login_design.dart';
import 'login_panel.dart';

class AuthWizardLayout extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onBack;

  const AuthWizardLayout({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoginColors.red,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = LoginMetrics.fromSize(constraints.biggest);

          return Stack(
            children: [
              Container(color: LoginColors.red),

              // Back Button & Logo
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: metrics.panelTop,
                child: Stack(
                  children: [
                    if (onBack != null)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 16,
                        left: 16,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: onBack,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    Positioned.fill(
                      child: Center(
                        child: Image.asset(
                          LoginAssets.logo,
                          width: 180,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // White Panel
              Positioned(
                top: metrics.panelTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: const LoginPanel(),
              ),

              // Form Content
              Positioned(
                top: metrics.formTop,
                left: metrics.formHorizontalPadding,
                right: metrics.formHorizontalPadding,
                bottom: 0,
                child: CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: 24,
                        ), // padding an toan
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: LoginTextStyles.title().copyWith(
                                fontSize: 28,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Expanded(child: child),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
