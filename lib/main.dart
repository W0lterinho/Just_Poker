import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'repository/auth_repository.dart';
import 'repository/poker_repository.dart';
import 'bloc/auth/auth_bloc.dart';
import 'bloc/game/game_cubit.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/choice_screen.dart';
import 'screens/poker_tables_screen.dart';
import 'screens/join_private_screen.dart';
import 'screens/game_screen.dart';

void main() {
  final authRepo  = AuthRepository();
  final pokerRepo = PokerRepository();
  final storage   = const FlutterSecureStorage();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepo),
        RepositoryProvider.value(value: pokerRepo),
        // <-- tu dodajemy secure storage
        RepositoryProvider<FlutterSecureStorage>.value(value: storage),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(authRepository: authRepo),
          ),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JustPoker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'MontserratBoldItalic',
      ),
      initialRoute: HomeScreen.routeName,
      routes: {
        HomeScreen.routeName:      (_) => const HomeScreen(),
        LoginScreen.routeName:     (_) => const LoginScreen(),
        RegisterScreen.routeName:  (_) => const RegisterScreen(),
        ChoiceScreen.routeName:    (_) => const ChoiceScreen(),
        PokerTablesScreen.routeName: (_) => const PokerTablesScreen(),
        JoinPrivateScreen.routeName: (_) => const JoinPrivateScreen(),
        // jeśli wolisz mieć GameScreen w routes:
        GameScreen.routeName:      (_) {
          final args = ModalRoute.of(_)!.settings.arguments
          as Map<String, dynamic>;
          return BlocProvider(
            create: (context) => GameCubit(
              context.read<PokerRepository>(),
              context.read<FlutterSecureStorage>(),
            ),
            child: GameScreen(
              tableCode: args['tableCode'] as int,
              isCreator: args['isCreator'] as bool,
            ),
          );
        },
      },
    );
  }
}