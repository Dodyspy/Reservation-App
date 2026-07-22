import SwiftUI

struct AddCustomerNoteView: View {
    let customer: Customer
    let customerViewModel: CustomerViewModel
    @Binding var newNote: String
    
    @Environment(\.dismiss) private var dismiss
    
    private var isValid: Bool {
        !newNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Ajouter une note")
                        .font(.custom("Didot", size: 24))
                        .foregroundColor(AppTheme.gold)
                    
                    Text("Pour \(customer.primary_name ?? customer.primary_email)")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.cream.opacity(0.7))
                }
                .padding(.top)
                
                // Note input
                VStack(alignment: .leading, spacing: 10) {
                    Text("Note")
                        .font(.headline)
                        .foregroundColor(AppTheme.cream)
                    
                    TextField("Tapez votre note ici...", text: $newNote, axis: .vertical)
                        .lineLimit(5...10)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppTheme.darkGray)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppTheme.gold.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .foregroundColor(AppTheme.cream)
                }
                
                // Quick note templates
                VStack(alignment: .leading, spacing: 10) {
                    Text("Modèles rapides")
                        .font(.headline)
                        .foregroundColor(AppTheme.cream)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                        ForEach(quickNoteTemplates, id: \.self) { template in
                            Button(template) {
                                newNote = template
                            }
                            .font(.caption)
                            .foregroundColor(AppTheme.cream)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppTheme.darkGray)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(AppTheme.gold.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(AppTheme.anthracite)
            .navigationTitle("Nouvelle Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.gold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ajouter") {
                        customerViewModel.addCustomerNote(customer, note: newNote)
                        newNote = ""
                        dismiss()
                    }
                    .disabled(!isValid)
                    .foregroundColor(AppTheme.gold)
                }
            }
        }
    }
    
    private let quickNoteTemplates = [
        "Client très agréable",
        "Préfère les tables calmes",
        "Allergique aux fruits à coque",
        "Célèbre son anniversaire",
        "Client régulier VIP",
        "Demande spéciale cuisine",
        "Arrivée souvent en retard",
        "Préfère paiement en espèces"
    ]
}

#Preview {
    AddCustomerNoteView(
        customer: Customer(
            primary_email: "test@example.com",
            primary_phone: "0612345678",
            total_reservations: 3,
            no_show_count: 0
        ),
        customerViewModel: CustomerViewModel(),
        newNote: .constant("")
    )
}
