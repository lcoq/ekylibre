class AddPublicTokenToFinancialYearExchanges < ActiveRecord::Migration
  def change
    add_column :financial_year_exchanges, :public_token, :string, null: false
    add_column :financial_year_exchanges, :public_token_expires_on, :datetime, null: false
    add_index :financial_year_exchanges, :public_token, unique: true
  end
end
