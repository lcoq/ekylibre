# coding: utf-8
class FinancialYearExchangeExport
  class CsvExport
    def initialize(exchange)
      @exchange = exchange
    end

    def export(&block)
      filename = "journal-entries-export.csv"
      tempfile = Tempfile.new(filename)
      write_csv tempfile.path
      yield tempfile, filename
    ensure
      tempfile.close!
    end

    private
    attr_reader :exchange

    def write_csv(filepath)
      CSV.open(filepath, 'w+') do |csv|
        csv << [ 'Jour', 'Numéro de compte', 'Tiers', 'Numéro de pièce', 'Libellé écriture', 'Débit', 'Crédit', 'Lettrage' ]
        exchange.journal_entries.includes(:items).order(printed_on: :desc).each do |entry|
          entry.items.each do |entry_item|
            csv << [ entry.printed_on, entry_item.account.number, entry.updater.name, entry.number, entry_item.name, entry_item.absolute_debit, entry_item.absolute_credit, entry_item.letter ]
          end
        end
      end
    end
  end
end
