# FF Cache Manager iOS

Projeto iOS em Objective‑C/Swift para gerenciamento de cache e integração com o backend `worse_query`.

## GitHub Actions

O workflow `.github/workflows/macos-build.yml` usa um runner `macos-15` e executa automaticamente:

- validação dos arquivos plist;
- teste de política de versões/builds;
- verificação de sintaxe Python;
- download e verificação SHA-256 da donor oficial FilzaSlop v1.0.3;
- compilação integral do IPA sem assinatura a partir deste projeto, incluindo Match State, Auto Toggle e perfis AutoCache;
- publicação da IPA e dos manifests como artefatos do Actions.

## Dependência para o IPA completo

O ZIP original não incluía `donors/FilzaSlop_1.0.3.ipa`, necessário para extrair a bridge protegida. O workflow agora baixa a versão oficial da release v1.0.3, verifica o SHA-256 publicado e usa `build_macos_full.sh` para compilar a variante completa com o SDK do Xcode. A variante CLEAN continua disponível separadamente em `build_macos.sh`.

O IPA gerado é intencionalmente não assinado. A assinatura e o provisionamento devem ser feitos separadamente com uma identidade e um App Group válidos. A validação em dispositivo real não é realizada pelo GitHub Actions.

## Teste local da política

```sh
cc -std=c11 -Wall -Wextra -Werror \
  tests/test_worse_query_policy.c FFWorseQuery.m \
  -framework Foundation -o /tmp/ff-wq-policy
/tmp/ff-wq-policy
```

Consulte `JAILBROKEN_AND_BUILD_GUIDE.txt`, `FILZA_WORSE_QUERY_README.md` e `CLEAN_BUILD_README.md` para os detalhes técnicos do projeto.
