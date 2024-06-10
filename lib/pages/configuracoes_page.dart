import 'package:app_criptu_moedas/configs/app_settings.dart';
import 'package:app_criptu_moedas/repositories/conta_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  @override
  Widget build(BuildContext context) {
    final conta = context.watch<ContaRepository>();
    final loc = context.read<AppSettings>().locale;
    NumberFormat real =
        NumberFormat.currency(locale: loc['locale'], name: loc['name']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              title: const Text('Saldo'),
              subtitle: Text(
                real.format(conta.saldo),
                style: const TextStyle(
                  fontSize: 25,
                  color: Colors.indigo,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: updateSaldo,
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: OutlinedButton(
                onPressed: () => context.read<AuthService>().logout(),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Sair do App',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  updateSaldo() async {
    final formKey = GlobalKey<FormState>();
    final valorController = TextEditingController();
    final conta = context.read<ContaRepository>();

    valorController.text = conta.saldo.toString();

    AlertDialog dialog = AlertDialog(
      title: const Text('Atualizar o Saldo'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: valorController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
          ],
          validator: (value) {
            if (value!.isEmpty) return 'Informe o valor do saldo';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR')),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              conta.setSaldo(double.parse(valorController.text));
              Navigator.pop(context);
            }
          },
          child: const Text('SALVAR'),
        ),
      ],
    );

    showDialog(context: context, builder: (context) => dialog);
  }
}
