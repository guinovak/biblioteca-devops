// Livros guardados em memória (somem quando a API reinicia)
function criarRepositorioEmMemoria() {
  const livros = new Map();
  let proximoId = 1;

  return {
    listar() {
      return [...livros.values()];
    },

    buscarPorId(id) {
      return livros.get(id) ?? null;
    },

    inserir(dados) {
      const livro = { id: proximoId++, ...dados };
      livros.set(livro.id, livro);
      return livro;
    },

    // altera só os campos enviados
    atualizar(id, dados) {
      const atual = livros.get(id);
      if (!atual) return null;
      const atualizado = { ...atual, ...dados, id };
      livros.set(id, atualizado);
      return atualizado;
    },

    // troca o livro inteiro (PUT)
    substituir(id, livro) {
      if (!livros.has(id)) return null;
      const novo = { ...livro, id };
      livros.set(id, novo);
      return novo;
    },

    remover(id) {
      return livros.delete(id);
    },
  };
}

module.exports = { criarRepositorioEmMemoria };
