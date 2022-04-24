# manga-cli-br

Script em Bash para ler mangá usando seu terminal!
<br>
Inspirado (ou seja, uma parte do código veio de lá rs) no [manga-cli](https://github.com/7USTIN/manga-cli).
<br>
Agradecimentos ao [Rosialdo](https://github.com/Rosialdo) que ajudou nos testes.

## Índice

- [Uso](#uso)
- [Instalação](#instalação)
- [Dependências](#dependências)
- [Aviso](./DISCLAIMER.md)
- [Licença](./LICENSE.md)

## Uso

```text
    COMO USAR: manga-cli-br [Opção]

    OPÇÕES:
    -h ou --help: mostra esta tela
    -v ou --version: mostra a versão do script
    -d ou --debug: não exclui os arquivos temporários gerados pelo script

    COMO SAIR DO LEITOR DE PDF:
    aperte q
```

## Instalação

### Linux

```sh
git clone https://github.com/ed-henrique/manga-cli-br && cd manga-cli-br
sudo cp manga-cli-br /usr/local/bin/manga-cli-br
```

## Dependências

- GNU coreutils (cat, mkdir, rm, tr)
- GNU gawk (awk)
- GNU sed
- curl
- git
- img2pdf
- zathura
