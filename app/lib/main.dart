import 'package:flutter/material.dart';

void main() {
  runApp(const AplicativoSamba());
}

class AplicativoSamba extends StatelessWidget {
  const AplicativoSamba({super.key});

  @override
  Widget build(BuildContext contexto) {
    return const MaterialApp(
      title: 'SAMBA',
      home: Scaffold(
        body: Center(child: Text('SAMBA\nInterface em desenvolvimento')),
      ),
    );
  }
}
