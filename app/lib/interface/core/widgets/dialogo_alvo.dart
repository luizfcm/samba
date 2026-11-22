import 'package:flutter/material.dart';

/// Resposta do diálogo da força-alvo.
class RespostaAlvo {
  const RespostaAlvo(this.valorN);
  const RespostaAlvo.remover() : valorN = null;

  final double? valorN;
}

/// Mostra um diálogo para definir a força-alvo. Retorna a força-alvo em newtons
Future<RespostaAlvo?> mostrarDialogoAlvo(
  BuildContext context, {
  double? alvoAtual,
}) {
  return showDialog<RespostaAlvo>(
    context: context,
    builder: (contexto) => _DialogoAlvo(alvoAtual: alvoAtual),
  );
}

class _DialogoAlvo extends StatefulWidget {
  const _DialogoAlvo({required this.alvoAtual});

  final double? alvoAtual;

  @override
  State<_DialogoAlvo> createState() => _DialogoAlvoState();
}

class _DialogoAlvoState extends State<_DialogoAlvo> {
  late final TextEditingController _campo = TextEditingController(
    text: widget.alvoAtual == null ? '' : widget.alvoAtual!.round().toString(),
  );
  String? _erro;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _definir() {
    final valor = double.tryParse(_campo.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      setState(() => _erro = 'Informe um valor maior que zero');
      return;
    }
    Navigator.pop(context, RespostaAlvo(valor));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Força-alvo'),
      content: TextField(
        controller: _campo,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _definir(),
        decoration: InputDecoration(
          labelText: 'Alvo em newtons',
          suffixText: 'N',
          errorText: _erro,
        ),
      ),
      actions: [
        if (widget.alvoAtual != null)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const RespostaAlvo.remover()),
            child: const Text('Remover'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(onPressed: _definir, child: const Text('Definir')),
      ],
    );
  }
}
