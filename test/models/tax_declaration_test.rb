# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2017 Brice Texier, David Joulin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see http://www.gnu.org/licenses.
#
# == Table: tax_declarations
#
#  accounted_at      :datetime
#  created_at        :datetime         not null
#  creator_id        :integer
#  currency          :string           not null
#  description       :text
#  financial_year_id :integer          not null
#  id                :integer          not null, primary key
#  invoiced_on       :date
#  journal_entry_id  :integer
#  lock_version      :integer          default(0), not null
#  mode              :string           not null
#  number            :string
#  reference_number  :string
#  responsible_id    :integer
#  started_on        :date             not null
#  state             :string
#  stopped_on        :date             not null
#  updated_at        :datetime         not null
#  updater_id        :integer
#
require 'test_helper'

class TaxDeclarationTest < ActiveSupport::TestCase
  test 'bookkeep set the non-purchase journal entry items tax declaration mode from the financial year' do
    financial_year = financial_year_in_debit_mode
    printed_on = financial_year.started_on + 1.day
    entry_item = create_journal_entry_item_sale(printed_on, a_tax)
    subject = create(:tax_declaration, financial_year: financial_year)
    subject.bookkeep
    entry_item.reload
    assert_equal 'debit', entry_item.tax_declaration_mode
  end
  test 'bookkeep set the tax declaration mode "debit" to journal entry items targeting purchases at invoicing' do
    financial_year = a_financial_year
    printed_on = financial_year.started_on + 1.day
    entry_item = create_journal_entry_item_purchase(printed_on, a_tax, 'at_invoicing')
    subject = create(:tax_declaration, financial_year: financial_year)
    subject.bookkeep
    entry_item.reload
    assert_equal 'debit', entry_item.tax_declaration_mode
  end
  test 'bookkeep set the tax declaration mode "payment" to journal entry items targeting purchases at paying' do
    financial_year = a_financial_year
    printed_on = financial_year.started_on + 1.day
    entry_item = create_journal_entry_item_purchase(printed_on, a_tax, 'at_paying')
    subject = create(:tax_declaration, financial_year: financial_year)
    subject.bookkeep
    entry_item.reload
    assert_equal 'payment', entry_item.tax_declaration_mode
  end

  def a_financial_year
    financial_year_in_debit_mode
  end

  def financial_year_in_debit_mode
    financial_years(:financial_years_008)
  end

  def a_tax
    taxes(:taxes_001)
  end

  def create_journal_entry_item_purchase(printed_on, tax, tax_payability)
    entry = create(:journal_entry, :with_items, printed_on: printed_on)
    purchase = create(:purchase, nature: purchase_natures(:purchase_natures_001), tax_payability: tax_payability)
    purchase_item = create(:purchase_item, purchase: purchase, tax: tax)
    create :journal_entry_item,
      entry: entry,
      printed_on: printed_on,
      tax: tax,
      resource_prism: 'item_tax',
      resource: purchase_item
  end

  def create_journal_entry_item_sale(printed_on, tax)
    entry = create(:journal_entry, :with_items, printed_on: printed_on)
    sale = create(:sale, nature: sale_natures(:sale_natures_001))
    sale_item = create(:sale_item, sale: sale, tax: tax)
    create :journal_entry_item,
      entry: entry,
      printed_on: printed_on,
      tax: tax,
      resource_prism: 'item_tax',
      resource: sale_item
  end
end
