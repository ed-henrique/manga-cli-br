# manga-cli-br

Script em Bash para ler mangá usando seu terminal!
<br>
Baseado no [manga-cli](https://github.com/7USTIN/manga-cli)
<br>
Agradecimentos ao [Rosialdo](https://github.com/Rosialdo) por ajudar nos testes.
<br>
<br>
**NESSE MOMENTO ESTOU VERIFICANDO A POSSIBILIDADE DE MIGRAR DO MUITOMANGA PARA O MANGALIVRE, TANTO PARA DAR ACESSO A UM MAIOR NÚMERO DE MANGÁS QUANTO PARA RESOLVER O PROBLEMA DE DISPOSIÇÃO DAS IMAGENS NO PDF, PRINCIPALMENTE EM WEBTOONS.**
<br>
**SE ALGUÉM SOUBER COMO POSSO PASSAR UM REQUEST PELO CLOUDFLARE SEM TOMAR UM 403, ME FALA, PARA QUE EU POSSA CONSEGUIR REALIZAR ESSA MIGRAÇÃO.**

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