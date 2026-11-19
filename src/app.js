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

/**
 * Monta a aplicação sem abrir porta, para os testes usarem com o Supertest.
 * Cada chamada cria um repositório novo, então os testes não se contaminam.
 */
function criarApp({ repositorio = criarRepositorioEmMemoria() } = {}) {
  const app = express();
  const servico = criarServicoDeLivros(repositorio);

  app.use(express.json());

  // Usado pelo health check do Docker, do load balancer e do teste de fumaça do CI
  app.get('/health', (req, res) => {
    res.json({ status: 'ok', versao: version });
  });

  app.use('/livros', criarRotasDeLivros(servico));

  app.use((req, res) => {
    res.status(404).json({ erro: 'rota não encontrada' });
  });

  // Tratador central: traduz os erros do serviço em status HTTP.
  // O Express só reconhece tratador de erro com 4 parâmetros, por isso o _next.
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
