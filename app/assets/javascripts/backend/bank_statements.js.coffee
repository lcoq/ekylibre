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
      @button.addClass "btn"

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

  selectLine = (line) ->
    return if lineIsReconciliated(line)
    line.addClass "selected"
    updateRemainingReconciliationBalance()
    hideOrShowCompleteButtons()

  deselectLine = (line) ->
    line.removeClass "selected"
    updateRemainingReconciliationBalance()
    hideOrShowCompleteButtons()

  clearReconciliatedLinesWithLetter = (letter) ->
    return unless letter
    linesWithLetter = reconciliatedLines().filter ->
      lineReconciliationLetter($(@)) is letter
    linesWithLetter.find(".bank-statement-letter:not(input)").text("")
    linesWithLetter.find("input.bank-statement-letter").val(null)
    showOrHideClearButtons()
    releaseReconciliationLetter(letter)

  showOrHideClearButtons = ->
    notReconciliatedLines().find(".clear a").hide()
    reconciliatedLines().find(".clear a").show()

  updateRemainingReconciliationBalance = ->
    selectedLines = lines().filter(".selected")
    if selectedLines.length >= 2
      $(".remaining-reconciliation-balance").show()
    else
      $(".remaining-reconciliation-balance").hide()
    # TODO update balance

  hideOrShowCompleteButtons = ->
    $(".journal-entry-item-type.selected .complete a").show()
    $(".journal-entry-item-type:not(.selected) .complete a").hide()

  selectedJournalEntryItemsBalance = ->
    selectedJournalEntryItems = $(".journal-entry-item-type.selected")
    debit = selectedJournalEntryItems.find(".debit").sum()
    credit = selectedJournalEntryItems.find(".credit").sum()
    debit - credit

  completeJournalEntryItems = (clickedLine) ->
    balance = selectedJournalEntryItemsBalance()
    urlParam = if balance > 0 then "credit=#{balance}" else "debit=#{-balance}"
    date = clickedLine.prevAll(".date-separator:first").data("date")
    buttonInDateSection = $(".#{date} a")
    buttonInDateSection.one "ajax:beforeSend", (event, xhr, settings) ->
      settings.url += "&#{urlParam}"
    buttonInDateSection.click()
    # TODO reconciliate

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