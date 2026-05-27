import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../core/state/app_state.dart';
import '../../models/transaction_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/custom_animations.dart';
import '../../services/api_service.dart';

class CSVUploadScreen extends StatefulWidget {
  const CSVUploadScreen({super.key});

  @override
  State<CSVUploadScreen> createState() => _CSVUploadScreenState();
}

class _CSVUploadScreenState extends State<CSVUploadScreen> with TickerProviderStateMixin {
  String? _selectedFileName;
  PlatformFile? _selectedFile;
  String _selectedBankName = "HDFC Bank";
  final TextEditingController _passwordController = TextEditingController();
  bool _isPdf = false;
  bool _isObscurePassword = true;
  String? _errorMessage;

  bool _isProcessing = false;
  bool _isSuccess = false;
  int _currentStepIndex = 0;
  int _parsedCount = 0;
  int _actualParsedCount = 0;

  int _newTransactionsCount = 0;
  int _duplicatesSkippedCount = 0;
  int _totalTransactionsCount = 0;
  int _nearDuplicatesWarnedCount = 0;
  bool _isDuplicateUpload = false;

  late AnimationController _bounceController;
  late AnimationController _checkmarkController;
  
  final List<String> _processingSteps = [
    "Reading file...",
    "Detecting bank format...",
    "Parsing transactions...",
    "Checking for duplicates...",
    "Removing sensitive data...",
    "Categorising with AI...",
  ];

  final List<String> _supportedBanks = [
    "HDFC Bank",
    "SBI",
    "ICICI",
    "Axis Bank"
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
    _passwordController.dispose();
    super.dispose();
  }

