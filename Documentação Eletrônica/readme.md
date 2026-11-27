# 📐 Documentação Eletrônica
 
Esta pasta reúne toda a documentação referente ao **hardware eletrônico** do equipamento de medição de força com **célula de carga**, cujos dados são adquiridos por um microcontrolador e enviados para o **aplicativo** responsável pela leitura, exibição e registro das medições.
 
---
 
## 📁 Estrutura da pasta
 
```
documentacao-eletronica/
├── esquemáticos/        # Diagramas esquemáticos do circuito (PDF e arquivos-fonte)
├── datasheets/          # Datasheets dos principais componentes
├── Lista de materiais/             # Link dos materiais utilizados no projeto
└── README.md
---
 
## 🔩 Principais componentes
 
| Componente | Modelo | Função |
|---|---|---|
| Célula de carga em S | Sensor de força |
| Conversor ADC | ADS1220 | Amplificação e conversão A/D |
| Microcontrolador | ESP32 S3 | Processamento e comunicação |
| Fonte | Bateria Li-ion 12V | Energia do sistema |
| Regulador de tensão | MP1584EN | Regula a tensão da bateria para alimentar a ESP
| Regulador de tensão | LT3042 | Regula a tensão da bateria para alimentar a célula de carga e o conversor ADC
 
A lista completa, com quantidades e referências, está no arquivo **BOM**.
 ---
 
## 🛠️ Como montar / reproduzir
 
1. Providencie os componentes listados no BOM.
2. Monte o circuito seguindo o esquemático em `esquematicos/`.
3. Grave o firmware no microcontrolador.
4. Conecte ao aplicativo e verifique as leituras.
---
Projeto desenvolvido para a disciplina/trabalho de **[nome da disciplina ou instituição]**._
 
