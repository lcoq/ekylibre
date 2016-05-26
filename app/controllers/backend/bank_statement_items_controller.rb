module Backend
  class BankStatementItemsController < Backend::BaseController
    def new
      @bank_statement_item = BankStatementItem.new
      if params[:debit]
        @bank_statement_item.debit = params[:debit]
      end
      if params[:credit]
        @bank_statement_item.credit = params[:credit]
      end
      if params[:transfered_on]
        @bank_statement_item.transfered_on = params[:transfered_on]
      end
      if params[:letter]
        @bank_statement_item.letter = params[:letter]
      end
      if params[:bank_statement_id]
        bank_statement = BankStatement.find_by(id: params[:bank_statement_id])
        @bank_statement_item.bank_statement = bank_statement
      end
      if request.xhr?
        if params[:reconciliation]
          render partial: "backend/bank_statement_items/reconciliation_row_form", object: @bank_statement_item
        else
          render partial: "backend/bank_statement_items/row_form", object: @bank_statement_item
        end
      else
        redirect_to_back
      end
    end
  end
end
