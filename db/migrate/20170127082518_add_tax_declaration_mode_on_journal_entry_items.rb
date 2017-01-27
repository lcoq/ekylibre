class AddTaxDeclarationModeOnJournalEntryItems < ActiveRecord::Migration
  def change
    add_column :journal_entry_items, :tax_declaration_mode, :string
    add_index :journal_entry_items, :tax_declaration_mode
  end
end
