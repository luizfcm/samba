# SAMBA

O Sistema de Avaliação de Movimento e Biomecânica Aplicada (SAMBA) é um projeto universitário de aquisição e análise de força, com célula de carga, ESP32-S3 e aplicativo Flutter para Android.

## Organização

- `app/`: aplicativo Flutter e testes.
- `docs/`: arquitetura, protocolo BLE v2 e métricas.
- `firmware/`: firmware do ESP32-S3.
- `analysis/`: análises de sinais.
- `data/raw/` e `data/processed/`: dados brutos e processados.

## Execução e validação

É necessário ter Flutter instalado com Dart compatível com `^3.13.5`, conforme `app/pubspec.yaml`.

```sh
cd app
flutter pub get
flutter run
```

As verificações do aplicativo são executadas em `app/`:

```sh
dart format .
flutter analyze
flutter test
```

Os testes da fonte simulada usam temporizadores reais; a força é determinística, mas o agendamento e os timestamps podem variar.

## Documentação técnica

- [Arquitetura](docs/architecture.md)
- [Protocolo BLE v2](docs/protocolo_ble_v2.md)
- [Métricas de força](docs/metrics.md)
