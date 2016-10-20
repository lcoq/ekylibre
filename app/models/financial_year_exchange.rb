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
class FinancialYearExchange < Ekylibre::Record::Base
  belongs_to :financial_year
  # [VALIDATORS[ Do not edit these lines directly. Use `rake clean:validations`.
  validates :closed_at, timeliness: { on_or_after: -> { Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.now + 50.years } }, allow_blank: true
  validates :locked_on, presence: true, timeliness: { on_or_after: -> { Time.new(1, 1, 1).in_time_zone }, on_or_before: -> { Time.zone.today + 50.years }, type: :date }
  validates :financial_year, presence: true
  # ]VALIDATORS]

  scope :opened, -> { where(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }

  after_initialize :set_initial_values, if: :initializeable?

  private

  def initializeable?
    new_record?
  end

  def set_initial_values
    self.locked_on = Date.yesterday unless locked_on
  end
end
