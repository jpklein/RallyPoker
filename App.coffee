Ext.define 'RallyPokerApp', {
  extend: 'Rally.app.App'
  componentCls: 'app'

  layout: 'card'
  items: [{
    id: 'storypicker'
    layout:
      # type: 'vbox'
      reserveScrollbar: true
    autoScroll: true
    dockedItems: [{
      items: [{
        id: 'iterationfilter'
        xtype: 'toolbar'
        # cls: 'header'
      }]
    }]
  }, {
    id: 'storyview'
    layout:
      reserveScrollbar: true
    autoScroll: true
    dockedItems: [{
      items: [{
        id: 'storyheader'
        xtype: 'toolbar'
        # cls: 'header'
        # tpl: '<h2>{FormattedID}: {Name}</h2>'
        items: [{
          id: 'storyback'
          xtype: 'button'
          html: 'Back',
          # scale: 'small'
          # ui: 'back'
        }, {
          id: 'storytitle'
          xtype: 'component'
        }]
      }]
    }]
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
      fieldLabel: 'Iteration'
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
      fetch: ['ObjectID', 'FormattedID', 'Name']
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
          '<div style="padding: .5em 0;" class="storylistitem" data-id="{ObjectID}">',
            '<span class="storylistitem-id">{FormattedID}: {Name}</span>',
          '</div>',
        '</tpl>'
      )
      itemSelector: 'div.storylistitem'
      emptyText: 'No stories available'
      listeners:
        click:
          element: 'el'
          fn: (e, t) =>
            StoryListItem = Ext.get(t).findParent '.storylistitem'
            storyListItemName = Ext.get(StoryListItem).child('.storylistitem-id').getHTML()
            Ext.get('storytitle').update storyListItemName
            @CurrentStory.load {
              filters: [{
                property: 'ObjectID'
                value: Ext.get(t).findParent('.storylistitem').getAttribute 'data-id'
              }]
            }
            @getLayout().setActiveItem 'storyview'
            return
    }
    @down('#storypicker').add @StoryList

    # Ext.getCmp('storytitle').update 'Back'
    Ext.getCmp('storyback').on 'click', () =>
      @getLayout().setActiveItem 'storypicker'
      return

    @CurrentStory = Ext.create 'Rally.data.WsapiDataStore', {
      model: 'User Story'
      # limit: 1,
      fetch: ['ObjectID', 'LastUpdateDate', 'Description', 'Attachments', 'Notes', 'Discussion']
    #   autoLoad: true
    #   listeners:
    #     load: (store, result, success) ->
    #       console.log result[0].data.FormattedID + ': ' + result[0].data.Name
    #       debugger
    #       return
    }
    @StoryPage = Ext.create 'Ext.view.View', {
      store: @CurrentStory
      tpl: new Ext.XTemplate(
        '<tpl for=".">',
          '<div class="storydetail" data-id="{ObjectID}">',
            '<span class="storydetail-date">{LastUpdateDate}</span>',
            '<div class="storydetail-description">',
              '{Description}',
            '</div>',
            '<div class="storydetail-attachments">',
              '<h3>Attachments<h3>{Attachments}',
            '</div>',
            '<div class="storydetail-notes">',
              '<h3>Notes<h3>{Notes}',
            '</div>',
            '<div class="storydetail-discussion">',
              '<h3>Discussion<h3>{Discussion}',
            '</div>',
          '</div>',
        '</tpl>'
      )
      itemSelector: 'div.storydetail'
    }
    @down('#storyview').add @StoryPage

    return
}