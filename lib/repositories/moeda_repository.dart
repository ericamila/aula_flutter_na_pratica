import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import '../database/db.dart';
import '../models/moeda.dart';

class MoedaRepository extends ChangeNotifier {
  static List<Moeda> _tabela = [];
  late Timer intervalo;

  List<Moeda> get tabela => _tabela;

  MoedaRepository() {
    _setupMoedasTable();
    _setupDadosTableMoedas();
    _readMoedasTable();
    _refreshPrecos();
  }

  _refreshPrecos() async {
    intervalo =
        Timer.periodic(const Duration(minutes: 5), (_) => checkPrecos());
  }

  _setupMoedasTable() async {
    const String table = '''
      CREATE TABLE IF NOT EXISTS moedas (
        baseId TEXT PRIMARY KEY,
        sigla TEXT,
        nome TEXT,
        icone TEXT,
        preco TEXT,
        timestamp INTEGER,
        mudancaHora TEXT,
        mudancaDia TEXT,
        mudancaSemana TEXT,
        mudancaMes TEXT,
        mudancaAno TEXT,
        mudancaPeriodoTotal TEXT
      );
    ''';
    Database db = await DB.instance.database;
    await db.execute(table);
  }

  _moedasTableIsEmpty() async {
    Database db = await DB.instance.database;
    List resultados = await db.query('moedas');
    return resultados.isEmpty;
  }

  _setupDadosTableMoedas() async {
    if (await _moedasTableIsEmpty()) {
      String uri = 'https://api.coinbase.com/v2/assets/search?base=BRL';

      final response = await http.get(Uri.parse(uri));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> moedas = json['data'];
        Database db = await DB.instance.database;
        Batch batch = db.batch();

        for (var moeda in moedas) {
          final preco = moeda['latest_price'];
          final timestamp = DateTime.parse(preco['timestamp']);

          batch.insert('moedas', {
            'baseId': moeda['id'],
            'sigla': moeda['symbol'],
            'nome': moeda['name'],
            'icone': moeda['image_url'],
            'preco': moeda['latest'],
            'timestamp': timestamp.millisecondsSinceEpoch,
            'mudancaHora': preco['percent_change']['hour'].toString(),
            'mudancaDia': preco['percent_change']['day'].toString(),
            'mudancaSemana': preco['percent_change']['week'].toString(),
            'mudancaMes': preco['percent_change']['month'].toString(),
            'mudancaAno': preco['percent_change']['year'].toString(),
            'mudancaPeriodoTotal': preco['percent_change']['all'].toString()
          });
        }
        await batch.commit(noResult: true);
      }
    }
  }

  _readMoedasTable() async {
    Database db = await DB.instance.database;
    List resultados = await db.query('moedas');

    _tabela = resultados.map((row) {
      double mudancaHora = 0,
          mudancaDia = 0,
          mudancaSemana = 0,
          mudancaMes = 0,
          mudancaAno = 0,
          mudancaPeriodoTotal = 0;

      try {
        mudancaHora = double.parse(row['mudancaHora']);
        mudancaDia = double.parse(row['mudancaDia']);
        mudancaSemana = double.parse(row['mudancaSemana']);
        mudancaMes = double.parse(row['mudancaMes']);
        mudancaAno = double.parse(row['mudancaAno']);
        mudancaPeriodoTotal = double.parse(row['mudancaPeriodoTotal']);
      } catch (e) {
        debugPrint('debug $e');
      }

      return Moeda(
        baseId: row['baseId'],
        icone: row['icone'].toString(),
        sigla: row['sigla'],
        nome: row['nome'],
        preco: double.parse(row['preco']),
        timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp']),
        mudancaHora: mudancaHora,
        mudancaDia: mudancaDia,
        mudancaSemana: mudancaSemana,
        mudancaMes: mudancaMes,
        mudancaAno: mudancaAno,
        mudancaPeriodoTotal: mudancaPeriodoTotal,
      );
    }).toList();

    notifyListeners();
  }

  getHistoricoMoeda(Moeda moeda) async {
    final response = await http.get(
      Uri.parse(
        'https://api.coinbase.com/v2/assets/prices/${moeda.baseId}?base=BRL',
      ),
    );
    List<Map<String, dynamic>> precos = [];

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final Map<String, dynamic> moeda = json['data']['prices'];

      precos.add(moeda['hour']);
      precos.add(moeda['day']);
      precos.add(moeda['week']);
      precos.add(moeda['month']);
      precos.add(moeda['year']);
      precos.add(moeda['all']);
    }

    return precos;
  }

  checkPrecos() async {
    String uri = 'https://api.coinbase.com/v2/assets/prices?base=BRL';
    final response = await http.get(Uri.parse(uri));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List<dynamic> moedas = json['data'];
      Database db = await DB.instance.database;
      Batch batch = db.batch();

      for (var atual in _tabela) {
        for (var novo in moedas) {
          if (atual.baseId == novo['base_id']) {
            final moeda = novo['prices'];
            final preco = moeda['latest_price'];
            final timestamp = DateTime.parse(preco['timestamp']);

            batch.update(
              'moedas',
              {
                'preco': moeda['latest'],
                'timestamp': timestamp.millisecondsSinceEpoch,
                'mudancaHora': preco['percent_change']['hour'].toString(),
                'mudancaDia': preco['percent_change']['day'].toString(),
                'mudancaSemana': preco['percent_change']['week'].toString(),
                'mudancaMes': preco['percent_change']['month'].toString(),
                'mudancaAno': preco['percent_change']['year'].toString(),
                'mudancaPeriodoTotal': preco['percent_change']['all'].toString()
              },
              where: 'baseId = ?',
              whereArgs: [atual.baseId],
            );
          }
        }
      }
      await batch.commit(noResult: true);
      await _readMoedasTable();
    }
  }
}
