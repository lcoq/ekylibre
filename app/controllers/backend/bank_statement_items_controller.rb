module Backend
  class BankStatementItemsController < Backend::BaseController
    def new
      @bank_statement_item = BankStatementItem.new
      if params[:bank_statement_id]
        bank_statement = BankStatement.find_by(id: params[:bank_statement_id])
        @bank_statement_item.bank_statement = bank_statement
      end
      if request.xhr?
        render partial: "backend/bank_statement_items/row_form", object: @bank_statement_item
      else
        redirect_to_back
      end
    end
  end
end
