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
  test 'compute declaration with journal entry items on debit' do
    #
    # Tax: 20%
    #
    # Purchase1 (on debit, deductible)
    #    HT 1500
    #   VAT 300
    #   TTC 1800
    #
    # Purchase2 (on debit, deductible)
    #    HT 400
    #   VAT  80
    #   TTC 480
    #
    # Sale1 (on debit, collected)
    #    HT 120
    #   VAT 24
    #   TTC 144
    #
    # ======>
    #
    # Deductible
    #   tax     380 (= 300 + 80)
    #   pretax 1900 (= 1500 + 400)
    # Collected
    #   tax     24
    #   pretax 120
    #
    # Global balance
    #   -356 (= 24 - 380)

    tax = taxes(:taxes_003)

    financial_year = financial_year_in_debit_mode
    started_on = financial_year.started_on
    stopped_on = started_on.end_of_month
    printed_on = started_on + 1.day

    purchases_account = create(:account, name: "Purchases")
    suppliers_account = create(:account, name: "Suppliers")
    clients_account = create(:account, name: "Clients")
    revenues_account = create(:account, name: "Revenues")
    vat_deductible_account = tax.deduction_account
    vat_collected_account = tax.collect_account

    purchase1 = create(:purchase,
      nature: purchase_natures(:purchase_natures_001),
      tax_payability: 'at_invoicing'
    )
    purchase1_item = create(:purchase_item,
      purchase: purchase1,
      tax: tax
    )
    purchase1_entry = build(:journal_entry,
      printed_on: printed_on,
      real_credit: 1800.0,
      real_debit: 1800.0
    )
    purchase1_entry.items = [
      build(:journal_entry_item,
       entry: purchase1_entry,
       account: suppliers_account,
       real_credit: 1800.0
     ),
      build(:journal_entry_item,
       entry: purchase1_entry,
       account: vat_deductible_account,
       real_debit: 300.0,
       real_pretax_amount: 1500.0,
       tax: tax,
       resource: purchase1_item
      ),
      build(:journal_entry_item,
        entry: purchase1_entry,
        account: purchases_account,
        real_debit: 1500.0
      )
    ]
    assert purchase1_entry.save

    purchase2 = create(:purchase,
      nature: purchase_natures(:purchase_natures_001),
      tax_payability: 'at_invoicing'
    )
    purchase2_item = create(:purchase_item,
      purchase: purchase2,
      tax: tax
    )
    purchase2_entry = build(:journal_entry,
     printed_on: printed_on,
     real_credit: 480.0,
     real_debit: 480.0
    )
    purchase2_entry.items = [
      build(:journal_entry_item,
       entry: purchase2_entry,
       account: suppliers_account,
       real_credit: 480.0
     ),
      build(:journal_entry_item,
       entry: purchase2_entry,
       account: vat_deductible_account,
       real_debit: 80.0,
       real_pretax_amount: 400.0,
       tax: tax,
       resource: purchase2_item
      ),
      build(:journal_entry_item,
        entry: purchase2_entry,
        account: purchases_account,
        real_debit: 400.0
      )
    ]
    assert purchase2_entry.save

    sale1 = create(:sale, nature: sale_natures(:sale_natures_001))
    sale1_item = create(:sale_item, sale: sale1, tax: tax)
    sale1_entry = build(:journal_entry,
     printed_on: printed_on,
     real_credit: 144.0,
     real_debit: 144.0
    )
    sale1_entry.items = [
      build(:journal_entry_item,
       entry: sale1_entry,
       account: clients_account,
       real_debit: 144.0
     ),
      build(:journal_entry_item,
       entry: sale1_entry,
       account: vat_collected_account,
       real_credit: 24.0,
       real_pretax_amount: 120.0,
       tax: tax,
       resource: sale1_item
      ),
      build(:journal_entry_item,
        entry: sale1_entry,
        account: revenues_account,
        real_credit: 120.0
      )
    ]
    assert sale1_entry.save

    subject = build(:tax_declaration, financial_year: financial_year, started_on: started_on, stopped_on: stopped_on)
    assert subject.save

    assert_equal 'debit', purchase1_entry.items.detect { |i| i.tax == tax }.reload.tax_declaration_mode
    assert_equal 'debit', purchase2_entry.items.detect { |i| i.tax == tax }.reload.tax_declaration_mode
    assert_equal 'debit', sale1_entry.items.detect { |i| i.tax == tax }.reload.tax_declaration_mode

    subject.items.detect { |item| item.tax == tax }.tap do |tax_item|
      assert_equal 380.0, tax_item.deductible_tax_amount
      assert_equal 1900.0, tax_item.deductible_pretax_amount
      assert_equal 24.0, tax_item.collected_tax_amount
      assert_equal 120.0, tax_item.collected_pretax_amount
      assert_equal 0.0, tax_item.fixed_asset_deductible_tax_amount
      assert_equal 0.0, tax_item.fixed_asset_deductible_pretax_amount
      assert_equal 0.0, tax_item.intracommunity_payable_tax_amount
      assert_equal 0.0, tax_item.intracommunity_payable_pretax_amount
      assert_equal -356.0, tax_item.balance_tax_amount
      assert_equal -1780.0, tax_item.balance_pretax_amount

      assert_equal 3, tax_item.parts.length
      tax_item.parts.detect { |part| part.journal_entry_item.entry == purchase1_entry }.tap do |p|
        assert p
        assert_equal vat_deductible_account, p.account
        assert_equal 300.0, p.tax_amount
        assert_equal 1500.0, p.pretax_amount
        assert_equal 300.0, p.total_tax_amount
        assert_equal 1500.0, p.total_pretax_amount
        assert_equal 'deductible', p.direction
      end
      tax_item.parts.detect { |part| part.journal_entry_item.entry == purchase2_entry }.tap do |p|
        assert p
        assert_equal vat_deductible_account, p.account
        assert_equal 80.0, p.tax_amount
        assert_equal 400.0, p.pretax_amount
        assert_equal 80.0, p.total_tax_amount
        assert_equal 400.0, p.total_pretax_amount
        assert_equal 'deductible', p.direction
      end
      tax_item.parts.detect { |part| part.journal_entry_item.entry == sale1_entry }.tap do |p|
        assert p
        assert_equal vat_collected_account, p.account
        assert_equal 24.0, p.tax_amount
        assert_equal 120.0, p.pretax_amount
        assert_equal 24.0, p.total_tax_amount
        assert_equal 120.0, p.total_pretax_amount
        assert_equal 'collected', p.direction
      end
    end

    assert_equal -356, subject.global_balance
  end
  test 'compute declaration with journal entry items on payment but without payment' do
    #
    # Tax: 20%
    #
    # Purchase1 (on payment, deductible)
    #    HT 725
    #   VAT 145
    #   TTC 870
    #
    # ======>
    #
    # Global balance 0 (no payment)

    tax = taxes(:taxes_003)

    financial_year = financial_year_in_debit_mode
    started_on = financial_year.started_on
    stopped_on = started_on.end_of_month
    printed_on = started_on + 1.day

    purchases_account = create(:account, name: "Purchases")
    suppliers_account = create(:account, name: "Suppliers")
    bank_account = create(:account, name: "Brank")
    vat_deductible_account = tax.deduction_account

    purchase1 = create(:purchase,
      nature: purchase_natures(:purchase_natures_001),
      tax_payability: 'at_paying'
    )
    purchase1_item = create(:purchase_item,
      purchase: purchase1,
      tax: tax
    )
    purchase1_entry = build(:journal_entry,
      printed_on: printed_on,
      real_credit: 870.0,
      real_debit: 870.0
    )
    purchase1_entry.items = [
      build(:journal_entry_item,
       entry: purchase1_entry,
       account: suppliers_account,
       real_credit: 870.0,
       letter: 'A'
     ),
      build(:journal_entry_item,
       entry: purchase1_entry,
       account: vat_deductible_account,
       real_debit: 145.0,
       real_pretax_amount: 725.0,
       tax: tax,
       resource: purchase1_item
      ),
      build(:journal_entry_item,
        entry: purchase1_entry,
        account: purchases_account,
        real_debit: 725.0
      )
    ]
    assert purchase1_entry.save

    subject = build(:tax_declaration, financial_year: financial_year, started_on: started_on, stopped_on: stopped_on)
    assert subject.save

    assert_equal 'payment', purchase1_entry.items.detect { |i| i.tax == tax }.reload.tax_declaration_mode

    subject.items.detect { |item| item.tax == tax }.tap do |tax_item|
      assert_equal 0, tax_item.parts.length
      assert_equal 0.0, tax_item.deductible_tax_amount
      assert_equal 0.0, tax_item.deductible_pretax_amount
      assert_equal 0.0, tax_item.collected_tax_amount
      assert_equal 0.0, tax_item.collected_pretax_amount
      assert_equal 0.0, tax_item.fixed_asset_deductible_tax_amount
      assert_equal 0.0, tax_item.fixed_asset_deductible_pretax_amount
      assert_equal 0.0, tax_item.intracommunity_payable_tax_amount
      assert_equal 0.0, tax_item.intracommunity_payable_pretax_amount
      assert_equal 0.0, tax_item.balance_tax_amount
      assert_equal 0.0, tax_item.balance_pretax_amount
    end

    assert_equal 0, subject.global_balance
  end
  test 'compute declaration with journal entry items on payment with payment but no declared' do
    #
    # Tax: 20%
    #
    # Purchase1 (on payment, deductible)
    #    HT 725
    #   VAT 145
    #   TTC 870
    #
    #   Payment1 340
    #   Payment2 60
    #
    #
    # ======>
    #
    # Deductible
    #   tax     66.67 (= 145 * (340 + 60) / 870)
    #   pretax 333.33 (= 725 * (340 + 60) / 870)
    #
    # Global balance
    #   -66.67

    tax = taxes(:taxes_003)

    financial_year = financial_year_in_debit_mode
    started_on = financial_year.started_on
    stopped_on = started_on.end_of_month
    printed_on = started_on + 1.day

    purchases_account = create(:account, name: "Purchases")
    suppliers_account = create(:account, name: "Suppliers")
    bank_account = create(:account, name: "Brank")
    vat_deductible_account = tax.deduction_account

    purchase1 = create(:purchase,
      nature: purchase_natures(:purchase_natures_001),
      tax_payability: 'at_paying'
    )
    purchase1_item = create(:purchase_item,
      purchase: purchase1,
      tax: tax
    )
    purchase1_entry = build(:journal_entry,
      printed_on: printed_on,
      real_credit: 870.0,
      real_debit: 870.0
    )
    purchase1_entry.items = [
      build(:journal_entry_item,
       entry: purchase1_entry,
       account: suppliers_account,
       real_credit: 870.0,
       letter: 'A'
     ),
      build(:journal_entry_item,
       entry: purchase1_entry,
       account: vat_deductible_account,
       real_debit: 145.0,
       real_pretax_amount: 725.0,
       tax: tax,
       resource: purchase1_item
      ),
      build(:journal_entry_item,
        entry: purchase1_entry,
        account: purchases_account,
        real_debit: 725.0
      )
    ]
    assert purchase1_entry.save


    payment1 = build(:journal_entry,
      printed_on: printed_on,
      real_credit: 340.0,
      real_debit: 340.0
    )
    payment1.items = [
      build(:journal_entry_item,
        entry: payment1,
        account: suppliers_account,
        real_debit: 340.0,
        letter: 'A'
      ),
      build(:journal_entry_item,
        entry: payment1,
        account: bank_account,
        real_credit: 340.0
      )
    ]
    assert payment1.save

    payment2 = build(:journal_entry,
      printed_on: printed_on,
      real_credit: 60.0,
      real_debit: 60.0
    )
    payment2.items = [
      build(:journal_entry_item,
        printed_on: printed_on,
        entry: payment2,
        account: suppliers_account,
        real_debit: 60.0,
        letter: 'A'
      ),
      build(:journal_entry_item,
        printed_on: printed_on,
        entry: payment2,
        account: bank_account,
        real_credit: 60.0
      )
    ]
    assert payment2.save

    subject = build(:tax_declaration, financial_year: financial_year, started_on: started_on, stopped_on: stopped_on)
    assert subject.save

    assert_equal 'payment', purchase1_entry.items.detect { |i| i.tax == tax }.reload.tax_declaration_mode

    subject.items.detect { |item| item.tax == tax }.tap do |tax_item|
      assert_equal 66.67, tax_item.deductible_tax_amount.round(2)
      assert_equal 333.33, tax_item.deductible_pretax_amount.round(2)
      assert_equal 0.0, tax_item.collected_tax_amount
      assert_equal 0.0, tax_item.collected_pretax_amount
      assert_equal 0.0, tax_item.fixed_asset_deductible_tax_amount
      assert_equal 0.0, tax_item.fixed_asset_deductible_pretax_amount
      assert_equal 0.0, tax_item.intracommunity_payable_tax_amount
      assert_equal 0.0, tax_item.intracommunity_payable_pretax_amount
      assert_equal -66.67, tax_item.balance_tax_amount.round(2)
      assert_equal -333.33, tax_item.balance_pretax_amount.round(2)

      assert_equal 1, tax_item.parts.length
      tax_item.parts.detect { |part| part.journal_entry_item.entry == purchase1_entry }.tap do |p|
        assert p
        assert_equal vat_deductible_account, p.account
        assert_equal 66.67, p.tax_amount.round(2)
        assert_equal 333.33, p.pretax_amount.round(2)
        assert_equal 145.0, p.total_tax_amount
        assert_equal 725.0, p.total_pretax_amount
        assert_equal 'deductible', p.direction
      end
    end

    assert_equal -66.67, subject.global_balance
  end
  test 'compute declaration with journal entry items on payment with payment and previous declared' do
    #
    # Tax: 20%
    #
    # Purchase1 (on payment, deductible)
    #    HT 725
    #   VAT 145
    #   TTC 870
    #
    #   Payment1 340 (previously declared)
    #   Payment2  60
    #
    # ======>
    #
    # PREVIOUS DECLARATION :
    #
    # Deductible
    #   tax     56.67 (= 145 * 340 / 870)
    #   pretax 238.33 (= 725 * 340 / 870)
    #
    # Global balance
    #   -56.67
    #
    # NEW DECLARATION :
    #
    # Deductible
    #   tax     10.00 (= 145 * (340 + 60) / 870 - 56.67)
    #   pretax 276.66 (= 725 * (340 + 60) / 870 - 56.67)
    #
    # Global balance
    #   -10.00

    tax = taxes(:taxes_003)

    financial_year = financial_year_in_debit_mode

    previous_declaration_started_on = financial_year.started_on.beginning_of_month
    previous_declaration_stopped_on = previous_declaration_started_on.end_of_month
    previous_declaration_printed_on = previous_declaration_started_on + 1.day

    started_on = (previous_declaration_stopped_on + 1.day).beginning_of_month
    stopped_on = started_on.end_of_month
    printed_on = started_on + 1.day

    purchases_account = create(:account, name: "Purchases")
    suppliers_account = create(:account, name: "Suppliers")
    bank_account = create(:account, name: "Brank")
    vat_deductible_account = tax.deduction_account

    purchase1 = create(:purchase,
      nature: purchase_natures(:purchase_natures_001),
      tax_payability: 'at_paying'
    )
    purchase1_item = create(:purchase_item,
      purchase: purchase1,
      tax: tax
    )
    purchase1_entry = build(:journal_entry,
      printed_on: previous_declaration_printed_on,
      real_credit: 870.0,
      real_debit: 870.0
    )
    purchase1_entry.items = [
      build(:journal_entry_item,
       entry: purchase1_entry,
       account: suppliers_account,
       real_credit: 870.0,
       letter: 'A'
     ),
      build(:journal_entry_item,
       entry: purchase1_entry,
       account: vat_deductible_account,
       real_debit: 145.0,
       real_pretax_amount: 725.0,
       tax: tax,
       resource: purchase1_item
      ),
      build(:journal_entry_item,
        entry: purchase1_entry,
        account: purchases_account,
        real_debit: 725.0
      )
    ]
    assert purchase1_entry.save


    payment1 = build(:journal_entry,
      printed_on: previous_declaration_printed_on,
      real_credit: 340.0,
      real_debit: 340.0
    )
    payment1.items = [
      build(:journal_entry_item,
        entry: payment1,
        account: suppliers_account,
        real_debit: 340.0,
        letter: 'A'
      ),
      build(:journal_entry_item,
        entry: payment1,
        account: bank_account,
        real_credit: 340.0
      )
    ]
    assert payment1.save


    payment2 = build(:journal_entry,
      printed_on: printed_on,
      real_credit: 60.0,
      real_debit: 60.0
    )
    payment2.items = [
      build(:journal_entry_item,
        printed_on: printed_on,
        entry: payment2,
        account: suppliers_account,
        real_debit: 60.0,
        letter: 'A'
      ),
      build(:journal_entry_item,
        printed_on: printed_on,
        entry: payment2,
        account: bank_account,
        real_credit: 60.0
      )
    ]
    assert payment2.save

    previous = create(:tax_declaration,
      financial_year: financial_year,
      started_on: previous_declaration_started_on,
      stopped_on: previous_declaration_stopped_on
    )
    assert_equal -56.67, previous.global_balance

    subject = build(:tax_declaration,
      financial_year: financial_year,
      started_on: started_on,
      stopped_on: stopped_on
    )
    assert subject.save

    subject.items.detect { |item| item.tax == tax }.tap do |tax_item|
      assert_equal 1, tax_item.parts.length
      tax_item.parts.detect { |part| part.journal_entry_item.entry == purchase1_entry }.tap do |p|
        assert p
        assert_equal vat_deductible_account, p.account
        assert_equal 10.0, p.tax_amount.round(2)
        assert_equal 276.67, p.pretax_amount.round(2)
        assert_equal 145.0, p.total_tax_amount
        assert_equal 725.0, p.total_pretax_amount
        assert_equal 'deductible', p.direction
      end

      assert_equal 10.0, tax_item.deductible_tax_amount.round(2)
      assert_equal 276.67, tax_item.deductible_pretax_amount.round(2)
      assert_equal 0.0, tax_item.collected_tax_amount
      assert_equal 0.0, tax_item.collected_pretax_amount
      assert_equal 0.0, tax_item.fixed_asset_deductible_tax_amount
      assert_equal 0.0, tax_item.fixed_asset_deductible_pretax_amount
      assert_equal 0.0, tax_item.intracommunity_payable_tax_amount
      assert_equal 0.0, tax_item.intracommunity_payable_pretax_amount
      assert_equal -10.0, tax_item.balance_tax_amount.round(2)
      assert_equal -276.67, tax_item.balance_pretax_amount.round(2)
    end

    assert_equal -10.0, subject.global_balance
  end

  def financial_year_in_debit_mode
    financial_years(:financial_years_008)
  end
end
