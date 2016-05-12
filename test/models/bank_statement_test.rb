# = Informations
#
# == License
#
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2009 Brice Texier, Thibaud Merigon
# Copyright (C) 2010-2012 Brice Texier
# Copyright (C) 2012-2016 Brice Texier, David Joulin
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
# == Table: bank_statements
#
#  cash_id                :integer          not null
#  created_at             :datetime         not null
#  creator_id             :integer
#  credit                 :decimal(19, 4)   default(0.0), not null
#  currency               :string           not null
#  custom_fields          :jsonb
#  debit                  :decimal(19, 4)   default(0.0), not null
#  id                     :integer          not null, primary key
#  initial_balance_credit :decimal(19, 4)   default(0.0), not null
#  initial_balance_debit  :decimal(19, 4)   default(0.0), not null
#  lock_version           :integer          default(0), not null
#  number                 :string           not null
#  started_at             :datetime         not null
#  stopped_at             :datetime         not null
#  updated_at             :datetime         not null
#  updater_id             :integer
#

require 'test_helper'

class BankStatementTest < ActiveSupport::TestCase
  test_model_actions

  test 'debit, credit and currency are computed during validations' do
    bank_statement = bank_statements(:bank_statements_001)
    bank_statement.debit = 0
    bank_statement.credit = 0
    bank_statement.currency = nil
    bank_statement.valid?
    assert_equal bank_statement.items.sum(:debit), bank_statement.debit
    assert_equal bank_statement.items.sum(:credit), bank_statement.credit
    assert_equal bank_statement.cash.currency, bank_statement.currency
  end

  test 'save with items replace its items with the new items attributes' do
    bank_statement = bank_statements(:bank_statements_001)
    new_items = [
      {
        name: "Bank statement item 1",
        credit: 15.3,
        debit: nil,
        letter: 'A',
        transfered_on: Date.parse('2016-05-11'),
        transaction_id: '119X6731'
      }, {
        name: "Bank statement item 1",
        credit: 15.3,
        debit: nil,
        letter: 'A',
        transfered_on: Date.parse('2016-05-11'),
        transaction_id: '119X6731'
      }
    ]

    assert bank_statement.save_with_items(new_items), inspect_errors(bank_statement)
    assert_equal new_items.length, bank_statement.items.count

    new_items.each do |item_attributes|
      item = bank_statement.items.detect { |i| i.name == item_attributes[:name] }
      assert item.present?
      assert_equal item_attributes[:credit], item.credit
      assert_equal item_attributes[:debit], item.debit
      assert_equal item_attributes[:currency], item.currency
      assert_equal item_attributes[:letter], item.letter
      assert_equal item_attributes[:transfered_on], item.transfered_on
      assert_equal item_attributes[:transaction_id], item.transaction_id
   end
  end

  test 'save with items does not update items or bank statement when an item is invalid' do
    bank_statement = bank_statements(:bank_statements_001)
    bank_statement_item_names = bank_statement.items.map(&:name)
    new_invalid_items = [
      { name: nil,
        credit: 15.3,
        debit: nil,
        transfered_on: Date.parse('2016-05-11') }
    ]
    assert !bank_statement.save_with_items(new_invalid_items), inspect_errors(bank_statement)
    bank_statement.reload
    assert_equal bank_statement_item_names.to_set, bank_statement.items.map(&:name).to_set
  end

  def inspect_errors(object)
    object.inspect + "\n" + object.errors.full_messages.to_sentence
  end
end
