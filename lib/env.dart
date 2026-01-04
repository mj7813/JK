import 'package:envied/envied.dart';
part 'env.g.dart';

@Envied(path: '.env') // Specify the path to your .env file
abstract class Env {
  @EnviedField(varName: 'API_KEY', obfuscate: true)
  static final String apiKey = _Env.apiKey; // Use obfuscate: true for extra security (optional)

  @EnviedField(varName: 'BASE_URL')
  static final String baseUrl = _Env.baseUrl;
}