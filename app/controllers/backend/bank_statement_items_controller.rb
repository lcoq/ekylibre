module Backend
  class BankStatementItemsController < Backend::BaseController
    def new
      @bank_statement_item = BankStatementItem.new
      permitted_params = params.permit(:debit, :credit, :transfered_on, :letter, :bank_statement_id)
      @bank_statement_item.attributes = permitted_params
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
