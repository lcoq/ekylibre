((E, $) ->
  "use strict"

  # Show date picker without its date input
  $ ->
    datePicker = $("#add-bank-statement-item-date")
    datePicker.hide()

    options =
      showOn: "button"
      buttonText: datePicker.data("label")
      onSelect: addBankStatementItem

    locale = datePicker.attr("lang")
    $.extend options, $.datepicker.regional[null], dateFormat: "yy-mm-dd"

    datePicker.datepicker options
    datePicker.attr "autocomplete", "off"

    datePickerButton = $(".bank-reconciliation-items .ui-datepicker-trigger")
    datePickerButton.addClass "btn"

  addBankStatementItem = (date) ->
    if $(".#{date} a").length
      # section for this date exists
      $(".#{date} a").click()
      return

    # Insert new date section at the right place, and add a new bank statement
    # item
    sectionHTML = $(".tmpl-date")[0].outerHTML.replace(/tmpl-date/g, date)

    dateSections = $(".date-separator:not(.tmpl-date)")
    dates = $.map(dateSections, (d) -> $(d).data("date"))
    index = dates.findIndex (d) -> d > date
    if index is -1
      $(".bank-reconciliation-items tbody").append(sectionHTML)
    else
      dateSections.eq(index).before(sectionHTML)

    $(".#{date} a").trigger "click"

  # Remove date section when it becomes empty
  $(document).on "click", "a.destroy", ->
    itemTr = $(@).closest("tr")
    prevTr = itemTr.prev("tr")
    nextTr = itemTr.next("tr")

    prevTrIsDateSeparator = prevTr.hasClass("date-separator")
    nextTrIsDateSeparator = !nextTr.length || nextTr.hasClass("date-separator")

    prevTr.deepRemove() if prevTrIsDateSeparator && nextTrIsDateSeparator
    itemTr.deepRemove()

) ekylibre, jQuery