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
# == Table: journal_entries
#
#  absolute_credit    :decimal(19, 4)   default(0.0), not null
#  absolute_currency  :string           not null
#  absolute_debit     :decimal(19, 4)   default(0.0), not null
#  balance            :decimal(19, 4)   default(0.0), not null
#  created_at         :datetime         not null
#  creator_id         :integer
#  credit             :decimal(19, 4)   default(0.0), not null
#  currency           :string           not null
#  debit              :decimal(19, 4)   default(0.0), not null
#  financial_year_id  :integer
#  id                 :integer          not null, primary key
#  journal_id         :integer          not null
#  lock_version       :integer          default(0), not null
#  number             :string           not null
#  printed_on         :date             not null
#  real_balance       :decimal(19, 4)   default(0.0), not null
#  real_credit        :decimal(19, 4)   default(0.0), not null
#  real_currency      :string           not null
#  real_currency_rate :decimal(19, 10)  default(0.0), not null
#  real_debit         :decimal(19, 4)   default(0.0), not null
#  resource_id        :integer
#  resource_type      :string
#  state              :string           not null
#  updated_at         :datetime         not null
#  updater_id         :integer
#

require 'test_helper'

class JournalEntryTest < ActiveSupport::TestCase
  test_model_actions
  test 'a journal forbids to write records before its closure date' do
    journal = journals(:journals_001)
    assert_raise ActiveRecord::RecordInvalid do
      record = journal.entries.create!(printed_on: journal.closed_on - 10)
    end
    assert_nothing_raised do
      record = journal.entries.create!(printed_on: journal.closed_on + 1)
    end
  end
  test 'cannot be updated when its journal is booked for accountant' do
    entry = journal_entries(:journal_entries_001)
    assert entry.updateable?
    entry.journal.accountant = entities(:entities_017)
    refute entry.updateable?
  end
  test 'cannot be created when in financial year exchange date range' do
    exchange = financial_year_exchanges(:financial_year_exchanges_001)
    journal = journals(:journals_008)
    entry = JournalEntry.new(journal: journal, printed_on: exchange.locked_on + 1.day)
    assert entry.valid?
    entry.printed_on = exchange.started_on + 1.day
    refute entry.valid?
  end
  test 'cannot be updated to a date in financial year exchange date range' do
    exchange = financial_year_exchanges(:financial_year_exchanges_001)
    entry = journal_entries(:journal_entries_081)
    assert entry.valid?
    entry.printed_on = exchange.started_on + 1.day
    refute entry.valid?
  end
  test 'journal is not booked for accountant when the entry has no journal' do
    entry = journal_entries(:journal_entries_001)
    entry.journal = nil
    refute entry.journal_booked_for_accountant?
  end
  test 'journal is booked for accountant when the journal is booked for accountant' do
    entry = journal_entries(:journal_entries_001)
    entry.journal.accountant = entities(:entities_017)
    assert entry.journal_booked_for_accountant?
  end
end
