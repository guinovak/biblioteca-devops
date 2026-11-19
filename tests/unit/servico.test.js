const { criarRepositorioEmMemoria } = require('../../src/livros/repositorio');
const {
  criarServicoDeLivros,
  validarDadosDoLivro,
  ErroDeValidacao,
  NaoEncontrado,
  Conflito,
} = require('../../src/livros/servico');

function novoServico() {
  return criarServicoDeLivros(criarRepositorioEmMemoria());
}

describe('validarDadosDoLivro', () => {
  test('aceita título, autor e ano válidos e remove espaços nas pontas', () => {
    expect(validarDadosDoLivro({ titulo: '  Dom Casmurro ', autor: 'Machado de Assis', ano: 1899 }))
      .toEqual({ titulo: 'Dom Casmurro', autor: 'Machado de Assis', ano: 1899 });
  });

  test('ano é opcional', () => {
    expect(validarDadosDoLivro({ titulo: 'Iracema', autor: 'José de Alencar' }))
      .toEqual({ titulo: 'Iracema', autor: 'José de Alencar' });
  });

  test.each([
    [{ autor: 'Alguém' }, /titulo é obrigatório/],
    [{ titulo: '   ', autor: 'Alguém' }, /titulo é obrigatório/],
    [{ titulo: 'Livro' }, /autor é obrigatório/],
    [{ titulo: 'Livro', autor: 'Alguém', ano: 1200 }, /ano deve ser um inteiro/],
    [{ titulo: 'Livro', autor: 'Alguém', ano: 1999.5 }, /ano deve ser um inteiro/],
    [{ titulo: 'Livro', autor: 'Alguém', ano: '1999' }, /ano deve ser um inteiro/],
    [undefined, /titulo é obrigatório; autor é obrigatório/],
  ])('rejeita %j', (dados, mensagem) => {
    expect(() => validarDadosDoLivro(dados)).toThrow(ErroDeValidacao);
    expect(() => validarDadosDoLivro(dados)).toThrow(mensagem);
  });

  test('rejeita ano no futuro', () => {
    const anoQueVem = new Date().getFullYear() + 1;
    expect(() => validarDadosDoLivro({ titulo: 'Livro', autor: 'Alguém', ano: anoQueVem }))
      .toThrow(ErroDeValidacao);
  });
});

describe('cadastro de livros', () => {
  test('cadastra com id sequencial e disponível para empréstimo', () => {
    const servico = novoServico();
    const primeiro = servico.cadastrar({ titulo: 'A', autor: 'X' });
    const segundo = servico.cadastrar({ titulo: 'B', autor: 'Y' });

    expect(primeiro).toMatchObject({ id: 1, emprestimo: null });
    expect(segundo.id).toBe(2);
    expect(servico.listar()).toHaveLength(2);
  });

  test('obter livro inexistente lança NaoEncontrado', () => {
    expect(() => novoServico().obter(99)).toThrow(NaoEncontrado);
  });

  test('atualizar mantém o empréstimo em andamento', () => {
    const servico = novoServico();
    const { id } = servico.cadastrar({ titulo: 'A', autor: 'X' });
    servico.emprestar(id, { leitor: 'Ana' });

    const atualizado = servico.atualizar(id, { titulo: 'A (2ª edição)', autor: 'X' });

    expect(atualizado.titulo).toBe('A (2ª edição)');
    expect(atualizado.emprestimo.leitor).toBe('Ana');
  });

  test('atualizar substitui o livro inteiro: ano que não veio é retirado', () => {
    const servico = novoServico();
    const { id } = servico.cadastrar({ titulo: 'A', autor: 'X', ano: 1990 });

    const atualizado = servico.atualizar(id, { titulo: 'A', autor: 'X' });

    expect(atualizado).not.toHaveProperty('ano');
    expect(servico.obter(id)).not.toHaveProperty('ano');
  });

  test('atualizar livro inexistente lança NaoEncontrado', () => {
    expect(() => novoServico().atualizar(7, { titulo: 'A', autor: 'X' })).toThrow(NaoEncontrado);
  });

  test('não remove livro emprestado', () => {
    const servico = novoServico();
    const { id } = servico.cadastrar({ titulo: 'A', autor: 'X' });
    servico.emprestar(id, { leitor: 'Ana' });

    expect(() => servico.remover(id)).toThrow(Conflito);
  });

  test('remove livro disponível', () => {
    const servico = novoServico();
    const { id } = servico.cadastrar({ titulo: 'A', autor: 'X' });

    servico.remover(id);

    expect(servico.listar()).toEqual([]);
  });
});

describe('empréstimo e devolução', () => {
  test('empresta para o leitor e registra a data', () => {
    const servico = novoServico();
    const { id } = servico.cadastrar({ titulo: 'A', autor: 'X' });

    const livro = servico.emprestar(id, { leitor: ' Ana ' });

    expect(livro.emprestimo.leitor).toBe('Ana');
    expect(new Date(livro.emprestimo.data).toString()).not.toBe('Invalid Date');
  });

  test('exige o nome do leitor', () => {
    const servico = novoServico();
    const { id } = servico.cadastrar({ titulo: 'A', autor: 'X' });

    expect(() => servico.emprestar(id, {})).toThrow(ErroDeValidacao);
    expect(() => servico.emprestar(id)).toThrow(ErroDeValidacao);
  });

  test('não empresta livro já emprestado', () => {
    const servico = novoServico();
    const { id } = servico.cadastrar({ titulo: 'A', autor: 'X' });
    servico.emprestar(id, { leitor: 'Ana' });

    expect(() => servico.emprestar(id, { leitor: 'Bruno' })).toThrow(Conflito);
  });

  test('devolve e o livro volta a ficar disponível', () => {
    const servico = novoServico();
    const { id } = servico.cadastrar({ titulo: 'A', autor: 'X' });
    servico.emprestar(id, { leitor: 'Ana' });

    expect(servico.devolver(id).emprestimo).toBeNull();
    expect(servico.listar({ disponivel: true })).toHaveLength(1);
  });

  test('não devolve livro que não está emprestado', () => {
    const servico = novoServico();
    const { id } = servico.cadastrar({ titulo: 'A', autor: 'X' });

    expect(() => servico.devolver(id)).toThrow(Conflito);
  });

  test('filtra disponíveis e emprestados', () => {
    const servico = novoServico();
    const a = servico.cadastrar({ titulo: 'A', autor: 'X' });
    servico.cadastrar({ titulo: 'B', autor: 'Y' });
    servico.emprestar(a.id, { leitor: 'Ana' });

    expect(servico.listar({ disponivel: true }).map((l) => l.titulo)).toEqual(['B']);
    expect(servico.listar({ disponivel: false }).map((l) => l.titulo)).toEqual(['A']);
  });
});
