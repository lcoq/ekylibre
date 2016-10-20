module Backend
  class FinancialYearExchangesController < Backend::BaseController
    manage_restfully only: [:new, :create]
  end
end
