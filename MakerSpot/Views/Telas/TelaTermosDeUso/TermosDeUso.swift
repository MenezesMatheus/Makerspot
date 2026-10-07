// Conteúdo fornecido nos Termos e Condições de Uso do MakerSpot (30 set. 2026).

enum TermosDeUso {
    static let titulo = "Termos & Condições de Uso - MakerSpot"
    static let ultimaAtualizacao = "Última atualização: 30 set. 2026"
    static let introducao: [String] = [
        "Bem-vindo ao MakerSpot!",
        "Estes Termos e Condições de Uso estabelecem as regras para utilização do aplicativo MakerSpot (“Aplicativo”), desenvolvido e disponibilizado por MakerSpot / Amanda de Morais - Bianca Duarte - Maria Júlia Sales - Matheus Menezes",
        "Ao criar uma conta ou utilizar o MakerSpot, você declara que leu, compreendeu e concorda com estes Termos.",
    ]

    struct Secao {
        let titulo: String
        let paragrafos: [String]
        var itens: [String] = []
        var mostraLinkPoliticaPrivacidade = false
    }

    static let secoes: [Secao] = [
        Secao(
            titulo: "1. Sobre o MakerSpot",
            paragrafos: [
                "O MakerSpot é uma plataforma destinada à comunidade Maker, visando facilitar o acesso a informação de locais e eventos e a troca criativa entre membros da comunidade, oferecendo aos usuários ferramentas e funcionalidades relacionadas à utilização dos serviços disponibilizados na plataforma.",
                "O aplicativo poderá disponibilizar funcionalidades como criação de perfil, personalização de informações, utilização de foto de perfil, recebimento de notificações e demais recursos apresentados dentro da plataforma.",
            ]
        ),
        Secao(
            titulo: "2. Cadastro e conta",
            paragrafos: [
                "Para utilizar determinadas funcionalidades do MakerSpot, o usuário deverá criar uma conta utilizando o Sign in with Apple.",
                "O usuário é responsável por fornecer informações verdadeiras e atualizadas e por manter a segurança de sua conta.",
                "A conta é pessoal e não deve ser compartilhada com outras pessoas.",
                "O usuário deverá comunicar ao MakerSpot caso identifique qualquer utilização não autorizada de sua conta.",
            ]
        ),
        Secao(
            titulo: "3. Foto de perfil",
            paragrafos: [
                "O MakerSpot permite que o usuário adicione uma foto ao seu perfil.",
                "Para selecionar uma imagem, o aplicativo poderá solicitar acesso às fotos disponíveis no dispositivo.",
                "O usuário declara possuir os direitos necessários para utilizar a imagem escolhida e se compromete a não utilizar imagens que violem direitos de terceiros.",
            ]
        ),
        Secao(
            titulo: "4. Uso adequado do aplicativo",
            paragrafos: [
                "O usuário compromete-se a utilizar o MakerSpot de maneira legal, ética e de acordo com estes Termos.",
                "É proibido:",
            ],
            itens: [
                "utilizar o aplicativo para atividades ilegais;",
                "fornecer informações falsas com a intenção de enganar outros usuários;",
                "tentar acessar contas ou informações de terceiros;",
                "interferir no funcionamento do aplicativo;",
                "introduzir vírus ou códigos maliciosos;",
                "utilizar o aplicativo para assediar, ameaçar ou discriminar outras pessoas e grupos;",
                "violar direitos autorais, marcas ou outros direitos de terceiros;",
                "utilizar o aplicativo para finalidades diferentes daquelas para as quais foi disponibilizado.",
            ]
        ),
        Secao(
            titulo: "5. Conteúdo do usuário",
            paragrafos: [
                "O MakerSpot permite que o usuário publique informações, imagens, comentários ou outros conteúdos, de forma que o usuário permanece responsável pelo material que disponibilizar na plataforma.",
                "O usuário declara possuir os direitos necessários sobre o conteúdo publicado.",
                "Não é permitido publicar conteúdo ilegal, ofensivo, discriminatório, fraudulento ou que viole direitos de terceiros.",
                "O MakerSpot poderá remover conteúdos que violem estes Termos ou a legislação aplicável.",
            ]
        ),
        Secao(
            titulo: "6. Notificações",
            paragrafos: [
                "O MakerSpot poderá enviar notificações push relacionadas às funcionalidades e aos serviços disponibilizados pelo aplicativo.",
                "O envio de notificações depende da autorização do usuário.",
                "O usuário poderá ativar ou desativar as notificações nas configurações do dispositivo.",
            ]
        ),
        Secao(
            titulo: "7. Disponibilidade do serviço",
            paragrafos: [
                "O MakerSpot busca manter o aplicativo disponível e funcionando adequadamente.",
                "Entretanto, o serviço poderá ficar temporariamente indisponível em razão de manutenção, atualizações, falhas técnicas, problemas de conexão ou circunstâncias que estejam fora do controle do responsável pelo aplicativo.",
            ]
        ),
        Secao(
            titulo: "8. Propriedade intelectual",
            paragrafos: [
                "A marca MakerSpot, sua identidade visual, interface, código, textos, elementos gráficos e demais componentes do aplicativo pertencem ao responsável pelo aplicativo ou são utilizados de acordo com as autorizações correspondentes.",
                "É proibida a reprodução, distribuição, modificação ou exploração comercial não autorizada desses elementos.",
            ]
        ),
        Secao(
            titulo: "9. Privacidade",
            paragrafos: [
                "O tratamento dos dados pessoais dos usuários é realizado de acordo com a Política de Privacidade do MakerSpot.",
                "A Política de Privacidade explica quais informações são coletadas, como são utilizadas, como são armazenadas e quais direitos podem ser exercidos pelos usuários.",
            ],
            mostraLinkPoliticaPrivacidade: true
        ),
        Secao(
            titulo: "10. Exclusão da conta",
            paragrafos: [
                "O usuário poderá solicitar a exclusão de sua conta por meio da funcionalidade disponibilizada no aplicativo.",
                "A exclusão poderá resultar na remoção dos dados associados à conta, observadas as obrigações legais de retenção de informações.",
                "Após a exclusão, o usuário poderá perder o acesso às funcionalidades e informações vinculadas à conta.",
            ]
        ),
        Secao(
            titulo: "11. Suspensão ou encerramento",
            paragrafos: [
                "O MakerSpot poderá suspender ou encerrar uma conta caso o usuário viole estes Termos, utilize o aplicativo de maneira fraudulenta ou ilegal ou pratique ações que possam prejudicar outros usuários ou o funcionamento da plataforma.",
            ]
        ),
        Secao(
            titulo: "12. Alterações nos Termos",
            paragrafos: [
                "Estes Termos poderão ser atualizados periodicamente para acompanhar mudanças no aplicativo, nos serviços oferecidos ou na legislação aplicável.",
                "Quando houver alterações relevantes, o usuário poderá ser informado por meio do aplicativo ou por outros meios apropriados.",
            ]
        ),
        Secao(
            titulo: "13. Legislação aplicável",
            paragrafos: [
                "Estes Termos serão interpretados de acordo com a legislação brasileira.",
                "Eventuais questões relacionadas à utilização do MakerSpot serão tratadas conforme a legislação aplicável e os direitos assegurados aos usuários.",
            ]
        ),
        Secao(
            titulo: "14. Contato",
            paragrafos: [
                "Para dúvidas, solicitações ou informações relacionadas a estes Termos, entre em contato:",
                "Aplicativo: MakerSpot",
                "Responsáveis: Amanda de Morais, Bianca Duarte, Maria Júlia Sales, Matheus Menezes",
                "E-mail: suportemakerspot@gmail.com",
            ]
        ),
    ]
}
