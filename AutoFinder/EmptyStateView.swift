import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: UIConstants.Spacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(Color(UIConstants.Colors.secondaryGray))
            
            VStack(spacing: UIConstants.Spacing.sm) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIConstants.Colors.textPrimary))
                
                Text(message)
                    .font(.body)
                    .foregroundColor(Color(UIConstants.Colors.textSecondary))
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(AppPrimaryButtonStyle())
            }
        }
        .padding()
    }
}
