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
    bankStatementItem = $(@).closest("tr")
    destroyBankStatementItem(bankStatementItem)

  isDateSection = (tableRow) ->
    return tableRow.hasClass("date-separator")

  destroyBankStatementItem = (bankStatementItemTableRow) ->
    previousTableRow = bankStatementItemTableRow.prev("tr")
    nextTableRow = bankStatementItemTableRow.next("tr")

    if isDateSection(previousTableRow) && (!nextTableRow.length || isDateSection(nextTableRow))
      previousTableRow.deepRemove()
    bankStatementItemTableRow.deepRemove()

) ekylibre, jQuery