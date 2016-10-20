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
# == Table: financial_years
#
#  accountant_id         :integer
#  closed                :boolean          default(FALSE), not null
#  code                  :string           not null
#  created_at            :datetime         not null
#  creator_id            :integer
#  currency              :string           not null
#  currency_precision    :integer
#  custom_fields         :jsonb
#  id                    :integer          not null, primary key
#  last_journal_entry_id :integer
#  lock_version          :integer          default(0), not null
#  started_on            :date             not null
#  stopped_on            :date             not null
#  updated_at            :datetime         not null
#  updater_id            :integer
#

require 'test_helper'

class FinancialYearTest < ActiveSupport::TestCase
  test_model_actions
  test 'chronology' do
    first_year = financial_years(:financial_years_001)
    assert_not_nil first_year

    assert_nil first_year.previous, 'No previous financial year expected'

    assert_not_nil first_year.next, "No next financial year found... #{first_year.attributes.inspect}"

    assert_not_nil first_year.next.previous
    assert_equal first_year, first_year.next.previous

    assert_not_nil FinancialYear.at(Time.now + 49.years)
  end
  test 'accountant can be set' do
    year = financial_years(:financial_years_001)
    year.accountant = entities(:entities_017)
    assert year.valid?
  end
  test 'cannot create exchange without accountant' do
    year = financial_years(:financial_years_001)
    refute year.can_create_exchange?
  end
  test 'cannot create exchange without journal booked by the accountant' do
    year = financial_years(:financial_years_025)
    year.accountant.booked_journals.destroy_all
    refute year.can_create_exchange?
  end
  test 'create exchange when it has no opened exchange but journal booked by the accountant' do
    year = financial_years(:financial_years_025)
    FinancialYearExchange.where(financial_year_id: year.id).update_all closed_at: Time.zone.now
    assert year.can_create_exchange?
  end
  test 'cannot create exchange with opened exchanges' do
    year = financial_years(:financial_years_025)
    refute year.can_create_exchange?
  end
  test 'destroy exchanges on destroy' do
    year = financial_years(:financial_years_025)
    exchange_ids = year.exchanges.map(&:id)
    year.destroy
    assert FinancialYearExchange.where(id: exchange_ids).empty?
  end
end
