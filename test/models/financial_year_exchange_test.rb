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
# == Table: financial_year_exchanges
#
#  closed_at         :datetime
#  created_at        :datetime         not null
#  creator_id        :integer
#  financial_year_id :integer          not null
#  id                :integer          not null, primary key
#  lock_version      :integer          default(0), not null
#  locked_on         :date             not null
#  updated_at        :datetime         not null
#  updater_id        :integer
#
require 'test_helper'

class FinancialYearExchangeTest < ActiveSupport::TestCase
  test_model_actions
  test 'opened scope includes opened exchanges' do
    exchange = financial_year_exchanges(:financial_year_exchanges_001)
    assert FinancialYearExchange.opened.pluck(:id).include?(exchange.id)
  end
  test 'opened scope does not include closed exchanges' do
    exchange = financial_year_exchanges(:financial_year_exchanges_001)
    exchange.update_column :closed_at, Time.zone.now
    refute FinancialYearExchange.opened.pluck(:id).include?(exchange.id)
  end
  test 'closed scope includes closed exchanges' do
    exchange = financial_year_exchanges(:financial_year_exchanges_001)
    exchange.update_column :closed_at, Time.zone.now
    assert FinancialYearExchange.closed.pluck(:id).include?(exchange.id)
  end
  test 'closed scope does not include opened exchanges' do
    exchange = financial_year_exchanges(:financial_year_exchanges_001)
    refute FinancialYearExchange.closed.pluck(:id).include?(exchange.id)
  end
  test 'is valid' do
    exchange = financial_year_exchanges(:financial_year_exchanges_001)
    assert exchange.valid?
  end
  test 'initialize with locked on set to yesterday' do
    yesterday = Date.yesterday
    exchange = FinancialYearExchange.new
    assert_equal yesterday, exchange.locked_on
  end
  test 'does not initialize with locked on set to yesterday when locked on is filled' do
    today = Date.today
    exchange = FinancialYearExchange.new(locked_on: today)
    assert_equal today, exchange.locked_on
  end
  test 'needs a locked on' do
    exchange = financial_year_exchanges(:financial_year_exchanges_001)
    exchange.locked_on = nil
    refute exchange.valid?
  end
  test 'locked on is before financial year stopped on' do
    exchange = financial_year_exchanges(:financial_year_exchanges_001)
    exchange.locked_on = exchange.financial_year.stopped_on + 1.day
    refute exchange.valid?
  end
  test 'needs a financial year' do
    exchange = financial_year_exchanges(:financial_year_exchanges_001)
    exchange.financial_year = nil
    refute exchange.valid?
  end
  test 'started on is the financial year started on when the financial year has no other exchange' do
    financial_year = financial_years(:financial_years_024)
    exchange = FinancialYearExchange.new(financial_year: financial_year)
    assert_equal financial_year.started_on, exchange.started_on
  end
  test 'started on is the latest financial year exchange locked on when the financial year has other exchanges' do
    financial_year = financial_years(:financial_years_025)
    previous_exchange = financial_year_exchanges(:financial_year_exchanges_001)
    exchange = FinancialYearExchange.new(financial_year: financial_year)
    assert_equal previous_exchange.locked_on, exchange.started_on
  end
  test 'create closes journal entries from non-booked journal between financial year start and exchange lock when the financial year has no other exchange' do
    financial_year = financial_years(:financial_years_024)
    locked_on = financial_year.stopped_on - 2.days
    entries_range = financial_year.started_on..locked_on

    draft_entries = JournalEntry.joins(:journal).where(printed_on: entries_range, state: :draft, journals: { accountant_id: nil }).to_a
    assert draft_entries.any?
    confirmed_entries = JournalEntry.joins(:journal).where(printed_on: entries_range, state: :confirmed, journals: { accountant_id: nil }).to_a
    assert confirmed_entries.any?

    exchange = FinancialYearExchange.new(financial_year: financial_year, locked_on: locked_on)
    assert exchange.save
    assert draft_entries.all? { |e| e.reload.closed? }
    assert confirmed_entries.all? { |e| e.reload.closed? }
  end
  test 'create does not close journal entries from booked journals' do
    financial_year = financial_years(:financial_years_024)
    locked_on = financial_year.stopped_on - 2.days
    entries_range = financial_year.started_on..locked_on
    draft_entries = JournalEntry.joins(:journal).where(printed_on: entries_range, state: :draft).where.not(journals: { accountant_id: nil }).to_a
    assert draft_entries.any?

    exchange = FinancialYearExchange.new(financial_year: financial_year, locked_on: locked_on)
    assert exchange.save
    assert draft_entries.all? { |e| e.reload.draft? }
  end
  test 'create does not close journal entries not between financial year start and exchange lock when the financial year has no other exchange' do
    financial_year = financial_years(:financial_years_024)
    locked_on = financial_year.stopped_on - 2.days
    entries_range = financial_year.started_on..locked_on

    draft_entries = JournalEntry.joins(:journal).where(state: :draft, journals: { accountant_id: nil }).where.not(printed_on: entries_range).to_a
    assert draft_entries.any?
    confirmed_entries = JournalEntry.joins(:journal).where(state: :confirmed, journals: { accountant_id: nil }).where.not(printed_on: entries_range).to_a
    assert confirmed_entries.any?

    exchange = FinancialYearExchange.new(financial_year: financial_year, locked_on: locked_on)
    assert exchange.save
    assert draft_entries.all? { |e| e.reload.draft? }
    assert confirmed_entries.all? { |e| e.reload.confirmed? }
  end
  test 'create closes journal entries from non-booked journal between previous and actual exchanges lock' do
    financial_year = financial_years(:financial_years_025)
    previous_exchange = financial_year_exchanges(:financial_year_exchanges_001)
    previous_exchange.update_column :closed_at, Time.zone.now
    locked_on = financial_year.stopped_on - 2.days
    entries_range = previous_exchange.locked_on..locked_on

    draft_entries = JournalEntry.joins(:journal).where(printed_on: entries_range, state: :draft, journals: { accountant_id: nil }).to_a
    assert draft_entries.any?
    confirmed_entries = JournalEntry.joins(:journal).where(printed_on: entries_range, state: :confirmed, journals: { accountant_id: nil }).to_a
    assert confirmed_entries.any?

    exchange = FinancialYearExchange.new(financial_year: financial_year, locked_on: locked_on)
    assert exchange.save
    assert draft_entries.all? { |e| e.reload.closed? }
    assert confirmed_entries.all? { |e| e.reload.closed? }
  end
  test 'create does not close journal entries not between previous and actual exchanges lock' do
    financial_year = financial_years(:financial_years_025)
    previous_exchange = financial_year_exchanges(:financial_year_exchanges_001)
    previous_exchange.update_column :closed_at, Time.zone.now
    locked_on = financial_year.stopped_on - 2.days
    entries_range = previous_exchange.locked_on..locked_on

    draft_entries = JournalEntry.joins(:journal).where(state: :draft, journals: { accountant_id: nil }).where.not(printed_on: entries_range).to_a
    assert draft_entries.any?
    confirmed_entries = JournalEntry.joins(:journal).where(state: :confirmed, journals: { accountant_id: nil }).where.not(printed_on: entries_range).to_a
    assert confirmed_entries.any?

    exchange = FinancialYearExchange.new(financial_year: financial_year, locked_on: locked_on)
    assert exchange.save
    assert draft_entries.all? { |e| e.reload.draft? }
    assert confirmed_entries.all? { |e| e.reload.confirmed? }
  end
end
