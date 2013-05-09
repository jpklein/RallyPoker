Ext.define 'RallyPokerApp', {
  extend: 'Rally.app.App',
  componentCls: 'app',
  # _CurrStory: undefined,
  launch: () ->
    @_CurrStory = Ext.create 'Rally.data.WsapiDataStore', {
      model: 'User Story',
      # limit: 1,
      fetch: true,
      filters: [{
        property: 'ObjectID',
        value: 11812083096,
      }]
      autoLoad: true,
      listeners:
        load: (store, result, success) ->
          console.log result[0].data.FormattedID + ': ' + result[0].data.Name
          debugger
          return
    }
    return
}
