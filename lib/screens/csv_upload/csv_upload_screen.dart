import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state/app_state.dart';
import '../../models/transaction_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/theme/custom_animations.dart';

class CSVUploadScreen extends StatefulWidget {
  const CSVUploadScreen({super.key});

  @override
  State<CSVUploadScreen> createState() => _CSVUploadScreenState();
}

class _CSVUploadScreenState extends State<CSVUploadScreen> with TickerProviderStateMixin {
  String? _selectedFileName;
  bool _isProcessing = false;
  bool _isSuccess = false;
  int _currentStepIndex = 0;
  int _parsedCount = 0;

  late AnimationController _bounceController;
  late AnimationController _checkmarkController;
  
  final List<String> _processingSteps = [
    "Reading file...",
    "Detecting bank format...",
    "Parsing transactions...",
    "Removing sensitive data...",
    "Categorising with AI...",
  ];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _checkmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _checkmarkController.dispose();
    super.dispose();
  }

  void _startSimulation() {
    setState(() {
      _isProcessing = true;
      _isSuccess = false;
      _currentStepIndex = 0;
      _parsedCount = 0;
    });

    // Step 1: Reading file
    Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _currentStepIndex = 1);
      HapticFeedback.lightImpact();

      // Step 2: Detecting bank format
      Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() => _currentStepIndex = 2);
        HapticFeedback.lightImpact();
        
        // Live counting transactions parsed
        Timer.periodic(const Duration(milliseconds: 30), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          if (_parsedCount < 142) {
            setState(() {
              _parsedCount += 6;
              if (_parsedCount > 142) _parsedCount = 142;
            });
          } else {
            timer.cancel();
            // Step 3: Removing sensitive data
            setState(() => _currentStepIndex = 3);
            HapticFeedback.lightImpact();

            Timer(const Duration(milliseconds: 800), () {
              if (!mounted) return;
              setState(() => _currentStepIndex = 4);
              HapticFeedback.lightImpact();

              // Step 4: Categorising with AI
              Timer(const Duration(milliseconds: 1200), () async {
                if (!mounted) return;
                
                // Add simulated transactions to SQLite DB
                await _seedParsedTransactions();

                setState(() {
                  _isProcessing = false;
                  _isSuccess = true;
                });
                _checkmarkController.forward(from: 0.0);
                HapticFeedback.mediumImpact();
              });
            });
          }
        });
      });
    });
  }

  Future<void> _seedParsedTransactions() async {
    final state = AppState.instance;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Insert mock parsed transactions
    final mockTxs = [
      TransactionModel(
        amount: "1250.00",
        merchant: "Amazon Shopping",
        type: "DEBIT",
        paymentMode: "Card",
        bank: "HDFC Bank",
        sender: "CSV",
        confidence: 95,
        timestamp: now - 3600000 * 2,
        message: "CSV Parsed statement row Amazon.in",
      ),
      TransactionModel(
        amount: "340.00",
        merchant: "Swiggy Food delivery",
        type: "DEBIT",
        paymentMode: "UPI",
        bank: "HDFC Bank",
        sender: "CSV",
        confidence: 98,
        timestamp: now - 3600000 * 8,
        message: "CSV Parsed statement row Swiggy Food",
      ),
      TransactionModel(
        amount: "199.00",
        merchant: "Netflix subscription",
        type: "DEBIT",
        paymentMode: "Card",
        bank: "HDFC Bank",
        sender: "CSV",
        confidence: 100,
        timestamp: now - 3600000 * 24,
        message: "CSV Parsed statement row Netflix Subscription",
      ),
      TransactionModel(
        amount: "15000.00",
        merchant: "Monthly Stipend/Allowance",
        type: "CREDIT",
        paymentMode: "Bank Transfer",
        bank: "HDFC Bank",
        sender: "CSV",
        confidence: 90,
        timestamp: now - 3600000 * 48,
        message: "CSV Parsed statement row Credit Inflow",
      ),
    ];

    await state.addTransactions(mockTxs);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = isDark ? Colors.white : AppColors.lightTextPrimary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Upload Statement",
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textTheme,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            
            if (!_isProcessing && !_isSuccess) ...[
              // Upload state
              _buildUploadZone(isDark),
              
              if (_selectedFileName != null) ...[
                const SizedBox(height: 20),
                _buildAutoDetectionBanner(isDark),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _startSimulation,
                    child: Text(
                      "Import Statement Now",
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ] else if (_isProcessing) ...[
              // Processing state
              _buildProcessingState(isDark),
            ] else ...[
              // Success state
              _buildSuccessState(isDark),
            ],
            
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // Upload zone with custom dashed borders
  Widget _buildUploadZone(bool isDark) {
    final borderColor = isDark ? AppColors.successGreen : AppColors.lightGradient[0];
    final labelColor = isDark ? Colors.white70 : AppColors.lightTextPrimary;

    return SpringScaleButton(
      scaleDownFactor: 0.98,
      onTap: () {
        setState(() {
          _selectedFileName = "hdfc_may2026_statement.csv";
        });
        HapticFeedback.lightImpact();
      },
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: borderColor,
          strokeWidth: 1.5,
          gap: 8.0,
          borderRadius: 24,
        ),
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161616) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bouncing cloud icon
              if (_selectedFileName == null)
                AnimatedBuilder(
                  animation: _bounceController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -6 * _bounceController.value),
                      child: Icon(
                        Icons.cloud_upload_outlined,
                        size: 48,
                        color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                      ),
                    );
                  },
                )
              else
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 48,
                  color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                ),
                
              const SizedBox(height: 16),
              Text(
                _selectedFileName ?? "Tap to upload or drag your CSV",
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 6),
              
              if (_selectedFileName == null) ...[
                Text(
                  "Supports HDFC, SBI, ICICI, Axis Bank",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Choose from Google Drive",
                  style: TextStyle(
                    color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ] else ...[
                const Text(
                  "Ready to parse statement structure",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Bank Auto-Detection Banner
  Widget _buildAutoDetectionBanner(bool isDark) {
    final isHDFC = _selectedFileName!.toLowerCase().contains("hdfc");
    final bannerBg = isHDFC 
        ? (isDark ? const Color(0xFF0F1B12) : const Color(0xFFE8F5E9)) 
        : (isDark ? const Color(0xFF2A1C0E) : const Color(0xFFFFF3E0));
    final bannerText = isHDFC 
        ? "✓ Detected: HDFC Bank Statement" 
        : "⚠ Unknown format. We'll try our best.";
    final textColor = isHDFC ? AppColors.successGreen : Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            isHDFC ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
            color: textColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            bannerText,
            style: GoogleFonts.outfit(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // Processing steps timeline
  Widget _buildProcessingState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
              ),
            ),
          ),
          const SizedBox(height: 28),
          
          Column(
            children: List.generate(_processingSteps.length, (idx) {
              final stepLabel = _processingSteps[idx];
              final isCompleted = _currentStepIndex > idx;
              final isCurrent = _currentStepIndex == idx;

              Color rowColor = Colors.grey;
              if (isCompleted) {
                rowColor = AppColors.successGreen;
              } else if (isCurrent) {
                rowColor = isDark ? Colors.white : Colors.black;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? AppColors.successGreen
                            : (isCurrent 
                                ? (isDark ? AppColors.accentNeon.withOpacity(0.2) : AppColors.lightGradient[0].withOpacity(0.12))
                                : Colors.transparent),
                        border: Border.all(
                          color: isCompleted ? Colors.transparent : Colors.grey,
                          width: 1,
                        ),
                      ),
                      child: isCompleted
                          ? const Center(child: Icon(Icons.check, color: Colors.black, size: 12))
                          : (isCurrent 
                              ? Center(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                                    ),
                                  ),
                                )
                              : null),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      idx == 2 && isCurrent
                          ? "Parsing $_parsedCount transactions..."
                          : stepLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: rowColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Success State
  Widget _buildSuccessState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: [
          // Animated checkmark circle
          SizedBox(
            width: 72,
            height: 72,
            child: AnimatedBuilder(
              animation: _checkmarkController,
              builder: (context, child) {
                return CustomPaint(
                  painter: CheckmarkPainter(progress: _checkmarkController.value),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            "142 transactions imported! 🎉",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          Text(
            "Date range: 01 May 2026 - 24 May 2026\nBank: HDFC Statement\nCategories detected: Food, Transport, Shopping",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                // Navigate to transactions list
                AppState.instance.setTab(1);
                Navigator.pop(context);
              },
              child: Text(
                "View Transactions →",
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Dashed border painter
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    // Draw dashed path
    double distance = 0.0;
    bool draw = true;
    for (final PathMetric metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final double len = draw ? gap : gap * 0.8;
        if (draw) {
          canvas.drawPath(
            metric.extractPath(distance, (distance + len).clamp(0.0, metric.length)),
            paint,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.gap != gap;
  }
}

// Custom checkmark drawing painter
class CheckmarkPainter extends CustomPainter {
  final double progress;

  CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    // Circle background paint
    final circlePaint = Paint()
      ..color = AppColors.successGreen.withOpacity(0.15)
      ..style = PaintingStyle.fill;
      
    // Circle stroke paint
    final borderPaint = Paint()
      ..color = AppColors.successGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
      
    canvas.drawCircle(center, radius, circlePaint);
    canvas.drawCircle(center, radius, borderPaint);

    // Draw checkmark path based on progress animation
    final checkPaint = Paint()
      ..color = AppColors.successGreen
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    final path = Path();
    final startOffset = Offset(size.width * 0.3, size.height * 0.5);
    final midOffset = Offset(size.width * 0.45, size.height * 0.65);
    final endOffset = Offset(size.width * 0.7, size.height * 0.35);

    path.moveTo(startOffset.dx, startOffset.dy);
    
    if (progress > 0) {
      final double totalLength1 = (midOffset - startOffset).distance;
      final double totalLength2 = (endOffset - midOffset).distance;
      
      final double progress1 = (progress / 0.5).clamp(0.0, 1.0);
      final double progress2 = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);

      final currentMid = Offset(
        startOffset.dx + (midOffset.dx - startOffset.dx) * progress1,
        startOffset.dy + (midOffset.dy - startOffset.dy) * progress1,
      );
      
      path.lineTo(currentMid.dx, currentMid.dy);
      
      if (progress1 >= 1.0 && progress2 > 0) {
        final currentEnd = Offset(
          midOffset.dx + (endOffset.dx - midOffset.dx) * progress2,
          midOffset.dy + (endOffset.dy - midOffset.dy) * progress2,
        );
        path.lineTo(currentEnd.dx, currentEnd.dy);
      }
    }
    
    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
