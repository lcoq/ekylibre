# == License
# Ekylibre - Simple agricultural ERP
# Copyright (C) 2008-2011 Brice Texier, Thibaud Merigon
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

module Backend
  class BankStatementsController < Backend::BaseController
    manage_restfully(
      except: :update,
      started_at: 'Cash.find(params[:cash_id]).last_bank_statement.stopped_at+1 rescue (Time.zone.today-1.month-2.days)'.c,
      stopped_at: "Cash.find(params[:cash_id]).last_bank_statement.stopped_at>>1 rescue (Time.zone.today-2.days)".c,
      redirect_to: "{action: :edit_items, id: 'id'.c}".c
    )

    unroll

    list(order: { started_at: :desc }) do |t|
      t.action :edit_items
      t.action :reconciliation
      t.action :edit
      t.action :destroy
      t.column :number, url: true
      t.column :cash,   url: true
      t.column :started_at
      t.column :stopped_at
      t.column :debit,  currency: true
      t.column :credit, currency: true
    end

    # Displays the main page with the list of bank statements
    def index
      redirect_to backend_cashes_path
    end

    list(:items, model: :bank_statement_items, conditions: { bank_statement_id: "params[:id]".c }, order: :id) do |t|
      t.column :journal, url: true
      t.column :transfered_on
      t.column :name
      t.column :account, url: true
      t.column :debit, currency: :currency
      t.column :credit, currency: :currency
    end

    def edit_items
      return unless @bank_statement = find_and_check
      if request.post?
        items = (params[:items] || {}).values
        if @bank_statement.save_with_items(items)
          redirect_to params[:redirect] || { action: :show, id: @bank_statement.id }
          return
        end
      end
    end

    def update
      return unless @bank_statement = find_and_check
      @bank_statement.attributes = permitted_params
      items = (params[:items] || {}).values
      if @bank_statement.save_with_items(items)
        redirect_to params[:redirect] || { action: :show, id: @bank_statement.id }
        return
      end
      t3e @bank_statement.attributes
    end

    def reconciliation
      return unless @bank_statement = find_and_check
      if request.post?
        @bank_statement.attributes = permitted_params
        items = (params[:items] || {}).values
        if @bank_statement.save_with_items(items)
          redirect_to params[:redirect] || { action: :show, id: @bank_statement.id }
          return
        end
      end
      bank_statement_items = @bank_statement.items
      journal_entry_items = @bank_statement.eligible_journal_entry_items
      # TODO restore :need_entries_to_point translation
      unless journal_entry_items.any?
        notify_error :need_entries_to_point
        redirect_to params[:redirect] || { action: :show, id: @bank_statement.id }
        return
      end
      @items = bank_statement_items + journal_entry_items
      @items_grouped_by_date = @items.group_by do |item|
        BankStatementItem === item ? item.transfered_on : item.printed_on
      end.sort
    end
  end
end
