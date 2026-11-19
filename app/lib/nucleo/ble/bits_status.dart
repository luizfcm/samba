/// Máscaras do campo status, comuns ao pacote de medição e ao Estado.
abstract final class BitsStatus {
  static const int saturacao = 1 << 0;
  static const int taraEmAndamento = 1 << 1;
  static const int semCalibracao = 1 << 2;
  static const int erroAdc = 1 << 3;
  static const int modoBruto = 1 << 4;
  static const int aquisicaoEmAndamento = 1 << 5;
}
