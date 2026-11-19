const { Router } = require('express');
const { ErroDeValidacao } = require('./servico');

function criarRotasDeLivros(servico) {
  const rotas = Router();

  function idDaRota(req) {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      throw new ErroDeValidacao('id deve ser um inteiro positivo');
    }
    return id;
  }

  rotas.get('/', (req, res) => {
    const { disponivel } = req.query;
    if (disponivel !== undefined && disponivel !== 'true' && disponivel !== 'false') {
      throw new ErroDeValidacao('disponivel deve ser true ou false');
    }
    const filtro = disponivel === undefined ? {} : { disponivel: disponivel === 'true' };
    res.json(servico.listar(filtro));
  });

  rotas.get('/:id', (req, res) => {
    res.json(servico.obter(idDaRota(req)));
  });

  rotas.post('/', (req, res) => {
    res.status(201).json(servico.cadastrar(req.body));
  });

  rotas.put('/:id', (req, res) => {
    res.json(servico.atualizar(idDaRota(req), req.body));
  });

  rotas.delete('/:id', (req, res) => {
    servico.remover(idDaRota(req));
    res.status(204).end();
  });

  rotas.post('/:id/emprestimo', (req, res) => {
    res.json(servico.emprestar(idDaRota(req), req.body));
  });

  rotas.post('/:id/devolucao', (req, res) => {
    res.json(servico.devolver(idDaRota(req)));
  });

  return rotas;
}

module.exports = { criarRotasDeLivros };
