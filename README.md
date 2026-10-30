# App Casas

Aplicativo Flutter em português do Brasil para procurar, anunciar e gerenciar imóveis para aluguel e venda. A interface se adapta a celulares e telas maiores. O workflow do GitHub compila um APK Android e uma versão web.

## O que já está no aplicativo

- Busca sem login por aluguel ou compra, bairro/cidade/CEP, categoria, preço e quartos.
- Localização do aparelho somente após a pessoa tocar em **Usar localização** e autorizar. A busca digitada continua disponível se a permissão for recusada.
- Categorias: apartamento, kitnet/studio, casa e casa em condomínio.
- Página do imóvel com fotos, preço, localização, descrição e informações disponíveis.
- Anúncio em quatro etapas, com seleção e reorganização de até dez fotos.
- Opção para divulgar o endereço completo ou somente bairro e cidade.
- Autorização explícita para mostrar o telefone e escolha separada para indicar se ele também recebe WhatsApp. Telefone e endereço privado ficam em documentos separados dos dados públicos do anúncio.
- Conta Google para publicar, editar, pausar, reativar, marcar como alugado/vendido, remover, salvar e denunciar anúncios.
- Link para abrir a região no OpenStreetMap. A posição opcional do anúncio é aproximada.
- Estados de carregamento, erro e ausência de resultados.

## Modo demonstração

Sem configuração Firebase, o app abre em **Modo demonstração** com três anúncios de exemplo. A busca e as telas de detalhes podem ser testadas, mas os dados não são ofertas reais. Login, publicação, favoritos, contato e denúncias exigem Firebase configurado e não são simulados.

## Configurar Firebase

