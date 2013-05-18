Ext.define 'RallyPokerApp', {
  extend: 'Rally.app.App'
  componentCls: 'app'

  layout: 'card'
  items: [{
    id: 'storypicker'
    # layout: 'vbox'
    items: [{
      xtype: 'container'
      id: 'iterationfilter'
      cls: 'header'
    #   xtype:'rallyiterationcombobox'
    #   itemId:'iterationfilter'
    #   width: 300
    #   listeners:
    #     change: (combo) ->
    #       @_onIterationFilterChange combo.getRawValue
    #       return
    #     ready: (combo) ->
    #       @_onIterationFilterChange combo.getRawValue
    #       return
    #     scope: @
    }]
  }, {
    id: 'storyview'
    # dockedItems: [{
    #   xtype: 'container'
    #   layout:
    #     type: 'hbox'
    #     align: 'middle'
    #     pack: 'end'
    #   height: 100
    #   items: [{
    #     xtype: 'component'
    #     width: 200,
    #     itemId: 'storyheader'
    #     tpl: '<h2>{FormattedID}: {Name}</h2>'
    #   }]
    # }]
  }]

  launch: () ->
    @IterationsStore = Ext.create 'Rally.data.WsapiDataStore', {
      # id: 'iterationsStore'
      model: 'Iteration'
      fetch: ['Name']
      sorters: [{
        property: 'Name'
        direction: 'DESC'
      }]
      autoLoad: true
      listeners:
        load: (store, result, success) =>
          # debugger
          @IterationFilter.setValue 'Deprecated' if success
          return
    }
    @IterationFilter = Ext.create 'Ext.form.ComboBox', {
      fieldLabel: 'Choose an Iteration'
      store: @IterationsStore
      queryMode: 'local'
      displayField: 'Name'
      valueField: 'Name'
      listeners:
        change: (field, newValue, oldValue, options) =>
          @StoriesStore.load {
            filters: [{
              property: 'Iteration.Name'
              value: newValue
            }]
          }
          return
    }
    @down('#iterationfilter').add @IterationFilter

    @StoriesStore = Ext.create 'Rally.data.WsapiDataStore', {
      model: 'User Story'
      fetch: ['Name']
      sorters: [{
        property: 'Name'
        direction: 'DESC'
      }]
      # listeners:
      #   load: (store, result, success) ->
      #     debugger
      #     return
    }
    @StoryList = Ext.create 'Ext.view.View', {
      store: @StoriesStore
      tpl: new Ext.XTemplate(
        '<tpl for=".">',
          '<div style="margin-bottom: 10px;" class="storylistitem">',
            '<span>{Name}</span>',
          '</div>',
        '</tpl>'
      )
      itemSelector: 'div.storylistitem'
      emptyText: 'No stories available'
    }
    @down('#storypicker').add @StoryList

    # @CurrentStory = Ext.create 'Rally.data.WsapiDataStore', {
    #   model: 'User Story'
    #   # limit: 1,
    #   fetch: ['FormattedID', 'Name', 'LastUpdateDate', 'Description', 'Attachments', 'Notes', 'Discussion']
    #   filters: [{
    #     property: 'ObjectID'
    #     value: 11812083096
    #   }]
    #   autoLoad: true
    #   listeners:
    #     load: (store, result, success) ->
    #       console.log result[0].data.FormattedID + ': ' + result[0].data.Name
    #       debugger
    #       return
    # }
    # @down('#storieslist').reconfigure @CurrentStory
    return
}