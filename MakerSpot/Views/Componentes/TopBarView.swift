//
//  TopBarView.swift
//  MakerSpot
//
//  Created by Matheus Miranda Cabral de Menezes on 14/09/26.
//

import SwiftUI

enum TopBarType: Equatable {
    case back
    case add
    case editDelete
    case confirm
    case closeConfirm
    case reportSave
    case mainScreens
}

private extension TopBarType {
    var showsBackButton: Bool {
        self != .mainScreens && self != .closeConfirm
    }

    var showsTitle: Bool {
        self == .back || self == .confirm
    }
}

struct TopBar: ToolbarContent {
    let type: TopBarType
    var title: String?
    var symbol: String?
    var action1: (() -> Void)?
    var action2: (() -> Void)?
    var backAction: (() -> Void)?
    var isActionDisabled = false

    @Environment(\.dismiss) private var dismiss

    init(
        type: TopBarType,
        title: String? = nil,
        symbol: String? = nil,
        action1: (() -> Void)? = nil,
        action2: (() -> Void)? = nil,
        backAction: (() -> Void)? = nil,
        isActionDisabled: Bool = false
    ) {
        self.type = type
        self.title = title
        self.symbol = symbol
        self.action1 = action1
        self.action2 = action2
        self.backAction = backAction
        self.isActionDisabled = isActionDisabled
    }

    var body: some ToolbarContent {
        if type.showsBackButton {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    voltar()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                }
                .accessibilityLabel("Voltar")
            }
        }

        if type == .closeConfirm {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    voltar()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Cancelar")
            }
        }

        if type.showsTitle, let title {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.headline)
            }
        }

        if type == .add {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    action1?()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Adicionar")
            }
        }

        if type == .confirm || type == .closeConfirm {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    action1?()
                } label: {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(isActionDisabled)
                .accessibilityLabel(
                    type == .closeConfirm ? "Salvar alterações" : "Confirmar"
                )
            }
        }

        if type == .editDelete {
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
        }

        if type == .reportSave {
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
        }

        if type == .mainScreens, let symbol {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    action1?()
                } label: {
                    Image(systemName: symbol)
                }
                .accessibilityLabel("Ação")
            }
        }
    }

    private func voltar() {
        if let backAction {
            backAction()
        } else {
            dismiss()
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
