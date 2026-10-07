enum PoliticaPrivacidade {
    static let titulo = "Política de Privacidade"
    static let ultimaAtualizacao = "Última atualização: 30/09/2026"
    static let ultimaAtualizacaoNoRodape = "Última atualização: 30 set. 2026"
    static let introducao = [
        "A presente Política de Privacidade descreve como o aplicativo Makerspot coleta, utiliza, armazena e protege os dados pessoais de seus usuários.",
        "Ao utilizar o aplicativo, o usuário declara estar ciente das práticas descritas nesta Política.",
    ]

    struct Secao {
        let titulo: String
        let blocos: [Bloco]
    }

    enum Bloco {
        case paragrafo(String)
        case subtitulo(String)
        case lista([String])
    }

    static let secoes: [Secao] = [
        Secao(
            titulo: "1. Dados que coletamos",
            blocos: [
                .paragrafo("Para disponibilizar as funcionalidades do aplicativo, podemos coletar e tratar os seguintes dados:"),
                .subtitulo("1.1. Dados de autenticação"),
                .paragrafo("O aplicativo utiliza o recurso Sign in with Apple para permitir que o usuário crie uma conta e realize sua autenticação."),
                .paragrafo("Nesse processo, podemos receber da Apple informações necessárias para identificar e autenticar o usuário, como:"),
                .lista([
                    "nome, quando disponibilizado;",
                    "endereço de e-mail;",
                    "identificador associado à conta do usuário;",
                    "informações necessárias para autenticação fornecidas pelo serviço Sign in with Apple.",
                ]),
                .paragrafo("O aplicativo não recebe nem armazena a senha utilizada pelo usuário em sua conta Apple."),
                .paragrafo("O usuário também poderá optar por ocultar seu endereço de e-mail por meio do recurso de privacidade disponibilizado pela Apple. Nesse caso, poderemos receber um endereço de e-mail privado fornecido pela Apple."),
                .subtitulo("1.2. Foto de perfil"),
                .paragrafo("O aplicativo permite que o usuário adicione uma foto ao seu perfil."),
                .paragrafo("Para essa finalidade, o aplicativo poderá solicitar acesso às fotos disponíveis no dispositivo. O usuário poderá selecionar a imagem que deseja utilizar como foto de perfil."),
                .paragrafo("A imagem selecionada poderá ser armazenada e processada por meio do CloudKit, serviço de armazenamento e infraestrutura fornecido pela Apple, para possibilitar o funcionamento da conta e a exibição da foto de perfil no aplicativo."),
                .paragrafo("O aplicativo não utiliza as demais fotografias existentes na biblioteca do dispositivo para outras finalidades."),
                .subtitulo("1.3. Notificações push"),
                .paragrafo("O aplicativo utiliza notificações push para enviar informações relacionadas ao funcionamento e aos serviços disponibilizados pela plataforma."),
                .paragrafo("As notificações podem incluir, conforme as funcionalidades disponíveis no aplicativo:"),
                .lista([
                    "lembretes;",
                    "atualizações;",
                    "mensagens;",
                    "alterações em informações ou serviços;",
                    "outras comunicações relacionadas à utilização do aplicativo.",
                ]),
                .paragrafo("O envio de notificações depende da autorização concedida pelo usuário no dispositivo."),
                .paragrafo("O usuário pode alterar ou revogar essa autorização a qualquer momento nas configurações do dispositivo."),
            ]
        ),
        Secao(
            titulo: "2. Como utilizamos os dados",
            blocos: [
                .paragrafo("Os dados coletados podem ser utilizados para:"),
                .lista([
                    "criar e gerenciar a conta do usuário;",
                    "autenticar o usuário;",
                    "disponibilizar as funcionalidades do aplicativo;",
                    "identificar o usuário dentro da plataforma;",
                    "armazenar e disponibilizar a foto de perfil;",
                    "enviar notificações push;",
                    "manter o funcionamento e a segurança do aplicativo;",
                    "prestar suporte ao usuário;",
                    "permitir a utilização dos serviços disponibilizados pelo aplicativo;",
                    "cumprir obrigações legais e regulatórias aplicáveis.",
                ]),
                .paragrafo("Os dados não serão utilizados para finalidades incompatíveis com aquelas descritas nesta Política de Privacidade."),
            ]
        ),
        Secao(
            titulo: "3. Armazenamento dos dados",
            blocos: [
                .paragrafo("Os dados utilizados pelo aplicativo podem ser armazenados por meio do CloudKit, serviço disponibilizado pela Apple para armazenamento e gerenciamento de dados associados a aplicativos."),
                .paragrafo("Os dados armazenados poderão incluir informações necessárias ao funcionamento da conta, como informações de identificação, dados associados ao perfil e foto de perfil, quando fornecida pelo usuário."),
                .paragrafo("O tratamento e armazenamento dos dados também estão sujeitos às políticas e aos termos aplicáveis da Apple."),
            ]
        ),
        Secao(
            titulo: "4. Compartilhamento de dados",
            blocos: [
                .paragrafo("Os dados pessoais poderão ser tratados por prestadores de serviços e tecnologias necessárias para o funcionamento do aplicativo."),
                .paragrafo("O aplicativo utiliza serviços da Apple, incluindo:"),
                .lista([
                    "Sign in with Apple, para autenticação;",
                    "CloudKit, para armazenamento e gerenciamento dos dados;",
                    "serviços de notificação da Apple, para envio de notificações push.",
                ]),
                .paragrafo("Não vendemos os dados pessoais dos usuários."),
                .paragrafo("Os dados também poderão ser divulgados quando necessário para cumprir obrigações legais, determinações judiciais ou solicitações de autoridades competentes, nos termos da legislação aplicável."),
            ]
        ),
        Secao(
            titulo: "5. Permissões do dispositivo",
            blocos: [
                .paragrafo("O aplicativo pode solicitar determinadas permissões para disponibilizar suas funcionalidades."),
                .subtitulo("Fotos"),
                .paragrafo("A permissão de acesso às fotos é utilizada para permitir que o usuário selecione uma imagem para utilizar como foto de perfil."),
                .paragrafo("O usuário poderá negar ou alterar essa permissão nas configurações do dispositivo."),
                .subtitulo("Notificações"),
                .paragrafo("A permissão de notificações é utilizada para possibilitar o envio de notificações push relacionadas ao aplicativo."),
                .paragrafo("O usuário poderá negar, alterar ou revogar essa permissão nas configurações do dispositivo."),
            ]
        ),
        Secao(
            titulo: "6. Exclusão da conta",
            blocos: [
                .paragrafo("O usuário poderá solicitar a exclusão de sua conta diretamente por meio da funcionalidade disponibilizada no aplicativo."),
                .paragrafo("Após a solicitação de exclusão, os dados associados à conta serão excluídos ou anonimizados, conforme aplicável, observados os períodos de retenção necessários para cumprimento de obrigações legais, prevenção de fraudes, resolução de disputas ou exercício de direitos."),
                .paragrafo("A exclusão da conta poderá resultar na perda permanente do acesso aos dados, informações e funcionalidades associados à conta."),
            ]
        ),
        Secao(
            titulo: "7. Segurança",
            blocos: [
                .paragrafo("Adotamos medidas técnicas e organizacionais apropriadas para proteger os dados pessoais contra acesso não autorizado, perda, alteração, divulgação ou destruição indevida."),
                .paragrafo("Embora sejam adotadas medidas de segurança, nenhum sistema eletrônico pode garantir proteção absoluta contra todos os riscos existentes."),
            ]
        ),
        Secao(
            titulo: "8. Direitos do usuário",
            blocos: [
                .paragrafo("Nos termos da legislação aplicável, especialmente da Lei nº 13.709/2018 — Lei Geral de Proteção de Dados Pessoais (LGPD), o usuário poderá exercer, quando aplicável, direitos relacionados aos seus dados pessoais, incluindo:"),
                .lista([
                    "confirmação da existência de tratamento;",
                    "acesso aos dados;",
                    "correção de dados incompletos, inexatos ou desatualizados;",
                    "solicitação de eliminação de dados tratados com base no consentimento, quando aplicável;",
                    "informações sobre o compartilhamento de dados;",
                    "revogação do consentimento, quando aplicável;",
                    "demais direitos previstos na legislação vigente.",
                ]),
                .paragrafo("Para exercer direitos ou esclarecer dúvidas sobre privacidade, o usuário poderá entrar em contato por meio do endereço indicado nesta Política."),
            ]
        ),
        Secao(
            titulo: "9. Privacidade de crianças",
            blocos: [
                .paragrafo("O aplicativo NÃO É destinado especificamente a crianças."),
                .paragrafo("Caso seja identificado que dados pessoais foram coletados de uma criança de maneira incompatível com a legislação aplicável, serão adotadas as medidas necessárias para solucionar a situação."),
            ]
        ),
        Secao(
            titulo: "10. Alterações nesta Política",
            blocos: [
                .paragrafo("Esta Política de Privacidade poderá ser atualizada periodicamente para refletir alterações nas funcionalidades do aplicativo, nos serviços utilizados ou na legislação aplicável."),
                .paragrafo("Quando houver alterações relevantes, os usuários poderão ser comunicados por meio do aplicativo ou de outros canais apropriados."),
            ]
        ),
        Secao(
            titulo: "11. Contato",
            blocos: [
                .paragrafo("Para dúvidas, solicitações ou questões relacionadas ao tratamento de dados pessoais, entre em contato:"),
                .paragrafo("Aplicativo: Makerspot"),
                .paragrafo("Responsáveis: Amanda de Morais, Bianca Duarte, Maria Júlia Sales, Matheus Menezes"),
                .paragrafo("E-mail: suportemakerspot@gmail.com"),
            ]
        ),
    ]
}
