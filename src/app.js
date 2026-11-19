const express = require('express');
const { criarRepositorioEmMemoria } = require('./livros/repositorio');
const {
  criarServicoDeLivros,
  ErroDeValidacao,
  NaoEncontrado,
  Conflito,
} = require('./livros/servico');
const { criarRotasDeLivros } = require('./livros/rotas');
const { version } = require('../package.json');

// Cria o app sem abrir a porta (os testes usam assim)
function criarApp({ repositorio = criarRepositorioEmMemoria() } = {}) {
  const app = express();
  const servico = criarServicoDeLivros(repositorio);

  app.use(express.json());

  app.get('/health', (req, res) => {
    res.json({ status: 'ok', versao: version });
  });

  app.use('/livros', criarRotasDeLivros(servico));

  app.use((req, res) => {
    res.status(404).json({ erro: 'rota não encontrada' });
  });

  // Converte os erros em status HTTP (o Express exige os 4 parâmetros)
  app.use((erro, req, res, _next) => {
    if (erro instanceof ErroDeValidacao) return res.status(400).json({ erro: erro.message });
    if (erro instanceof NaoEncontrado) return res.status(404).json({ erro: erro.message });
    if (erro instanceof Conflito) return res.status(409).json({ erro: erro.message });
    if (erro.type === 'entity.parse.failed') {
      return res.status(400).json({ erro: 'JSON inválido' });
    }
    console.error(erro);
    return res.status(500).json({ erro: 'erro interno' });
  });

  return app;
}

module.exports = { criarApp };
