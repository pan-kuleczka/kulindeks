// ignore_for_file: avoid_print
import 'package:kulindeks/api/client.dart';
void main() async {
  final cols = await MStudentClient.discoverColleges();
  print('discovered ${cols.length} colleges');
  final umw = cols.firstWhere((c) => c.baseUrl.contains('umw'));
  print('UMW: ${umw.name} -> ${umw.baseUrl} mfa=${umw.mfa} pri=${umw.primaryColor}');
  // prove the base/core URL composition
  final c = MStudentClient(umw.baseUrl);
  print('core prefix OK');
  c.close();
}
