//
//  TopBarView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

enum TopBarType: Equatable {
    case add
    case editDelete
    case confirm
    case reportSave
    case mainScreens
}

private extension TopBarType {
    var showsBackButton: Bool {
        self != .mainScreens
    }
}

struct TopBar: ToolbarContent {
    let type: TopBarType
    var title: String?
    var symbol: String?
    var action1: (() -> Void)?
    var action2: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    init(
        type: TopBarType,
        title: String? = nil,
        symbol: String? = nil,
        action1: (() -> Void)? = nil,
        action2: (() -> Void)? = nil
    ) {
        self.type = type
        self.title = title
        self.symbol = symbol
        self.action1 = action1
        self.action2 = action2
    }

    var body: some ToolbarContent {
        if type.showsBackButton {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                }
                .accessibilityLabel("Voltar")
            }
        }

        if type == .confirm, let title {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.headline)
            }
        }

        switch type {
        case .add:
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    action1?()
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glassProminent)
                .tint(Color("AccentColor").opacity(0.75))
                .accessibilityLabel("Adicionar")
            }

        case .confirm:
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    action1?()
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glassProminent)
                .tint(Color("AccentColor").opacity(0.75))
                .accessibilityLabel("Confirmar")
            }

        case .editDelete:
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    action1?()
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Editar")

                Button(role: .destructive) {
                    action2?()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Excluir")
            }

        case .reportSave:
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    action1?()
                } label: {
                    Image(systemName: "exclamationmark.bubble")
                }
                .accessibilityLabel("Denunciar")

                Button {
                    action2?()
                } label: {
                    Image(systemName: "bookmark")
                }
                .accessibilityLabel("Salvar")
            }

        case .mainScreens:
            if let symbol {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        action1?()
                    } label: {
                        Image(systemName: symbol)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color("AccentColor").opacity(0.75))
                    .accessibilityLabel("Ação")
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Adicionar") {
    NavigationStack {
        Color.black
            .ignoresSafeArea()
            .navigationBarBackButtonHidden(true)
            .toolbar {
                TopBar(
                    type: .add,
                    action1: { print("Adicionar") }
                )
            }
    }
}

#Preview("Editar e excluir") {
    NavigationStack {
        Color.black
            .ignoresSafeArea()
            .navigationBarBackButtonHidden(true)
            .toolbar {
                TopBar(
                    type: .editDelete,
                    action1: { print("Editar") },
                    action2: { print("Excluir") }
                )
            }
    }
}

#Preview("Confirmar") {
    NavigationStack {
        Color.black
            .ignoresSafeArea()
            .navigationBarBackButtonHidden(true)
            .toolbar {
                TopBar(
                    type: .confirm,
                    title: "Novo Spot",
                    action1: { print("Confirmar") }
                )
            }
    }
}

#Preview("Denunciar e salvar") {
    NavigationStack {
        Color.black
            .ignoresSafeArea()
            .navigationBarBackButtonHidden(true)
            .toolbar {
                TopBar(
                    type: .reportSave,
                    action1: { print("Denunciar") },
                    action2: { print("Salvar") }
                )
            }
    }
}

#Preview("Tela principal com ação") {
    NavigationStack {
        ZStack(alignment: .topLeading) {
        }
        .toolbar {
            TopBar(
                type: .mainScreens,
                symbol: "plus",
                action1: { print("Adicionar") }
            )
        }
    }
}

#Preview("Salvos sem ação") {
    NavigationStack {
        ZStack(alignment: .topLeading) {
            Color.black
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 8) {
                Text("Salvos")
                    .font(.largeTitle.bold())

                Text("Seus eventos e espaços favoritos.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
        }
        .toolbar {
            TopBar(type: .mainScreens)
        }
    }
}
