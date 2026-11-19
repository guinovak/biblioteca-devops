const { criarApp } = require('./app');

const porta = Number(process.env.PORT) || 3000;

const servidor = criarApp().listen(porta, () => {
  console.log(`Biblioteca ouvindo na porta ${porta}`);
});

// O ECS manda SIGTERM antes de parar a tarefa: fecha as conexões e sai limpo
process.on('SIGTERM', () => {
  servidor.close(() => process.exit(0));
});
