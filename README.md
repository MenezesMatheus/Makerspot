# MakerSpot

**MakerSpot** é um app iOS para descobrir e compartilhar **espaços e eventos da comunidade maker**. Usuários podem explorar publicações, buscar Spots, salvar os que interessam e divulgar os próprios espaços e eventos.

O aplicativo é desenvolvido em **SwiftUI**. Os dados compartilhados ficam no **CloudKit**; os Spots salvos também têm persistência local para responder imediatamente às ações do usuário.

---

## Conceitos centrais

| Conceito | O que é |
|---|---|
| **Spot** | Uma publicação criada por um usuário. Reúne nome, descrição, endereço, contatos, fotos e informações específicas do seu tipo. |
| **Evento** | Um Spot com data de início, data de término e fuso horário. Eventos encerrados deixam de aparecer nas listagens de Spots disponíveis. |
| **Espaço** | Um Spot com dias e intervalos de funcionamento, inclusive horários que terminam no dia seguinte. |
| **Usuário** | Perfil associado à autenticação com a Apple e à conta iCloud usada pelo aplicativo. |
| **Spot salvo** | Um Spot marcado pelo usuário para consultar depois. Guarda também a última versão visualizada para identificar atualizações. |
| **Denúncia** | Relato enviado sobre um Spot, que pode ser analisado no fluxo de moderação. |

---

## Funcionalidades

### Descoberta e busca

A aba **Spots** apresenta eventos e espaços em destaque, com acesso às listagens completas. A busca permite encontrar publicações pelo texto informado. As listagens usam paginação para carregar mais registros conforme a navegação.

Somente Spots ativos e disponíveis aparecem para descoberta. Um evento cuja data de término já passou não é tratado como disponível, mesmo que ainda exista no banco.

### Publicação de eventos e espaços

O usuário pode cadastrar, editar e excluir os próprios Spots. Um evento informa seu período de realização; um espaço informa seus dias e horários de funcionamento. O endereço é convertido em coordenadas para integração com o app Mapas.

As regras são validadas no backend do aplicativo: o término de um evento precisa ocorrer depois do início, os fusos horários devem ser válidos e os intervalos de funcionamento de um espaço não podem se sobrepor.

O Spot é criado antes da conclusão do envio de suas fotos. Os arquivos pendentes são guardados temporariamente no aparelho, e o aplicativo tenta retomar o envio quando necessário.

### Salvos

Salvar ou remover um Spot dos salvos atualiza primeiro o estado persistido no aparelho. A interface responde sem esperar a rede, enquanto o **SwiftData** sincroniza os registros pelo CloudKit privado.

O aplicativo mantém uma cópia dos dados do Spot salvo para exibi-lo durante a consulta local. Quando recebe atualizações, compara a versão atual do Spot com a última versão visualizada pelo usuário.

### Conta e perfil

A entrada usa **Iniciar sessão com a Apple**. O identificador necessário para restaurar a sessão é guardado no **Keychain**. O perfil permite atualizar informações e foto, consultar as próprias publicações, encerrar a sessão e excluir a conta.

A cada operação protegida, o aplicativo verifica se a conta iCloud corresponde ao perfil autenticado e se a conta está apta a usar o serviço.

### Fotos, denúncias e notificações

Antes de anexar uma foto, o aplicativo valida o arquivo e usa **SensitiveContentAnalysis** para verificar conteúdo sensível.

Usuários podem denunciar Spots de outras pessoas. O aplicativo também apresenta avisos de moderação e restrição de publicações. As notificações incluem lembretes de eventos salvos ou organizados pelo usuário.

---

## Arquitetura

A interface é organizada por telas com `View` e `ViewModel`. As entidades, validações, operações de dados e integrações ficam em `Backend/`.

