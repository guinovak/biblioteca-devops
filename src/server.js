const { criarApp } = require('./app');

const porta = Number(process.env.PORT) || 3000;

const servidor = criarApp().listen(porta, () => {
  console.log(`Biblioteca ouvindo na porta ${porta}`);
});

// Fecha o servidor quando o container é parado
process.on('SIGTERM', () => {
  servidor.close(() => process.exit(0));
});