  void _detectBankName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains("hdfc")) {
      setState(() => _selectedBankName = "HDFC Bank");
    } else if (lower.contains("sbi")) {
      setState(() => _selectedBankName = "SBI");
    } else if (lower.contains("icici")) {
      setState(() => _selectedBankName = "ICICI");
    } else if (lower.contains("axis")) {
      setState(() => _selectedBankName = "Axis Bank");
    }
  }

  void _resetState() {
    setState(() {
      _selectedFileName = null;
      _selectedFile = null;
      _passwordController.clear();
      _errorMessage = null;
      _isProcessing = false;
      _isSuccess = false;
      _isDuplicateUpload = false;
      _currentStepIndex = 0;
      _parsedCount = 0;
      _actualParsedCount = 0;
      _newTransactionsCount = 0;
      _duplicatesSkippedCount = 0;
      _totalTransactionsCount = 0;
      _nearDuplicatesWarnedCount = 0;
    });
  }

  void _uploadAndParseStatement() async {
    if (_selectedFile == null) return;

    setState(() {
      _isProcessing = true;
      _isSuccess = false;
      _isDuplicateUpload = false;
      _errorMessage = null;
      _currentStepIndex = 0;
      _parsedCount = 0;
      _actualParsedCount = 0;
      _nearDuplicatesWarnedCount = 0;
    });

    // Step 1: Reading file (simulate brief progress for high quality feel)
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _currentStepIndex = 1);
    HapticFeedback.lightImpact();

    // Step 2: Detecting bank format & starting API call
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _currentStepIndex = 2);
    HapticFeedback.lightImpact();

    // Read bytes
    Uint8List fileBytes;
    try {
      if (_selectedFile!.bytes != null) {
        fileBytes = _selectedFile!.bytes!;
      } else {
        fileBytes = await File(_selectedFile!.path!).readAsBytes();
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = "Failed to read selected file: $e";
      });
      HapticFeedback.heavyImpact();
      return;
    }

    // Call API in background
    bool apiCallFinished = false;
    dynamic apiResult;
    String? apiError;

    final existingFingerprints = AppState.instance.transactions.map((tx) => tx.fingerprint).toList();

    ApiService.uploadStatement(
      fileBytes: fileBytes,
      fileName: _selectedFile!.name,
      bankName: _selectedBankName,
      password: _isPdf && _passwordController.text.isNotEmpty ? _passwordController.text : null,
      existingFingerprints: existingFingerprints,
    ).then((result) {
      apiResult = result;
      apiCallFinished = true;
    }).catchError((error) {
      apiError = error.toString();
      apiCallFinished = true;
    });

    // Progress counter simulation (incrementing counts until API replies or is close to done)
    int simulatedParsedCount = 0;
    Timer.periodic(const Duration(milliseconds: 40), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (simulatedParsedCount < 95 && !apiCallFinished) {
        setState(() {
          simulatedParsedCount += 2;
          _parsedCount = simulatedParsedCount;
        });
      } else if (apiCallFinished) {
        timer.cancel();

        if (apiError != null) {
          setState(() {
            _isProcessing = false;
            _errorMessage = apiError!.replaceAll('Exception: ', '');
          });
          HapticFeedback.heavyImpact();
          return;
        }

        // Successfully received backend data
        final String status = apiResult['status'] ?? 'success';
        _duplicatesSkippedCount = apiResult['duplicates_skipped'] ?? 0;
        _newTransactionsCount = apiResult['new_transactions'] ?? 0;
        _totalTransactionsCount = apiResult['total_transactions'] ?? 0;
        _nearDuplicatesWarnedCount = apiResult['near_duplicates_warned'] ?? 0;

        if (status == 'duplicate_upload') {
          setState(() {
            _isProcessing = false;
            _isSuccess = false;
            _isDuplicateUpload = true;
            _errorMessage = null;
          });
          HapticFeedback.heavyImpact();
          try {
            HapticFeedback.vibrate();
          } catch (_) {}
          return;
        }

        final List<dynamic> transactionsData = apiResult['data'] ?? [];
        _actualParsedCount = transactionsData.length;
        
        if (_actualParsedCount == 0 && _newTransactionsCount == 0) {
          if (_duplicatesSkippedCount > 0) {
            setState(() {
              _isProcessing = false;
              _isSuccess = false;
              _isDuplicateUpload = true;
              _errorMessage = null;
            });
            HapticFeedback.heavyImpact();
            try {
              HapticFeedback.vibrate();
            } catch (_) {}
          } else {
            setState(() {
              _isProcessing = false;
              _errorMessage = "No transactions found in this statement. Please verify the bank and password.";
            });
            HapticFeedback.heavyImpact();
          }
          return;
        }

        // Update parsed count dynamically to match actual count
        setState(() {
          _parsedCount = _actualParsedCount;
        });

        // Step 3: Checking for duplicates
        setState(() => _currentStepIndex = 3);
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;

        // Step 4: Removing sensitive data
        setState(() => _currentStepIndex = 4);
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;
        // Step 5: Categorising with AI
        setState(() => _currentStepIndex = 5);
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 1000));

        if (!mounted) return;

        // Map backend transactions to local TransactionModel objects
        final List<TransactionModel> txnsToInsert = [];
        final now = DateTime.now().millisecondsSinceEpoch;

        for (var item in transactionsData) {
          final double amount = double.tryParse(item['amount']?.toString() ?? '') ?? 0.0;
          final String rawType = item['transaction_type']?.toString().toLowerCase() ?? 'debit';
          final String rawDesc = item['merchant']?.toString() ?? 'Statement transaction';
          final String paymentMode = item['paymentMode']?.toString() ?? 'Bank Transfer';
          final int timestamp = item['timestamp'] is int ? item['timestamp'] : int.tryParse(item['timestamp']?.toString() ?? '') ?? now;
          final String txId = item['id']?.toString() ?? AppState.instance.strUUID();
          final String fingerprint = item['fingerprint']?.toString() ?? '';
          final String bankVal = item['bank']?.toString() ?? _selectedBankName;
          final String senderVal = item['sender']?.toString() ?? 'CSV';
          final int confidenceVal = item['confidence'] is int ? item['confidence'] : int.tryParse(item['confidence']?.toString() ?? '') ?? 95;
          final String messageVal = item['message']?.toString() ?? rawDesc;

          final tx = TransactionModel(
            id: txId,
            fingerprint: fingerprint.isNotEmpty ? fingerprint : "statement_${_selectedBankName.toLowerCase()}_${amount.toStringAsFixed(2)}_${timestamp}_${rawDesc.replaceAll(' ', '_')}",
            amount: amount.toStringAsFixed(2),
            merchant: rawDesc,
            category: item['category']?.toString() ?? AppState.instance.getCategory(rawDesc),
            type: rawType == 'credit' ? 'credit' : 'debit',
            paymentMode: paymentMode,
            bank: bankVal,
            sender: senderVal,
            confidence: confidenceVal,
            autoAdded: 1,
            timestamp: timestamp,
            message: messageVal,
          );
          txnsToInsert.add(tx);
        }

        // Add to local database
        await AppState.instance.addTransactions(txnsToInsert);

        // Success state
        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _parsedCount = _actualParsedCount;
        });
        _checkmarkController.forward(from: 0.0);
        HapticFeedback.mediumImpact();
      }
    });
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
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isProcessing && !_isSuccess && !_isDuplicateUpload) ...[
                // Upload zone
                _buildUploadZone(isDark),
                const SizedBox(height: 24),
                
                if (_errorMessage != null) ...[
                  _buildErrorBanner(isDark),
                  const SizedBox(height: 24),
                ],

                if (_selectedFileName != null) ...[
                  _buildAutoDetectionBanner(isDark),
                  const SizedBox(height: 24),
                  
                  // Bank selector dropdown
                  _buildBankSelector(isDark),
                  const SizedBox(height: 20),

                  // Optional Password field if PDF is selected
                  if (_isPdf) ...[
                    _buildPasswordField(isDark),
                    const SizedBox(height: 20),
                  ],

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _uploadAndParseStatement,
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
                // Processing timeline state
                _buildProcessingState(isDark),
              ] else if (_isDuplicateUpload) ...[
                // Dedicated Premium Duplicate Upload state
                _buildDuplicateUploadState(isDark),
              ] else ...[
                // Success state
                _buildSuccessState(isDark),
              ],
            ],
          ),
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
      onTap: () async {
        try {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['csv', 'pdf'],
            withData: true,
          );

          if (result != null && result.files.isNotEmpty) {
            final file = result.files.first;
            setState(() {
              _selectedFile = file;
              _selectedFileName = file.name;
              _isPdf = file.extension?.toLowerCase() == 'pdf';
              _errorMessage = null;
              _detectBankName(file.name);
            });
            HapticFeedback.lightImpact();
          }
        } catch (e) {
          setState(() {
            _errorMessage = "Failed to select file: $e";
          });
        }
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  _selectedFileName ?? "Tap to upload CSV or PDF Statement",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
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
                  "Choose from Device Storage",
                  style: TextStyle(
                    color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ] else ...[
                Text(
                  "Size: ${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Error Banner Widget
  Widget _buildErrorBanner(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C1414) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.outfit(
                color: isDark ? const Color(0xFFFFB4B4) : Colors.red.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }



  // Bank Auto-Detection Banner
  Widget _buildAutoDetectionBanner(bool isDark) {
    final isDetected = _selectedFileName!.toLowerCase().contains("hdfc") ||
                      _selectedFileName!.toLowerCase().contains("sbi") ||
                      _selectedFileName!.toLowerCase().contains("icici") ||
                      _selectedFileName!.toLowerCase().contains("axis");
    final bannerBg = isDetected 
        ? (isDark ? const Color(0xFF0F1B12) : const Color(0xFFE8F5E9)) 
        : (isDark ? const Color(0xFF2A1C0E) : const Color(0xFFFFF3E0));
    final bannerText = isDetected 
        ? "✓ Auto-Detected: $_selectedBankName Statement" 
        : "⚠ Unknown format. Please select bank below.";
    final textColor = isDetected ? AppColors.successGreen : Colors.orange;

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
            isDetected ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
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

  // Bank selector dropdown
  Widget _buildBankSelector(bool isDark) {
    return DropdownButtonFormField<String>(
      value: _selectedBankName,
      isExpanded: true,
      dropdownColor: isDark ? const Color(0xFF161616) : Colors.white,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: "Bank Name",
        labelStyle: TextStyle(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF161616) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
            width: 1.5,
          ),
        ),
      ),
      items: _supportedBanks.map((String bank) {
        return DropdownMenuItem<String>(
          value: bank,
          child: Text(
            bank,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() => _selectedBankName = val);
        }
      },
    );
  }

  // PDF Password entry field
  Widget _buildPasswordField(bool isDark) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _isObscurePassword,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: "Statement Password (If encrypted PDF)",
        labelStyle: TextStyle(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF161616) : Colors.white,
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isObscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          onPressed: () {
            setState(() => _isObscurePassword = !_isObscurePassword);
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
            width: 1.5,
          ),
        ),
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

              final String stepText;
              if (idx == 2 && isCurrent) {
                stepText = 'Parsing $_parsedCount transactions...';
              } else if (idx == 3 && isCompleted && _nearDuplicatesWarnedCount > 0) {
                stepText = 'Found $_nearDuplicatesWarnedCount near-duplicate(s)';
              } else if (idx == 3 && isCompleted && _duplicatesSkippedCount > 0) {
                stepText = '$_duplicatesSkippedCount exact duplicate(s) skipped';
              } else {
                stepText = stepLabel;
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
                    Expanded(
                      child: Text(
                        stepText,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: rowColor,
                        ),
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

  // Dedicated Premium Duplicate Upload state
  Widget _buildDuplicateUploadState(bool isDark) {
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
          // Premium Warning Info Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.orangeAccent, width: 3),
            ),
            child: const Center(
              child: Icon(
                Icons.info_outline_rounded,
                color: Colors.orangeAccent,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            "Statement Already Imported",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            "All $_totalTransactionsCount transactions in this file are already recorded in your account. No new transactions were added to prevent duplicate entries.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Transaction breakdown rows
          _buildBreakdownRow(isDark, Icons.add_circle_outline_rounded, "New Transactions", "0", isDark ? Colors.white38 : Colors.grey),
          const SizedBox(height: 10),
          _buildBreakdownRow(isDark, Icons.copy_rounded, "Duplicates Skipped", "$_duplicatesSkippedCount", Colors.orange),
          const SizedBox(height: 10),
          _buildBreakdownRow(isDark, Icons.summarize_outlined, "Total Processed", "$_totalTransactionsCount", isDark ? Colors.white70 : Colors.black54),
          const SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _resetState,
                    child: Text(
                      "Upload Another",
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
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
                      "View Transactions",
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
            "Import Successful! 🎉",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            "Bank: $_selectedBankName Statement\nSource: ${_selectedFile?.name ?? 'File'}",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Transaction breakdown rows
          _buildBreakdownRow(isDark, Icons.add_circle_outline_rounded, "New Transactions", "$_newTransactionsCount", AppColors.successGreen),
          const SizedBox(height: 10),
          _buildBreakdownRow(isDark, Icons.copy_rounded, "Duplicates Skipped", "$_duplicatesSkippedCount", Colors.orange),
          if (_nearDuplicatesWarnedCount > 0) ...[
            const SizedBox(height: 10),
            _buildNearDuplicateWarningRow(isDark),
          ],
          const SizedBox(height: 10),
          _buildBreakdownRow(isDark, Icons.summarize_outlined, "Total Processed", "$_totalTransactionsCount", isDark ? Colors.white70 : Colors.black54),
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

  Widget _buildNearDuplicateWarningRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1C0E) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.amber.withOpacity(0.25)
              : Colors.amber.withOpacity(0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Near-Duplicate Warning',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$_nearDuplicatesWarnedCount transaction(s) may already exist with the same amount & merchant. Please review your history.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.amber.withOpacity(0.75)
                        : Colors.amber.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(bool isDark, IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202020) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.lightTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
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
