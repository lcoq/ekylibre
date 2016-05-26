((E, $) ->
  "use strict"

  # Create bank statement items and date sections

  $ ->
    container = $(".add-bank-statement-item-cont")
    new DatePickerButton(container, createBankStatementItemAndDateSection)

  class DatePickerButton
    # Used to display a datepicker on a button click while the date input
    # remains hidden
    constructor: (@container, @onSelect) ->
      @dateInput = @container.find("input[type=date]")
      @_initializeDatePicker()

    _initializeDatePicker: ->
      @dateInput.hide()

      options =
        showOn: "button"
        buttonText: @dateInput.data("label")
        onSelect: @onSelect

      locale = @dateInput.attr("lang")
      $.extend options, $.datepicker.regional[null], dateFormat: "yy-mm-dd"

      @dateInput.datepicker options
      @dateInput.attr "autocomplete", "off"

      @button = @container.find(".ui-datepicker-trigger")
      @button.addClass(classes) if classes = @dateInput.data("classes")

  createBankStatementItemInDateSection = (date) ->
    buttonInDateSection = $(".#{date} a")
    return false unless buttonInDateSection.length
    buttonInDateSection.click()
    true

  insertDateSection = (date) ->
    html = $(".tmpl-date")[0].outerHTML.replace(/tmpl-date/g, date)
    dateSections = $(".date-separator:not(.tmpl-date)")
    nextDateSection = dateSections.filter( -> $(@).data("date") > date).first()
    if nextDateSection.length
      nextDateSection.before html
    else
      $(".bank-reconciliation-items tbody").append html

  createBankStatementItemAndDateSection = (date) ->
    return if createBankStatementItemInDateSection(date)
    insertDateSection(date)
    createBankStatementItemInDateSection(date)

  # Destroy bank statement items and date sections

  $(document).on "click", "a.destroy", ->
    bankStatementItem = $(@).closest(lines())
    letter = lineReconciliationLetter(bankStatementItem)
    destroyBankStatementItem(bankStatementItem)
    clearReconciliatedLinesWithLetter(letter)
    updateReconciliationBalances()
    return false

  isDateSection = (line) ->
    return line.hasClass("date-separator")

  destroyBankStatementItem = (bankStatementItemLine) ->
    previousLine = bankStatementItemLine.prev("tr")
    nextLine = bankStatementItemLine.next("tr")

    if isDateSection(previousLine) && (!nextLine.length || isDateSection(nextLine))
      previousLine.deepRemove()
    bankStatementItemLine.deepRemove()

  # Select/deselect lines

  nextReconciliationLetters = null

  getNextReconciliationLetter = ->
    nextReconciliationLetters.shift()

  releaseReconciliationLetter = (letter) ->
    nextReconciliationLetters.unshift letter

  $ ->
    nextReconciliationLetters = $(".bank-reconciliation-items").data("next-letters")
    showOrHideClearButtons()
    updateReconciliationBalances()

  $(document).on "click", ".bank-statement-item-type:not(.selected), .journal-entry-item-type:not(.selected)", (event) ->
    return if $(event.target).is('input,a')
    selectLine $(@)

  $(document).on "click", ".bank-statement-item-type.selected, .journal-entry-item-type.selected", (event) ->
    return if $(event.target).is('input,a')
    deselectLine $(@)

  $(document).on "click", ".bank-statement-item-type .clear a, .journal-entry-item-type .clear a", ->
    line = $(@).closest(lines())
    letter = lineReconciliationLetter(line)
    clearReconciliatedLinesWithLetter(letter)
    return false

  $(document).on "click", ".journal-entry-item-type .complete a", ->
    completeJournalEntryItems $(@).closest(".journal-entry-item-type")
    return false

  $(document).on "change keyup", ".bank-statement-item-type input.debit, .bank-statement-item-type input.credit", ->
    line = $(@).closest(lines())
    if lineIsReconciliated(line)
      letter = lineReconciliationLetter(line)
      clearReconciliatedLinesWithLetter(letter)
    updateReconciliationBalances()

  selectLine = (line) ->
    return if lineIsReconciliated(line)
    line.addClass "selected"
    reconciliateLinesIfValid()
    hideOrShowCompleteButtons()

  deselectLine = (line) ->
    line.removeClass "selected"
    hideOrShowCompleteButtons()

  reconciliateLinesIfValid = ->
    selectedLines = lines().filter(".selected")
    return unless linesAreValidForReconciliation(selectedLines)
    letter = getNextReconciliationLetter()
    reconciliateLines(selectedLines, letter)

  linesAreValidForReconciliation = (lines) ->
    journalEntryItems = lines.filter(".journal-entry-item-type")
    bankStatementItems = lines.filter(".bank-statement-item-type")
    journalEntryItemsDebit = journalEntryItems.find(".debit").sum()
    journalEntryItemsCredit = journalEntryItems.find(".credit").sum()
    journalEntryItemsBalance = journalEntryItemsDebit - journalEntryItemsCredit
    bankStatementItemsDebit = bankStatementItems.find(".debit").sum()
    bankStatementItemsCredit = bankStatementItems.find(".credit").sum()
    bankStatementItemsBalance = bankStatementItemsDebit - bankStatementItemsCredit
    journalEntryItemsBalance is -bankStatementItemsBalance

  reconciliateLines = (lines, letter) ->
    lines.find(".bank-statement-letter:not(input)").text(letter)
    lines.find("input.bank-statement-letter").val(letter)
    lines.removeClass("selected")
    updateReconciliationBalances()
    hideOrShowCompleteButtons()
    showOrHideClearButtons()

  clearReconciliatedLinesWithLetter = (letter) ->
    return unless letter
    linesWithLetter = reconciliatedLines().filter ->
      lineReconciliationLetter($(@)) is letter
    linesWithLetter.find(".bank-statement-letter:not(input)").text("")
    linesWithLetter.find("input.bank-statement-letter").val(null)
    showOrHideClearButtons()
    releaseReconciliationLetter(letter)
    updateReconciliationBalances()

  showOrHideClearButtons = ->
    notReconciliatedLines().find(".clear a").hide()
    reconciliatedLines().find(".clear a").show()

  updateReconciliationBalances = ->
    all = lines().filter(".bank-statement-item-type")
    allDebit = all.find(".debit").sum()
    allCredit = all.find(".credit").sum()
    allBalance = allDebit - allCredit

    reconciliated = reconciliatedLines().filter(".bank-statement-item-type")
    reconciliatedDebit = reconciliated.find(".debit").sum()
    reconciliatedCredit = reconciliated.find(".credit").sum()
    reconciliatedBalance = reconciliatedDebit - reconciliatedCredit

    remainingDebit = allDebit - reconciliatedDebit
    remainingCredit = allCredit - reconciliatedCredit

    updateReconciliationBalance(reconciliatedDebit, reconciliatedCredit)
    updateRemainingReconciliationBalance(remainingDebit, remainingCredit)

    $(".reconciliated-debit").toggleClass("valid", allDebit is reconciliatedDebit)
    $(".reconciliated-credit").toggleClass("valid", allCredit is reconciliatedCredit)
    $(".remaining-reconciliated-debit").toggleClass("valid", remainingDebit is 0)
    $(".remaining-reconciliated-credit").toggleClass("valid", remainingCredit is 0)

  updateReconciliationBalance = (debit, credit) ->
    $(".reconciliated-debit").text(debit.toFixed(2))
    $(".reconciliated-credit").text(credit.toFixed(2))

  updateRemainingReconciliationBalance = (debit, credit) ->
    $(".remaining-reconciliated-debit").text(debit.toFixed(2))
    $(".remaining-reconciliated-credit").text(credit.toFixed(2))

  hideOrShowCompleteButtons = ->
    $(".journal-entry-item-type.selected .complete a").show()
    $(".journal-entry-item-type:not(.selected) .complete a").hide()

  completeJournalEntryItems = (clickedLine) ->
    selectedJournalEntryItems = $(".journal-entry-item-type.selected")
    debit = selectedJournalEntryItems.find(".debit").sum()
    credit = selectedJournalEntryItems.find(".credit").sum()
    balance = debit - credit
    balanceParam = if balance > 0 then "credit=#{balance}" else "debit=#{-balance}"

    reconciliationLetter = getNextReconciliationLetter()
    reconciliationLetterParam = "letter=#{reconciliationLetter}"

    urlParams = "#{balanceParam}&#{reconciliationLetterParam}"
    date = clickedLine.prevAll(".date-separator:first").data("date")
    buttonInDateSection = $(".#{date} a")
    buttonInDateSection.one "ajax:beforeSend", (event, xhr, settings) ->
      settings.url += "&#{urlParams}"
    buttonInDateSection.one "ajax:complete", (event, xhr, status) ->
      # use ajax:complete to ensure elements are already added to the DOM
      return unless status is "success"
      reconciliateLines(selectedJournalEntryItems, reconciliationLetter)
    buttonInDateSection.click()

  lines = ->
    $(".bank-statement-item-type,.journal-entry-item-type")

  notReconciliatedLines = ->
    lines().filter -> not lineIsReconciliated($(@))

  reconciliatedLines = ->
    lines().filter -> lineIsReconciliated($(@))

  lineIsReconciliated = (line) ->
    !!lineReconciliationLetter(line)

  lineReconciliationLetter = (line) ->
    line.find("input.bank-statement-letter").val()

) ekylibre, jQuery