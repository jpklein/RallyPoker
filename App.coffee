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
        # xtype: 'container'
        id: 'iterationfilter'
        # cls: 'header'
      }]
    }]
  }, {
    id: 'storyview'
    layout:
      reserveScrollbar: true
    autoScroll: true
    dockedItems: [{
    #   xtype: 'container'
    #   layout:
    #     type: 'hbox'
    #     align: 'stretch'
    #     pack: 'end'
    #   height: 100
      items: [{
    #     xtype: 'component'
    #     width: 200,
        id: 'storyheader'
        # cls: 'header'
    #     tpl: '<h2>{FormattedID}: {Name}</h2>'
        items: [{
        #   xtype: 'button'
        #   text: 'Back',
        #   # scale: 'small'
        #   # ui: 'back'
        #   handler: () =>
        #     @getLayout().setActiveItem 'storypicker'
        #     return
        # }, {
          id: 'storytitle'
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
            storyListItem = Ext.get(t).findParent '.storylistitem'
            storyListItemId = Ext.get(storyListItem).child('.storylistitem-id').getHTML()
            Ext.get('storytitle').update storyListItemId
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

    @BackButton = Ext.create 'Ext.Button', {
      text: 'Back',
      # scale: 'small'
      # ui: 'back'
      handler: () =>
        @getLayout().setActiveItem 'storypicker'
        return
    }
    @down('#storyheader').add @BackButton

    @CurrentStory = Ext.create 'Rally.data.WsapiDataStore', {
      model: 'User Story'
      # limit: 1,
      fetch: ['ObjectID', 'FormattedID', 'Name', 'LastUpdateDate', 'Description', 'Attachments', 'Notes', 'Discussion']
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
            '<h2 class="storydetail-id">{FormattedID}: {Name}</h2>',
            '<span class="storydetail-date">{LastUpdateDate}</span>',
            '<div class="storydetail-description">',
              '<h3>Description<h3>{Description}',
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