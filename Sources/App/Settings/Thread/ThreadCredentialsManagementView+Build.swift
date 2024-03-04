import Foundation

extension ThreadCredentialsManagementView {
    static func build() -> ThreadCredentialsManagementView {
        ThreadCredentialsManagementView(viewModel: ThreadCredentialsManagementViewModel())
    }
}