1. Crie um projeto em [Firebase Console](https://console.firebase.google.com/).
2. Adicione o app Android com o identificador `br.com.appcasas.app_casas`.
3. Em Authentication, habilite o provedor **Google**. Cadastre as impressões digitais SHA-1 e SHA-256 do certificado Android que assinará o APK.
4. Crie um banco Cloud Firestore e um bucket do Firebase Storage.
5. Publique as regras deste repositório:

   ```sh
   firebase use --add
   firebase deploy --only firestore:rules,storage
   ```

6. No repositório, acesse **Settings → Secrets and variables → Actions** e crie:

   | Secret | Onde encontrar |
   |---|---|
   | `FIREBASE_API_KEY` | Configuração do app Android no Firebase |
   | `FIREBASE_APP_ID` | Configuração do app Android no Firebase |
   | `FIREBASE_MESSAGING_SENDER_ID` | Configuração do projeto Firebase |
   | `FIREBASE_PROJECT_ID` | ID do projeto Firebase |
   | `GOOGLE_SERVER_CLIENT_ID` | OAuth Client ID do tipo Web, usado pelo Google Sign-In Android |
   | `FIREBASE_STORAGE_BUCKET` | Nome do bucket criado no Firebase Storage |
   | `FIREBASE_AUTH_DOMAIN` | Domínio de autenticação Firebase, necessário para login na versão web |

   Não coloque senhas, chaves privadas ou tokens de usuário nesses campos. Os valores públicos de configuração do Firebase não substituem as regras de segurança.

O APK consegue carregar anúncios depois de configurar os quatro valores básicos do Firebase. Para publicar fotos, configure também Storage e `FIREBASE_STORAGE_BUCKET`. O login Android precisa de `GOOGLE_SERVER_CLIENT_ID`; o login web precisa de `FIREBASE_AUTH_DOMAIN`. Nenhuma credencial é incluída no repositório.

## Assinatura Android do APK no GitHub Actions

Para assinar o APK com o certificado cadastrado no Firebase, crie estes quatro Secrets em **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Conteúdo Base64 do arquivo JKS |
| `ANDROID_KEYSTORE_PASSWORD` | Senha do keystore |
| `ANDROID_KEY_ALIAS` | `app-casas` |
| `ANDROID_KEY_PASSWORD` | Senha da chave desse alias |

No PowerShell do computador onde está o arquivo `%USERPROFILE%\app-casas-release.jks`, copie o conteúdo Base64 para a área de transferência:

```powershell
$keystorePath = Join-Path $env:USERPROFILE 'app-casas-release.jks'
if (-not (Test-Path -LiteralPath $keystorePath)) {
    throw "Keystore não encontrado: $keystorePath"
}
[Convert]::ToBase64String([IO.File]::ReadAllBytes($keystorePath)) | Set-Clipboard
```

Cole o conteúdo da área de transferência somente no valor de `ANDROID_KEYSTORE_BASE64` no GitHub. Preencha as outras três Secrets diretamente no GitHub; não envie a JKS, o Base64 ou senhas pelo chat. Depois de salvar, limpe a área de transferência com `Set-Clipboard -Value ''`.

O workflow decodifica o JKS somente no runner, valida o alias e não inclui o arquivo nos artefatos. Builds de pull request não recebem as Secrets de assinatura. Se as quatro Secrets não estiverem definidas, o APK usa a chave de depuração padrão e não terá o SHA registrado no Firebase; se apenas parte delas estiver definida, a compilação para com erro.

O provedor Google do Firebase ainda está desabilitado. Antes de declarar o login funcional, abra **Firebase Console → Authentication → Sign-in method → Google**, habilite o provedor e selecione um e-mail de suporte.

## Dados e privacidade

- Anúncios ficam em `properties/{id}`. Apenas anúncios ativos são listados publicamente.
- CEP e endereço completo ficam em `propertyPrivate/{id}`. O telefone fica separado em `propertyContacts/{id}` e só pode ser lido por uma pessoa autenticada quando o anunciante marcou a autorização de divulgação.
- As regras do Firestore limitam os campos aceitos nos documentos públicos, privados e de contato; endereços completos só podem ser publicados quando a opção de divulgação estiver marcada.
- Para permitir busca por CEP sem revelar o endereço, o anúncio guarda apenas os cinco primeiros dígitos do CEP na parte pública.
- Favoritos ficam em `users/{uid}/favorites/{id}` e cada pessoa acessa somente os próprios. O nome e telefone usados nos próximos anúncios também ficam no documento privado `users/{uid}` para evitar pedir os mesmos dados novamente.
- Denúncias são gravadas em `reports`. A regra permite revisão por uma conta com a custom claim `admin`; ainda não há uma tela administrativa no aplicativo.
- Fotos são limitadas a imagens de até 10 MB. As regras permitem que cada anunciante altere apenas os próprios arquivos.
- A opção de marcar a posição usa a localização atual somente após autorização e arredonda as coordenadas para mostrar uma região aproximada.

## Executar localmente

Instale Flutter stable 3.41 ou mais recente e o Firebase CLI. Como as pastas de plataforma são geradas pelo workflow, crie as plataformas antes de executar:

```sh
flutter create --platforms=android,web --org br.com.appcasas --project-name app_casas .
flutter pub get
flutter analyze
flutter test
```

Para compilar localmente, passe os mesmos valores de configuração usando `--dart-define`. Não salve esses valores no código-fonte. A compilação Android exige a configuração de assinatura Google no Firebase para que o login funcione em um aparelho.

## APK e versão web pelo GitHub Actions

O workflow **Build Android APK** roda em pushes, pull requests e também pode ser iniciado manualmente. Ao concluir, abra a execução em **Actions** e baixe:

- `app-casas-mvp-apk`: arquivo Android `app-release.apk`.
- `app-casas-web`: site responsivo em `build/web`.

Sem os Secrets, a compilação ainda pode ser analisada, mas a aplicação continuará em modo demonstração. Para iOS, ainda é necessário gerar o projeto iOS e cadastrar as descrições de uso de câmera/fotos e localização antes de distribuir.

## Dependências Firebase e Flutter

O projeto usa as APIs atuais de `firebase_core` 5.1.0, `firebase_auth` 7.0.1, `cloud_firestore` 7.1.0, `firebase_storage` 14.0.1 e `google_sign_in` 7.2.0, além de `image_picker`, `geolocator` e `url_launcher`. Consulte as páginas oficiais para [Firebase Core](https://pub.dev/packages/firebase_core), [Firebase Auth](https://pub.dev/packages/firebase_auth), [Cloud Firestore](https://pub.dev/packages/cloud_firestore), [Firebase Storage](https://pub.dev/packages/firebase_storage) e [Google Sign-In](https://pub.dev/packages/google_sign_in).
