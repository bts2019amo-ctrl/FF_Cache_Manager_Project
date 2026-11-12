# FF Cache Manager iOS

Projeto iOS em Objective‑C/Swift para gerenciamento de cache e integração com o backend `worse_query`.

## GitHub Actions

O workflow `.github/workflows/macos-build.yml` usa um runner `macos-14` e executa automaticamente:

- validação dos arquivos plist;
- teste de política de versões/builds;
- verificação de sintaxe Python;
- compilação integral do IPA sem assinatura, quando o segredo `FILZA_DONOR_IPA_B64` estiver configurado no repositório.

## Dependência para o IPA completo

O ZIP original não inclui `donors/FilzaSlop_1.0.3.ipa`, necessário pelos scripts de build para extrair a bridge protegida. Por isso, o workflow sempre executa a validação no macOS, mas só inicia o job de IPA quando o administrador configurar o segredo `FILZA_DONOR_IPA_B64` com o conteúdo desse arquivo codificado em Base64.

Para gerar o valor localmente:

```sh
base64 -i FilzaSlop_1.0.3.ipa | pbcopy
```

Depois, crie o segredo com esse valor em **Settings → Secrets and variables → Actions**. O arquivo não deve ser commitado no repositório.

O IPA gerado é intencionalmente não assinado. A assinatura e o provisionamento devem ser feitos separadamente com uma identidade e um App Group válidos. A validação em dispositivo real não é realizada pelo GitHub Actions.

## Teste local da política

```sh
cc -std=c11 -Wall -Wextra -Werror \
  tests/test_worse_query_policy.c FFWorseQuery.m \
  -framework Foundation -o /tmp/ff-wq-policy
/tmp/ff-wq-policy
```

Consulte `JAILBROKEN_AND_BUILD_GUIDE.txt`, `FILZA_WORSE_QUERY_README.md` e `CLEAN_BUILD_README.md` para os detalhes técnicos do projeto.
