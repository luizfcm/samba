final RegExp _formatoEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool emailValido(String email) => _formatoEmail.hasMatch(email.trim());

const int tamanhoMinimoSenha = 6;
