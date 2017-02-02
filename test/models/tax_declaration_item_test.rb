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
# == Table: tax_declaration_items
#
#  balance_pretax_amount                :decimal(19, 4)   default(0.0), not null
#  balance_tax_amount                   :decimal(19, 4)   default(0.0), not null
#  collected_pretax_amount              :decimal(19, 4)   default(0.0), not null
#  collected_tax_amount                 :decimal(19, 4)   default(0.0), not null
#  created_at                           :datetime         not null
#  creator_id                           :integer
#  currency                             :string           not null
#  deductible_pretax_amount             :decimal(19, 4)   default(0.0), not null
#  deductible_tax_amount                :decimal(19, 4)   default(0.0), not null
#  fixed_asset_deductible_pretax_amount :decimal(19, 4)   default(0.0), not null
#  fixed_asset_deductible_tax_amount    :decimal(19, 4)   default(0.0), not null
#  id                                   :integer          not null, primary key
#  intracommunity_payable_pretax_amount :decimal(19, 4)   default(0.0), not null
#  intracommunity_payable_tax_amount    :decimal(19, 4)   default(0.0), not null
#  lock_version                         :integer          default(0), not null
#  tax_declaration_id                   :integer          not null
#  tax_id                               :integer          not null
#  updated_at                           :datetime         not null
#  updater_id                           :integer
#
require 'test_helper'

class TaxDeclarationItemTest < ActiveSupport::TestCase
  test 'compute generate tax declaration item parts from journal entry items on debit and update amounts' do
    tax = taxes(:taxes_003) # amount 0.2
    financial_year = financial_years(:financial_years_008)
    tax_declaration = create(:tax_declaration, financial_year: financial_year)
    printed_on = tax_declaration.started_on + 1.day

    purchases_account = create(:account, name: "Purchases")
    suppliers_account = create(:account, name: "Suppliers")
    clients_account = create(:account, name: "Clients")
    revenues_account = create(:account, name: "Revenues")
    vat_deductible_account = tax.deduction_account
    vat_collected_account = tax.collect_account

    purchase1 = build(:journal_entry,
      printed_on: printed_on,
      real_credit: 1800.0,
      real_debit: 1800.0
    )
    purchase1.items = [
      build(:journal_entry_item,
       entry: purchase1,
       account: suppliers_account,
       real_credit: 1800.0
     ),
      build(:journal_entry_item,
       entry: purchase1,
       account: vat_deductible_account,
       real_debit: 300.0,
       real_pretax_amount: 1500.0,
       tax: tax,
       tax_declaration_mode: 'debit',
      ),
      build(:journal_entry_item,
        entry: purchase1,
        account: purchases_account,
        real_debit: 1500.0
      ),
    ]

    purchase2 = build(:journal_entry,
     printed_on: printed_on,
     real_credit: 480.0,
     real_debit: 480.0
    )
    purchase2.items = [
      build(:journal_entry_item,
       entry: purchase2,
       account: suppliers_account,
       real_credit: 480.0
     ),
      build(:journal_entry_item,
       entry: purchase2,
       account: vat_deductible_account,
       real_debit: 80.0,
       real_pretax_amount: 400.0,
       tax: tax,
       tax_declaration_mode: 'debit',
      ),
      build(:journal_entry_item,
        entry: purchase2,
        account: purchases_account,
        real_debit: 400.0
      ),
    ]

    sale1 = build(:journal_entry,
     printed_on: printed_on,
     real_credit: 144.0,
     real_debit: 144.0
    )
    sale1.items = [
      build(:journal_entry_item,
       entry: sale1,
       account: clients_account,
       real_debit: 144.0
     ),
      build(:journal_entry_item,
       entry: sale1,
       account: vat_collected_account,
       real_credit: 24.0,
       real_pretax_amount: 120.0,
       tax: tax,
       tax_declaration_mode: 'debit',
      ),
      build(:journal_entry_item,
        entry: sale1,
        account: revenues_account,
        real_credit: 120.0
      ),
    ]

    purchase1.save!
    purchase2.save!
    sale1.save!

    subject = TaxDeclarationItem.new(tax_declaration: tax_declaration, tax: tax)
    assert subject.compute!

    assert_equal 3, subject.parts.length

    subject.parts.detect { |part| part.journal_entry_item.entry == purchase1 }.tap do |p|
      assert p
      assert_equal vat_deductible_account, p.account
      assert_equal 300.0, p.tax_amount
      assert_equal 1500.0, p.pretax_amount
      assert_equal 300.0, p.total_tax_amount
      assert_equal 1500.0, p.total_pretax_amount
      assert_equal 'deductible', p.direction
    end

    subject.parts.detect { |part| part.journal_entry_item.entry == purchase2 }.tap do |p|
      assert p
      assert_equal vat_deductible_account, p.account
      assert_equal 80.0, p.tax_amount
      assert_equal 400.0, p.pretax_amount
      assert_equal 80.0, p.total_tax_amount
      assert_equal 400.0, p.total_pretax_amount
      assert_equal 'deductible', p.direction
    end

    subject.parts.detect { |part| part.journal_entry_item.entry == sale1 }.tap do |p|
      assert p
      assert_equal vat_collected_account, p.account
      assert_equal 24.0, p.tax_amount
      assert_equal 120.0, p.pretax_amount
      assert_equal 24.0, p.total_tax_amount
      assert_equal 120.0, p.total_pretax_amount
      assert_equal 'collected', p.direction
    end

    assert_equal 380.0, subject.deductible_tax_amount
    assert_equal 1900.0, subject.deductible_pretax_amount # 1500 + 400

    assert_equal 24.0, subject.collected_tax_amount
    assert_equal 120.0, subject.collected_pretax_amount

    assert_equal 0.0, subject.fixed_asset_deductible_tax_amount
    assert_equal 0.0, subject.fixed_asset_deductible_pretax_amount
    assert_equal 0.0, subject.intracommunity_payable_tax_amount
    assert_equal 0.0, subject.intracommunity_payable_pretax_amount

    assert_equal -356.0, subject.balance_tax_amount # 380 - 24
    assert_equal -1780.0, subject.balance_pretax_amount # 1900 - 120
 end
end
