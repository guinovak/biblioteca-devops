/**
 * Repositório de livros em memória.
 *
 * Na Fase 1 os dados vivem só enquanto o processo está de pé: o foco da fase é
 * o pipeline e a infraestrutura, não a persistência. Trocar por um banco de
 * verdade (ex.: DynamoDB ou RDS) só exige outra implementação com os mesmos
 * métodos.
 */
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

    // Mescla só os campos informados (usado no empréstimo e na devolução)
    atualizar(id, dados) {
      const atual = livros.get(id);
      if (!atual) return null;
      const atualizado = { ...atual, ...dados, id };
      livros.set(id, atualizado);
      return atualizado;
    },

    // Troca o livro inteiro: campo que não veio deixa de existir (usado no PUT)
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
