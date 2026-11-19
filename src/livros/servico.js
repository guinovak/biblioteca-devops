/**
 * Regras de negócio da biblioteca: cadastro de livros, empréstimo e devolução.
 * Não conhece HTTP; quem traduz para status e JSON são as rotas.
 */

class ErroDeValidacao extends Error {}
class NaoEncontrado extends Error {}
class Conflito extends Error {}

const ANO_MINIMO = 1450; // prensa de Gutenberg

function validarDadosDoLivro(dados) {
  const erros = [];
  const { titulo, autor, ano } = dados ?? {};

  if (typeof titulo !== 'string' || titulo.trim() === '') {
    erros.push('titulo é obrigatório');
  }
  if (typeof autor !== 'string' || autor.trim() === '') {
    erros.push('autor é obrigatório');
  }
  if (ano !== undefined) {
    const anoAtual = new Date().getFullYear();
    if (!Number.isInteger(ano) || ano < ANO_MINIMO || ano > anoAtual) {
      erros.push(`ano deve ser um inteiro entre ${ANO_MINIMO} e ${anoAtual}`);
    }
  }

  if (erros.length > 0) {
    throw new ErroDeValidacao(erros.join('; '));
  }

  return {
    titulo: titulo.trim(),
    autor: autor.trim(),
    ...(ano !== undefined && { ano }),
  };
}

function criarServicoDeLivros(repositorio) {
  function obter(id) {
    const livro = repositorio.buscarPorId(id);
    if (!livro) throw new NaoEncontrado(`livro ${id} não encontrado`);
    return livro;
  }

  return {
    listar({ disponivel } = {}) {
      const livros = repositorio.listar();
      if (disponivel === undefined) return livros;
      return livros.filter((livro) => (livro.emprestimo === null) === disponivel);
    },

    obter,

    cadastrar(dados) {
      const livro = validarDadosDoLivro(dados);
      return repositorio.inserir({ ...livro, emprestimo: null });
    },

    atualizar(id, dados) {
      const atual = obter(id);
      const livro = validarDadosDoLivro(dados);
      return repositorio.substituir(id, { ...livro, emprestimo: atual.emprestimo });
    },

    remover(id) {
      const livro = obter(id);
      if (livro.emprestimo) {
        throw new Conflito('livro emprestado não pode ser removido');
      }
      repositorio.remover(id);
    },

    emprestar(id, { leitor } = {}) {
      const livro = obter(id);
      if (typeof leitor !== 'string' || leitor.trim() === '') {
        throw new ErroDeValidacao('leitor é obrigatório');
      }
      if (livro.emprestimo) {
        throw new Conflito('livro já está emprestado');
      }
      return repositorio.atualizar(id, {
        emprestimo: { leitor: leitor.trim(), data: new Date().toISOString() },
      });
    },

    devolver(id) {
      const livro = obter(id);
      if (!livro.emprestimo) {
        throw new Conflito('livro não está emprestado');
      }
      return repositorio.atualizar(id, { emprestimo: null });
    },
  };
}

module.exports = {
  criarServicoDeLivros,
  validarDadosDoLivro,
  ErroDeValidacao,
  NaoEncontrado,
  Conflito,
};
