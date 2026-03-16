import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class UpiScannerScreen extends StatefulWidget {
  const UpiScannerScreen({Key? key}) : super(key: key);

  @override
  State<UpiScannerScreen> createState() => _UpiScannerScreenState();
}

class _UpiScannerScreenState extends State<UpiScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController cameraController;
  bool isProcessing = false;
  bool _cameraPermissionGranted = false;
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      autoStart: false,
      facing: CameraFacing.back,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermissions());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_cameraPermissionGranted) cameraController.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        cameraController.stop();
        break;
      default:
        break;
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.camera.request();
    final granted = status == PermissionStatus.granted;
    if (granted) await cameraController.start();
    if (mounted) {
      setState(() {
        _cameraPermissionGranted = granted;
        _permissionChecked = true;
      });
    }
  }

  Future<void> _handleUpiQr(String qrData) async {
    try {
      // ✅ If it's already a full UPI URL, use it directly
      // Otherwise parse and rebuild it cleanly
      Uri upiUri;

      if (qrData.startsWith('upi://')) {
        upiUri = Uri.parse(qrData);
      } else {
        // Parse individual fields from raw QR data
        final upiMatch = RegExp(r'pa=([^&]+)').firstMatch(qrData);
        final nameMatch = RegExp(r'pn=([^&]+)').firstMatch(qrData);
        final amountMatch = RegExp(r'am=([\d.]+)').firstMatch(qrData);

        final String? upiVpa = upiMatch?.group(1);
        if (upiVpa == null) {
          _showSnack('Invalid UPI QR code', Colors.red);
          return;
        }

        // ✅ Build a standard UPI payment URI
        upiUri = Uri(
          scheme: 'upi',
          host: 'pay',
          queryParameters: {
            'pa': upiVpa,
            'pn': Uri.decodeComponent(nameMatch?.group(1) ?? 'Merchant'),
            // 'am': amountMatch?.group(1) ?? '0',
            'am': '100.00', //for fixed amount(not working)
            'cu': 'INR',
            'tn': 'Expense via QR scan',
            'tr':
                'TXN${DateTime.now().millisecondsSinceEpoch.toRadixString(36).substring(0, 20)}',
            'mc': '0000',
          },
        );
      }

      debugPrint('🔗 Launching UPI URI: $upiUri');

      // ✅ Android shows system app-chooser (GPay, PhonePe, etc. appear automatically)
      if (await canLaunchUrl(upiUri)) {
        await launchUrl(upiUri, mode: LaunchMode.externalApplication);
        // ✅ We can't know the result — show a neutral message
        if (mounted) {
          _showSnack('Opening payment app…', Colors.blue);
        }
      } else {
        _showSnack('No UPI app found on this device', Colors.red);
      }
    } catch (e) {
      debugPrint('UPI launch error: $e');
      _showSnack('Failed to open UPI: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => isProcessing = false);
        cameraController.start();
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan UPI QR'),
        backgroundColor: const Color(0xFF30437A),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_permissionChecked) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_cameraPermissionGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Camera access is required to scan QR codes'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: openAppSettings,
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: cameraController,
          onDetect: (BarcodeCapture capture) async {
            if (isProcessing) return;
            final String? code = capture.barcodes.firstOrNull?.rawValue;
            if (code != null) {
              isProcessing = true;
              cameraController.stop();
              await _handleUpiQr(code);
            }
          },
        ),
        CustomPaint(
          painter: ScannerOverlayPainter(),
          child: const SizedBox.expand(),
        ),
        const Positioned(
          bottom: 100,
          left: 40,
          right: 40,
          child: Column(
            children: [
              Text(
                'Align QR code in frame',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Your camera will scan automatically',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    super.dispose();
  }
}

// Keep your ScannerOverlayPainter with the 4-rect fix from before
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.55);
    final cutoutSize = size.width * 0.7;
    final cutoutLeft = (size.width - cutoutSize) / 2;
    final cutoutTop = size.height * 0.2;
    final cutoutRight = cutoutLeft + cutoutSize;
    final cutoutBottom = cutoutTop + cutoutSize;

    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, cutoutTop), paint);
    canvas.drawRect(
      Rect.fromLTRB(0, cutoutBottom, size.width, size.height),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, cutoutTop, cutoutLeft, cutoutBottom),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTRB(cutoutRight, cutoutTop, size.width, cutoutBottom),
      paint,
    );

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cutoutLeft, cutoutTop, cutoutRight, cutoutBottom),
        const Radius.circular(20),
      ),
      borderPaint,
    );

    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const L = 28.0;
    final tl = Offset(cutoutLeft, cutoutTop);
    final tr = Offset(cutoutRight, cutoutTop);
    final bl = Offset(cutoutLeft, cutoutBottom);
    final br = Offset(cutoutRight, cutoutBottom);

    canvas.drawLine(tl, tl + const Offset(L, 0), linePaint);
    canvas.drawLine(tl, tl + const Offset(0, L), linePaint);
    canvas.drawLine(tr, tr + const Offset(-L, 0), linePaint);
    canvas.drawLine(tr, tr + const Offset(0, L), linePaint);
    canvas.drawLine(bl, bl + const Offset(L, 0), linePaint);
    canvas.drawLine(bl, bl + const Offset(0, -L), linePaint);
    canvas.drawLine(br, br + const Offset(-L, 0), linePaint);
    canvas.drawLine(br, br + const Offset(0, -L), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// import 'package:flutter/material.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:upi_pay/upi_pay.dart';

// class UpiScannerScreen extends StatefulWidget {
//   const UpiScannerScreen({Key? key}) : super(key: key);

//   @override
//   State<UpiScannerScreen> createState() => _UpiScannerScreenState();
// }

// class _UpiScannerScreenState extends State<UpiScannerScreen> {
//   MobileScannerController cameraController = MobileScannerController(
//     detectionSpeed: DetectionSpeed.normal,
//     autoStart: true, // ✅ Auto-start camera
//     facing: CameraFacing.back,
//   );
//   bool isProcessing = false;

//   List<ApplicationMeta> upiApps = []; // ✅ Store available apps

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _requestPermissions();
//       _getUpiApps(); // ✅ Get installed UPI apps on load
//     });
//   }

//   Future<void> _getUpiApps() async {
//     try {
//       print('🔍 Checking UPI apps...'); // Add this
//       upiApps = await UpiPay().getInstalledUpiApplications();
//       print(
//         '📱 Found ${upiApps.length} UPI apps: ${upiApps.map((a) => a.upiApplication.getAppName()).toList()}',
//       );
//       if (upiApps.isEmpty) {
//         print('❌ No UPI apps detected - check Android restrictions');
//       }
//       setState(() {}); // Update UI if needed
//     } catch (e) {
//       debugPrint('No UPI apps: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Scan UPI QR'),
//         backgroundColor: const Color(0xFF30437A),
//       ),
//       body: Stack(
//         children: [
//           // Scanner view
//           MobileScanner(
//             controller: cameraController,
//             onDetect: (BarcodeCapture capture) async {
//               if (isProcessing) return;

//               final List<Barcode> barcodes = capture.barcodes;
//               final String? code = barcodes.first.rawValue;

//               if (code != null) {
//                 isProcessing = true;
//                 await _handleUpiQr(code);
//               }
//             },
//           ),

//           // Scanner overlay (center square)
//           _buildScannerOverlay(context),
//         ],
//       ),
//     );
//   }

//   Widget _buildScannerOverlay(BuildContext context) {
//     return Stack(
//       fit: StackFit.expand,
//       children: [
//         // ✅ Dark corners (NOT full screen)
//         Positioned.fill(
//           child: Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [Colors.black54, Colors.transparent],
//               ),
//             ),
//           ),
//         ),

//         // ✅ Center scan window (transparent)
//         Center(
//           child: Container(
//             width: MediaQuery.of(context).size.width * 0.75,
//             height: MediaQuery.of(context).size.height * 0.4,
//             decoration: BoxDecoration(
//               border: Border.all(color: Colors.greenAccent, width: 3),
//               borderRadius: BorderRadius.circular(16),
//               // ✅ NO background - camera shows through
//             ),
//           ),
//         ),

//         // Instructions text
//         const Positioned(
//           bottom: 100,
//           left: 40,
//           right: 40,
//           child: Column(
//             children: [
//               Text(
//                 'Align QR code in frame',
//                 style: TextStyle(color: Colors.white, fontSize: 16),
//                 textAlign: TextAlign.center,
//               ),
//               SizedBox(height: 8),
//               Text(
//                 'Your camera will scan automatically',
//                 style: TextStyle(color: Colors.white70, fontSize: 14),
//                 textAlign: TextAlign.center,
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Future<void> _requestPermissions() async {
//     final status = await Permission.camera.request();
//     if (status != PermissionStatus.granted) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Camera permission required')),
//         );
//       }
//     }
//   }

//   Future<void> _handleUpiQr(String qrData) async {
//     if (upiApps.isEmpty) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('No UPI apps installed')));
//       return;
//     }

//     try {
//       final upiMatch = RegExp(r'pa=([^&]+)').firstMatch(qrData);
//       final amountMatch = RegExp(r'am=([0-9.]+)').firstMatch(qrData);

//       final String? upiVpa = upiMatch?.group(1);
//       final double amount = double.tryParse(amountMatch?.group(1) ?? '0') ?? 0;

//       if (upiVpa == null) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(const SnackBar(content: Text('Invalid UPI QR')));
//         return;
//       }

//       // ✅ Let user pick which UPI app to use
//       final selectedApp = await _showAppPicker();
//       if (selectedApp == null || !mounted) return;

//       final response = await UpiPay().initiateTransaction(
//         // ✅ static call, no instantiation
//         app: selectedApp.upiApplication, // ✅ ApplicationMeta object directly
//         receiverUpiAddress: upiVpa,
//         receiverName: 'Merchant',
//         transactionRef: 'EXP_${DateTime.now().millisecondsSinceEpoch}',
//         transactionNote: 'Expense via QR scan',
//         amount: amount.toStringAsFixed(2),
//       );

//       if (!mounted) return;

//       final isSuccess =
//           response?.status == UpiTransactionStatus.success; // ✅ lowercase enum
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             isSuccess
//                 ? 'Payment Successful!'
//                 : 'Status: ${response?.status ?? "Unknown"}',
//           ),
//           backgroundColor: isSuccess ? Colors.green : Colors.orange,
//         ),
//       );

//       if (isSuccess) Navigator.pop(context);
//     } catch (e) {
//       // ✅ Always catch — otherwise finally swallows the real error silently
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Payment failed: ${e.toString()}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() => isProcessing = false); // ✅ setState so UI rebuilds
//       }
//     }
//   }

//   Future<ApplicationMeta?> _showAppPicker() async {
//     return showModalBottomSheet<ApplicationMeta>(
//       context: context,
//       builder: (ctx) => ListView(
//         shrinkWrap: true,
//         children: [
//           const Padding(
//             padding: EdgeInsets.all(16),
//             child: Text(
//               'Pay with',
//               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//             ),
//           ),
//           ...upiApps.map(
//             (app) => ListTile(
//               leading: CircleAvatar(
//                 child: Text(app.upiApplication.getAppName()[0]),
//               ),

//               title: Text(app.upiApplication.getAppName()),
//               onTap: () => Navigator.pop(ctx, app),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     cameraController.dispose();
//     super.dispose();
//   }
// }

// // Scanner overlay (center square)
// class ScannerOverlayPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);

//     final cutoutSize = size.width * 0.7;
//     final cutoutOffset = Offset(
//       (size.width - cutoutSize) / 2,
//       (size.height * 0.2),
//     );

//     // Semi-transparent overlay
//     canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

//     // Clear center square
//     canvas.drawRRect(
//       RRect.fromRectAndRadius(
//         Rect.fromLTWH(cutoutOffset.dx, cutoutOffset.dy, cutoutSize, cutoutSize),
//         const Radius.circular(20),
//       ),
//       Paint()..blendMode = BlendMode.clear,
//     );

//     // Corner lines
//     final linePaint = Paint()
//       ..color = Colors.white
//       ..strokeWidth = 4
//       ..strokeCap = StrokeCap.round;

//     const lineLength = 30.0;
//     canvas.drawLine(
//       cutoutOffset + const Offset(0, 0),
//       cutoutOffset + const Offset(lineLength, 0),
//       linePaint,
//     );
//     canvas.drawLine(
//       cutoutOffset + const Offset(0, 0),
//       cutoutOffset + const Offset(0, lineLength),
//       linePaint,
//     );
//     canvas.drawLine(
//       cutoutOffset + Offset(cutoutSize, 0),
//       cutoutOffset + Offset(cutoutSize - lineLength, 0),
//       linePaint,
//     );
//     canvas.drawLine(
//       cutoutOffset + Offset(cutoutSize, 0),
//       cutoutOffset + Offset(cutoutSize, lineLength),
//       linePaint,
//     );
//     canvas.drawLine(
//       cutoutOffset + Offset(0, cutoutSize),
//       cutoutOffset + Offset(lineLength, cutoutSize),
//       linePaint,
//     );
//     canvas.drawLine(
//       cutoutOffset + Offset(0, cutoutSize),
//       cutoutOffset + Offset(0, cutoutSize - lineLength),
//       linePaint,
//     );
//     canvas.drawLine(
//       cutoutOffset + Offset(cutoutSize, cutoutSize),
//       cutoutOffset + Offset(cutoutSize - lineLength, cutoutSize),
//       linePaint,
//     );
//     canvas.drawLine(
//       cutoutOffset + Offset(cutoutSize, cutoutSize),
//       cutoutOffset + Offset(cutoutSize, cutoutSize - lineLength),
//       linePaint,
//     );
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }
