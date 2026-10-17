# SAMBA

O Sistema de Avaliação de Movimento e Biomecânica Aplicada (SAMBA) é um projeto universitário de aquisição e análise de força. Este repositório reúne a base de software e a documentação técnica mantidas pela equipe.

## Estado atual

O aplicativo Flutter contém uma fonte simulada de força a 100 Hz, um modelo de amostra, um decodificador de pacotes BLE e o cálculo de força máxima, força média, duração e impulso. Esses componentes têm testes unitários.

A interface contém apenas a identificação do SAMBA e um aviso de que está em desenvolvimento, sem conexão com a aquisição. Não há comunicação BLE real, firmware executável, processamento específico por exercício, persistência ou sincronização.

O desenvolvimento e a validação inicial do aplicativo estão concentrados em Android.

## Organização

- `app/`: aplicativo Flutter e testes.
- `docs/`: arquitetura, protocolos BLE e definição das métricas.
- `firmware/`: registro do estado do firmware, ainda sem código executável.
- `analysis/`: diretório de análise, ainda sem scripts ou notebooks.
- `data/raw/` e `data/processed/`: diretórios de dados, atualmente sem amostras versionadas.

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
- [Protocolo BLE v2](docs/protocolo_ble_v2.md), adotado pelo dispositivo
- [Pacote BLE v1](docs/protocolo_ble_v1.md)
- [Métricas de força](docs/metrics.md)
