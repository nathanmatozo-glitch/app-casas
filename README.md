# App Casas — Flutter

Aplicativo Android para anunciar e consultar imóveis para venda e aluguel.

## Login com conta Google

O projeto inclui a tela de entrada e a integração com Firebase Authentication + Google Sign-In. Para autenticar contas reais, é necessário conectar o aplicativo a um projeto Firebase.

### 1. Criar e configurar o Firebase

1. Acesse https://console.firebase.google.com/ e crie um projeto.
2. Adicione um aplicativo Android com o identificador de pacote **br.com.appcasas.app_casas**.
3. Em Authentication > Sign-in method (Provedores de acesso), habilite **Google** e salve.
4. Cadastre no Firebase a impressão digital SHA-1 do certificado que assina o APK.
5. Na configuração do provedor Google, obtenha o OAuth Client ID do tipo Web. Esse valor será GOOGLE_SERVER_CLIENT_ID.

### 2. Cadastrar os valores no GitHub

No repositório, abra Settings > Secrets and variables > Actions > New repository secret e crie estes cinco Secrets:

| Secret | Valor |
|---|---|
| FIREBASE_API_KEY | API Key do app Android no Firebase |
| FIREBASE_APP_ID | App ID do app Android no Firebase |
| FIREBASE_MESSAGING_SENDER_ID | Sender ID do projeto Firebase |
| FIREBASE_PROJECT_ID | ID do projeto Firebase |
| GOOGLE_SERVER_CLIENT_ID | OAuth Client ID do tipo Web |

Esses valores são usados pelo workflow para compilar o APK conectado ao Firebase. Não coloque senhas de usuários ou chaves privadas nesses campos.

### 3. Gerar o APK atualizado

Depois de salvar os Secrets, acesse Actions > Build Android APK e execute Run workflow (ou envie um novo commit para a branch main). Quando a execução terminar com sucesso, baixe o artefato app-casas-mvp-apk.

### 4. O que o login faz

- Abre a seleção de conta Google no Android.
- Autentica a identidade no Firebase Authentication.
- Cria o cadastro do usuário no primeiro acesso.
- Mantém a sessão entre aberturas do aplicativo.
- Mostra a tela de imóveis somente depois da autenticação.
- Permite sair da conta pelo menu do perfil.

## Build

A compilação e os testes são executados automaticamente em .github/workflows/build-apk.yml.

**Observação:** enquanto os Secrets do Firebase não forem cadastrados, o APK exibirá a tela de login e avisará que a configuração está pendente. Isso é intencional: não há autenticação simulada nem armazenamento de senhas no aplicativo.
