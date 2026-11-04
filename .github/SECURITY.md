# Segurança do HexGym

Este arquivo diz como avisar de uma falha de segurança no HexGym sem que ela fique pública antes da correção.

## Como avisar

Não abra uma issue, não comente num pull request e não conte a falha em nenhum lugar público: as issues e os pull requests deste repositório são abertos a qualquer pessoa.

Use o relato privado do GitHub: na aba [Security](https://github.com/lipedesign/HexGym/security) do repositório, clique em "Report a vulnerability". Pelo GitHub, o relato fica visível só para você e para quem cuida do repositório, e é nele que a correção é conversada.

## O que ajuda no relato

- a versão do app e o build do TestFlight, ou a branch e o commit, se for um build do Xcode;
- o aparelho e o sistema, como o modelo do iPhone e a versão do iOS, ou do Apple Watch e do watchOS;
- os passos para chegar na falha, o mais preciso que der;
- o que alguém consegue fazer com ela.

Não anexe as fotos nem as animações de exercício da Gym visual: o trabalho do HexGym é feito por agentes de IA, e essas mídias não podem passar por eles.

## O que vale aqui

O HexGym está em construção e ainda não tem versão publicada. As correções entram na `develop`, como todo o trabalho, e chegam na versão seguinte.

O HexGym é um fork do openGym, e boa parte do código veio de lá: o motor com as regras de treino, o servidor e o app web. Se a falha também existe no openGym, a política de segurança dele está no [SECURITY.md do openGym](https://github.com/DuarteSantos8/openGym/blob/main/SECURITY.md).

Não há prazo de resposta nem programa de recompensa.
