class @DataTable

  constructor: (@tableSelector = '', @columns = [], @ajaxOptions = {}) ->
    @elem = jQuery(@tableSelector)

  init: ->
    @elem.dataTable
      processing: true
      responsive: true
      ajax: @ajaxOptions
      pagingType: 'full_numbers'
      'columnDefs': [ {
        'className': 'dt-center'
        'targets': '_all'
      } ]
      columns: @columns
      fnDrawCallback: (oSettings) ->

class @DataTableColumn

  constructor: (@field) ->
    @fieldName = @field.name
    @type = @field.type
    @editable = @field.editable
    @renderOverride = @field.renderOverride

  renderSpan: (value, _id) ->
    output = value
    if @type == 'number'
      output = formatter.format(output);
    return output

  init: ->
    self = this
    hash = data: @fieldName
    renderer = null
    if @renderOverride
      override = @renderOverride
      renderer = (data, type, full, meta) ->
        return override(full)
    else if @type == 'currency'
      renderer = (data, type, full, meta) ->
        return formatter.format(data)
    else
      renderer = (data, type, full, meta) ->
        return data
    if renderer
      hash['render'] = renderer
    return hash