import 'package:app_criptu_moedas/repositories/conta_repository.dart';
import 'package:app_criptu_moedas/repositories/moeda_repository.dart';
import 'package:app_criptu_moedas/services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';

import 'configs/hive_config.dart';
import 'firebase_options.dart';
import 'repositories/favoritas_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'configs/app_settings.dart';
import 'meu_aplicativo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveConfig.start();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
        ChangeNotifierProvider(create: (context) => MoedaRepository()),
        ChangeNotifierProvider(
            create: (context) => ContaRepository(
                  moedas: context.read<MoedaRepository>(),
                )),
        ChangeNotifierProvider(create: (context) => AppSettings()),
        ChangeNotifierProvider(
          create: (context) => FavoritasRepository(
            auth: context.read<AuthService>(),
            moedas: context.read<MoedaRepository>(),
          ),
        ),
      ],
      child: const MeuAplicativo(),
    ),
  );
}
