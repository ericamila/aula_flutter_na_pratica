import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';
import '../database/db.dart';
import '../models/historico.dart';
import '../models/moeda.dart';
import '../models/posicao.dart';
import 'moeda_repository.dart';

class ContaRepository extends ChangeNotifier {
  List<Posicao> _carteira = [];
  List<Historico> _historico = [];
  late Database db;
  double _saldo = 0;
  late MoedaRepository moedas;

  get saldo => _saldo;

  List<Posicao> get carteira => _carteira;

  List<Historico> get historico => _historico;

  ContaRepository({required this.moedas}) {
    _initRepository();
  }

  _initRepository() async {
    await _getSaldo();
    await _getCarteira();
    await _getHistorico();
  }

  _getSaldo() async {
    db = await DB.instance.database;
    List conta = await db.query('conta', limit: 1);
    _saldo = conta.first['saldo'];
    notifyListeners();
  }

  setSaldo(double valor) async {
    db = await DB.instance.database;
    db.update('conta', {
      'saldo': valor,
    });
    _saldo = valor;
    notifyListeners();
  }

  comprar(Moeda moeda, double valor) async {
    db = await DB.instance.database;
    await db.transaction((txn) async {
      //Verificar se já foi comprada antes
      final posicaoMoeda = await txn
          .query('carteira', where: 'sigla = ?', whereArgs: [moeda.sigla]);

      //Se não tem moeda em carteira
      if (posicaoMoeda.isEmpty) {
        await txn.insert('carteira', {
          'sigla': moeda.sigla,
          'moeda': moeda.nome,
          'quantidade': (valor / moeda.preco).toString()
        });

        //Já tem a moeda em carteira
      } else {
        final atual = double.parse(posicaoMoeda.first['quantidade'].toString());
        await txn.update(
          'carteira',
          {'quantidade': ((valor / moeda.preco) + atual).toString()},
          where: 'sigla = ?',
          whereArgs: [moeda.sigla],
        );
      }

      // Inserir o histórico
      await txn.insert('historico', {
        'sigla': moeda.sigla,
        'moeda': moeda.nome,
        'quantidade': (valor / moeda.preco).toString(),
        'valor': valor,
        'tipo_operacao': 'compra',
        'data_operacao': DateTime.now().millisecondsSinceEpoch
      });

      await txn.update('conta', {'saldo': saldo - valor});
    });

    await _initRepository();
    notifyListeners();
  }

  _getCarteira() async {
    _carteira = [];
    List posicoes = await db.query('carteira');
    for (var posicao in posicoes) {
      Moeda moeda = moedas.tabela.firstWhere(
        (m) => m.sigla == posicao['sigla'],
      );
      _carteira.add(Posicao(
        moeda: moeda,
        quantidade: double.parse(posicao['quantidade']),
      ));
    }
    notifyListeners();
  }

  _getHistorico() async {
    _historico = [];
    List operacoes = await db.query('historico');
    for (var operacao in operacoes) {
      Moeda moeda = moedas.tabela.firstWhere(
        (m) => m.sigla == operacao['sigla'],
      );
      _historico.add(Historico(
        dataOperacao:
            DateTime.fromMillisecondsSinceEpoch(operacao['data_operacao']),
        tipoOperacao: operacao['tipo_operacao'],
        moeda: moeda,
        valor: operacao['valor'],
        quantidade: double.parse(operacao['quantidade']),
      ));
    }
    notifyListeners();
  }
}