| Pasta ou arquivo | Responsabilidade |
|---|---|
| `MakerSpotApp.swift` | Fluxo inicial: onboarding, restauração da sessão, login e navegação principal. |
| `TabBarView.swift` | Abas Spots, Salvos, Perfil e Busca. |
| `Backend/Entidades/` | Modelos de Spot, evento, espaço, usuário, foto, localização e moderação. |
| `Backend/CRUD/` | Operações sobre usuários, Spots, fotos, salvos e denúncias; autorização e validação. |
| `Backend/CloudKit/` | Acesso aos bancos do CloudKit, tipos de registro, conversões, assinaturas e esquema. |
| `Backend/Services/` | Sessão, autenticação, localização, persistência dos salvos, envio de fotos e análise de imagens. |
| `Views/Telas/` | Telas navegáveis e seus `ViewModels`. |
| `Views/Componentes/` | Cards, botões e outros elementos reutilizáveis. |
| `Views/Sheets/` e `Views/PopUP-Pickers/` | Formulários modais, confirmações e seletores. |
| `Notificacoes/` | Coordenação, roteamento e modelos de notificações. |

### Fluxo dos dados

```text
Views → ViewModels → CRUD / Services
                         ├── ClienteCloudKit → bancos público e privado
                         └── SalvosLocais → SwiftData → CloudKit privado
```

O `ClienteCloudKit` concentra o acesso aos registros remotos. Os conversores traduzem `CKRecord` para as entidades usadas pelo restante do aplicativo.

---

## 🗃 Modelo de dados

```text
Usuário ── publica ──< Spot ── pode ser ── Evento
                         │          └──── Espaço
                         ├──< Fotos
                         ├──< Denúncias
                         └──< Spots salvos por outros usuários
```

`Spot` é o modelo comum aos dois tipos de publicação. Ele guarda os dados compartilhados, enquanto `Evento` contém datas e `Espaco` contém o funcionamento semanal.

O CloudKit separa registros conforme sua finalidade: publicações, fotos de Spots e denúncias usam o **banco público**; dados de usuário e registros privados usam o **banco privado**. Os salvos atuais são persistidos localmente com SwiftData e sincronizados com o CloudKit privado.

---

## Decisões de arquitetura

- **Um modelo comum para eventos e espaços.** `Spot` concentra identidade, proprietário, localização, contatos e fotos. O enum `DetalhesSpot` mantém os dados específicos de cada tipo.

- **Validação fora das telas.** `ValidadorSpotCRUD` normaliza e valida os dados de cadastro e edição. O CRUD também verifica a sessão, a conta iCloud, a propriedade do Spot e eventuais restrições antes de operações protegidas.

- **CloudKit encapsulado.** Views e ViewModels trabalham com entidades Swift. `ClienteCloudKit`, a configuração e os conversores cuidam dos registros remotos e da escolha entre banco público e privado.

- **Salvos com escrita local imediata.** A ação do usuário é gravada em SwiftData antes da sincronização. Isso mantém a interface responsiva e preserva a alteração local quando o iCloud está temporariamente indisponível.

- **Envio de fotos recuperável.** O cadastro do Spot não precisa aguardar todas as fotos. Arquivos e um manifesto de envio pendente permitem retomar a operação depois.

- **Análise antes de anexar imagens.** A verificação de conteúdo sensível acontece antes de a foto entrar no fluxo de publicação.

- **Sessão protegida e vinculada à conta.** O identificador de autenticação fica no Keychain. O aplicativo confere a conta CloudKit em uso e limpa os dados de sessão quando ela é encerrada ou bloqueada.

- **Atualização por versões.** Cada Spot possui um número de versão; os salvos registram a última versão conhecida para indicar quando uma publicação foi atualizada.

---

## Tecnologias

- **Swift / SwiftUI** — interface e navegação.
- **CloudKit** — armazenamento e sincronização de dados.
- **SwiftData** — persistência local dos Spots salvos.
- **AuthenticationServices e Keychain** — autenticação com a Apple e restauração segura da sessão.
- **MapKit e Core Location** — busca de coordenadas e abertura de endereços no Mapas.
- **PhotosUI e SensitiveContentAnalysis** — seleção e análise de fotos.
- **UserNotifications** — lembretes e avisos.

---

## Time
**[Matheus Menezes](https://github.com/MenezesMatheus)** · **[Maria Júlia Alves Sales](https://github.com/Salesmaju)** · **[Amanda de Morais Silva](https://github.com/amandemorais)** · **[biancaduartemg](https://github.com/biancaduartemg)**
