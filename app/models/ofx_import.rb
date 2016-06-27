class OfxImport
  class InvalidOfxFile < RuntimeError; end
  class OfxFileHasMultipleAccounts < RuntimeError; end

  attr_reader :error, :internal_error, :bank_statement

  def initialize(file, cash)
    @file = file
    @cash = cash
  end

  def run
    read_and_parse_file or return false
    ensure_file_has_a_single_account or return false
    @bank_statement = build_bank_statement_with_items
    save_bank_statement
  end

  def recoverable?
    bank_statement.present?
  end

  private
  attr_reader :file, :cash, :parsed

  def read_and_parse_file
    begin
      @parsed = OfxParser::OfxParser.parse(file.read)
      true
    rescue => error
      @error = InvalidOfxFile.new("OFX file is invalid")
      @internal_error = error
      false
    end
  end

  def ensure_file_has_a_single_account
    return true if parsed.bank_accounts.length == 1
    @error = OfxFileHasMultipleAccounts.new("OFX file with multiple bank accounts is not supported")
    false
  end

  def ofx_statement
    parsed.bank_accounts.first.statement
  end

  def build_bank_statement_with_items
    bank_statement = build_bank_statement(cash)
    ofx_statement.transactions.each do |transaction|
      build_bank_statement_item bank_statement, transaction
    end
    bank_statement
  end

  def build_bank_statement(cash)
    cash.bank_statements.build.tap do |s|
      s.number = generate_bank_statement_number
      s.started_at = ofx_statement.start_date
      s.stopped_at = ofx_statement.end_date
    end
  end

  def build_bank_statement_item(bank_statement, transaction)
    bank_statement.items.build.tap do |i|
      i.name = transaction.payee
      i.transaction_number = transaction.fit_id
      i.transfered_on = transaction.date
      i.balance = transaction.amount.to_f
    end
  end

  def generate_bank_statement_number
    statement_duration_days = (ofx_statement.end_date - ofx_statement.start_date).to_i
    if statement_duration_days <= 99
      formatted_duration = "%02i" % statement_duration_days
      ofx_statement.start_date.strftime("%Y%m%d") + formatted_duration
    end
  end

  def save_bank_statement
    begin
      @bank_statement.save!
      true
    rescue => error
      @error = error
      false
    end
  end
end
