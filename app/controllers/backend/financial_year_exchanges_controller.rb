module Backend
  class FinancialYearExchangesController < Backend::BaseController
    manage_restfully only: [:new, :create, :show]

    list(:journal_entries, conditions: { financial_year_exchange_id: 'params[:id]'.c }, order: { created_at: :desc}) do |t|
      t.column :number, url: true
      t.column :printed_on
      t.column :journal, url: true
      t.column :real_debit,  currency: :real_currency
      t.column :real_credit, currency: :real_currency
      t.column :debit,  currency: true, hidden: true
      t.column :credit, currency: true, hidden: true
      t.column :absolute_debit,  currency: :absolute_currency, hidden: true
      t.column :absolute_credit, currency: :absolute_currency, hidden: true
    end
  end
end
