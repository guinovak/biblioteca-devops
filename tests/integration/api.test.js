const request = require('supertest');
const { criarApp } = require('../../src/app');

describe('API da biblioteca', () => {
  let app;

  beforeEach(() => {
    app = criarApp(); // repositório novo a cada teste
  });

  async function cadastrar(livro = { titulo: 'Dom Casmurro', autor: 'Machado de Assis', ano: 1899 }) {
    const resposta = await request(app).post('/livros').send(livro);
    return resposta.body;
  }

  test('GET /health responde ok com a versão', async () => {
    const resposta = await request(app).get('/health');

    expect(resposta.status).toBe(200);
    expect(resposta.body).toEqual({ status: 'ok', versao: expect.any(String) });
  });

  test('POST /livros cadastra e devolve 201', async () => {
    const resposta = await request(app)
      .post('/livros')
      .send({ titulo: 'Memórias Póstumas de Brás Cubas', autor: 'Machado de Assis', ano: 1881 });

    expect(resposta.status).toBe(201);
    expect(resposta.body).toMatchObject({ id: 1, ano: 1881, emprestimo: null });
  });

  test('POST /livros com dados inválidos devolve 400 com a mensagem', async () => {
    const resposta = await request(app).post('/livros').send({ titulo: '' });

    expect(resposta.status).toBe(400);
    expect(resposta.body.erro).toMatch(/titulo é obrigatório/);
  });

  test('POST /livros com JSON malformado devolve 400', async () => {
    const resposta = await request(app)
      .post('/livros')
      .set('Content-Type', 'application/json')
      .send('{"titulo": ');

    expect(resposta.status).toBe(400);
    expect(resposta.body.erro).toBe('JSON inválido');
  });

  test('GET /livros lista e filtra por disponibilidade', async () => {
    const livro = await cadastrar();
    await cadastrar({ titulo: 'Iracema', autor: 'José de Alencar' });
    await request(app).post(`/livros/${livro.id}/emprestimo`).send({ leitor: 'Ana' });

    const todos = await request(app).get('/livros');
    const disponiveis = await request(app).get('/livros?disponivel=true');
    const emprestados = await request(app).get('/livros?disponivel=false');

    expect(todos.body).toHaveLength(2);
    expect(disponiveis.body.map((l) => l.titulo)).toEqual(['Iracema']);
    expect(emprestados.body.map((l) => l.titulo)).toEqual(['Dom Casmurro']);
  });

  test('GET /livros com filtro inválido devolve 400', async () => {
    const resposta = await request(app).get('/livros?disponivel=talvez');

    expect(resposta.status).toBe(400);
  });

  test('GET /livros/:id devolve o livro ou 404', async () => {
    const livro = await cadastrar();

    expect((await request(app).get(`/livros/${livro.id}`)).body.titulo).toBe('Dom Casmurro');
    expect((await request(app).get('/livros/999')).status).toBe(404);
  });

  test('id que não é inteiro positivo devolve 400', async () => {
    expect((await request(app).get('/livros/abc')).status).toBe(400);
    expect((await request(app).get('/livros/0')).status).toBe(400);
  });

  test('PUT /livros/:id atualiza o livro', async () => {
    const livro = await cadastrar();

    const resposta = await request(app)
      .put(`/livros/${livro.id}`)
      .send({ titulo: 'Dom Casmurro (edição comentada)', autor: 'Machado de Assis' });

    expect(resposta.status).toBe(200);
    expect(resposta.body.titulo).toBe('Dom Casmurro (edição comentada)');
  });

  test('fluxo completo: emprestar, recusar 2º empréstimo, devolver e remover', async () => {
    const { id } = await cadastrar();

    const emprestimo = await request(app).post(`/livros/${id}/emprestimo`).send({ leitor: 'Ana' });
    expect(emprestimo.status).toBe(200);
    expect(emprestimo.body.emprestimo.leitor).toBe('Ana');

    const segundo = await request(app).post(`/livros/${id}/emprestimo`).send({ leitor: 'Bruno' });
    expect(segundo.status).toBe(409);

    const remocaoBloqueada = await request(app).delete(`/livros/${id}`);
    expect(remocaoBloqueada.status).toBe(409);

    const devolucao = await request(app).post(`/livros/${id}/devolucao`);
    expect(devolucao.status).toBe(200);
    expect(devolucao.body.emprestimo).toBeNull();

    const segundaDevolucao = await request(app).post(`/livros/${id}/devolucao`);
    expect(segundaDevolucao.status).toBe(409);

    expect((await request(app).delete(`/livros/${id}`)).status).toBe(204);
    expect((await request(app).get(`/livros/${id}`)).status).toBe(404);
  });

  test('rota desconhecida devolve 404 em JSON', async () => {
    const resposta = await request(app).get('/nao-existe');

    expect(resposta.status).toBe(404);
    expect(resposta.body).toEqual({ erro: 'rota não encontrada' });
  });

  test('erro inesperado devolve 500 sem vazar detalhes', async () => {
    const repositorioQuebrado = {
      listar() {
        throw new Error('disco cheio');
      },
    };
    const appQuebrado = criarApp({ repositorio: repositorioQuebrado });
    const silenciar = jest.spyOn(console, 'error').mockImplementation(() => {});

    const resposta = await request(appQuebrado).get('/livros');

    expect(resposta.status).toBe(500);
    expect(resposta.body).toEqual({ erro: 'erro interno' });
    silenciar.mockRestore();
  });
});
