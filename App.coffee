Ext.define 'RallyPokerApp', {
  extend: 'Rally.app.App'
  id: 'RallyPokerApp'
  componentCls: 'app'
  models: []
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

  Base62: do () ->
    # Adapted from Javascript Base62 encode/decoder
    # Copyright (c) 2013 Andrew Nesbitt
    # See LICENSE at https://github.com/andrew/base62.js

    # Library that obfuscates numeric strings as case-sensitive,
    # alphanumeric strings
    chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

    {
      encode: (i) ->
        return if i == 0
        s = ''
        while i > 0
          s = chars[i % 62] + s
          i = Math.floor(i / 62)
        s
      decode: (a,b,c,d) ->
        `for (
          b = c = (a === (/\W|_|^$/.test(a += "") || a)) - 1;
          d = a.charCodeAt(c++);
        ) {
          b = b * 62 + d - [, 48, 29, 87][d >> 5];
        }
        return b`
        return
    }

  PokerMessage: do () ->
    # helper fn to escape RegEx-reserved strings
    esc = (str) -> str.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"
    # [strings] ==> encoded message + custom delimiters
    sep = ['/', '&']
    msg = new RegExp "^" + sep[0] + "\\w+(?:" + sep[1] + "\\w+)+$"
    env = ['[[', ']]']
    pkg = new RegExp esc(env[0]) + "(" + sep[0] + ".+?)" + esc(env[1])

    {
      compile: (M) ->
        fn = arguments[1] || (x) -> x
        a = Ext.clone M
        a[0] = sep[0] + fn M[0]
        s = if a.length == 1 then a[0] else a.reduce (p, c, i) -> p + sep[1] + fn c
        env[0] + s + env[1]
      extract: (s) ->
        if s and a = s.match pkg then a.pop() else false
      parse: (s) ->
        return false if not msg.test s
        M = s.slice(1).split sep[1]
        if not arguments[1]? then M else arguments[1] i for i in M by 1
    }

  launch: () ->
    @Account = @getContext().getUser()
    projectID = @getContext().getProject().ObjectID

    Ext.create 'Rally.data.WsapiDataStore',
      model: 'Project'
      fetch: ['TeamMembers']
      filters: [{ property: 'ObjectID', value: projectID }]
      autoLoad: true
      listeners:
        scope: @
        # beforeload: (store) ->
        #   @getEl().mask 'Loading...'
        load: (store, result, success) ->
          return if not success
          @Account.ref = '/user/' + @Account.ObjectID
          @Account.isTeamMember = false

          for M in result[0].data.TeamMembers
            @Account.isTeamMember = true if M._ref == @Account.ref

          @down('#storypicker').add
            xtype: 'component'
            html: 'You are a ' + if @Account.isTeamMember then 'Pig. Oink, oink.' else 'Chicken. Try harder!'
          # @getEl().unmask()
          return

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
            StoryListItem = Ext.get(Ext.get(t).findParent '.storylistitem')

            storyListItemName = StoryListItem.child('.storylistitem-id').getHTML()
            Ext.get('storytitle').update storyListItemName

            storyListItemId = StoryListItem.getAttribute 'data-id'
            @CurrentStory.load {
              filters: [{
                property: 'ObjectID'
                value: storyListItemId
              }]
            }
            # always load the store so that its view is reprocessed.
            @DiscussionsStore.load {
              filters: [{
                property: 'Artifact.ObjectID'
                value: storyListItemId
              }]
            }
            @getLayout().setActiveItem 'storyview'
            return
    }
    @down('#storypicker').add @StoryList

    Ext.getCmp('storyback').on 'click', () =>
      @getLayout().setActiveItem 'storypicker'
      return

    @CurrentStory = Ext.create 'Rally.data.WsapiDataStore', {
      model: 'userstory'
      limit: 1,
      fetch: ['ObjectID', 'LastUpdateDate', 'Description', 'Attachments', 'Notes', 'Discussion']
    }
    @StoryPage = Ext.create 'Ext.view.View', {
      store: @CurrentStory
      tpl: new Ext.XTemplate(
        '<tpl for=".">',
        '<div class="storydetail" data-id="{ObjectID}">',
          '<small class="storydetail-date">Last Updated: {[this.prettyDate(values.LastUpdateDate)]}</small>',
          '<div class="storydetail-description">',
            '{Description}',
          '</div>',
          '<div class="storydetail-attachments">',
            '<h3>Attachments<h3>{Attachments}',
          '</div>',
          '<div class="storydetail-notes">',
            '<h3>Notes<h3>{Notes}',
          '</div>',
        '</div>',
        '</tpl>',
        {
          # Adapted from JavaScript Pretty Date
          # Copyright (c) 2011 John Resig (ejohn.org)
          # Licensed under the MIT and GPL licenses.

          # Takes an ISO time and returns a string representing how
          # long ago the date represents.
          prettyDate: (date) ->
            diff = (((new Date()).getTime() - date.getTime()) / 1000)
            day_diff = Math.floor(diff / 86400)
            return if isNaN(day_diff) || day_diff < 0 || day_diff >= 31
            day_diff == 0 && (diff < 60 && "just now" || diff < 120 && "1 minute ago" || diff < 3600 && Math.floor(diff / 60) + " minutes ago" || diff < 7200 && "1 hour ago" || diff < 86400 && Math.floor(diff / 3600) + " hours ago") || day_diff == 1 && "Yesterday" || day_diff < 7 && day_diff + " days ago" || day_diff < 31 && Math.ceil(day_diff / 7) + " weeks ago"
        }
      )
      itemSelector: 'div.storydetail'
    }
    @down('#storyview').add @StoryPage

    # custom field definition to parse poker messages from discussion items.
    @DiscussionMessageField = new Ext.data.Field {
      name: 'Message'
      type: 'string'
      convert: (v, rec) =>
        if message = @PokerMessage.extract rec.get 'Text'
          # Expected message contents: UserID + 4-bit point-selection value
          (@PokerMessage.parse message, @Base62.decode).pop()
        else
          false
    }
    Rally.data.ModelFactory.getModel {
      type: 'conversationpost'
      success: (Model) =>
        @models['conversationpost'] = Ext.clone Model
        Model.prototype.fields.items.push @DiscussionMessageField
        Model.setFields Model.prototype.fields.items
        return
    }
    @DiscussionsStore = Ext.create 'Rally.data.WsapiDataStore', {
      model: 'conversationpost'
      fetch: ['User', 'CreationDate', 'Text', 'Message']
    }
    @DiscussionThread = Ext.create 'Ext.view.View', {
      store: @DiscussionsStore
      tpl: new Ext.XTemplate(
        '<tpl for=".">',
          '<tpl if="Message !== false">',
            '<tpl if="!this.shownMessages">{% this.shownMessages = true %}',
              '<div class="messagethread">',
                '<h3>Who\'s Voted</h3>',
                '<ul class="messageitems">',
            '</tpl>',
          '</tpl>',
          '<tpl if="xindex == xcount && this.shownMessages">',
            '<tpl for="whoVoted">',
                  '<li>{name} at {when}</li>',
            '</tpl>'
                '</ul>',
              '</div>',
          '</tpl>',
        '</tpl>',
        '<div class="estimateselector"></div>'
        '<tpl for=".">',
          '<tpl if="Message === false">',
            '<tpl if="!this.shownDiscussion">{% this.shownDiscussion = true %}',
              '<div class="discussionthread">',
                '<h3>Discussion</h3>',
            '</tpl>'
                '<div class="discussionitem">',
                  '<small class="discussionitem-id">{User._refObjectName}: {CreationDate}</small>',
                  '<p class="discussionitem-text">{Text}</p>',
                '</div>',
          '</tpl>',
          '<tpl if="xindex == xcount && this.shownDiscussion">',
              '</div>',
          '</tpl>',
        '</tpl>',
        {
          accountVoted: false
          shownMessages: false
          shownDiscussion: false
          whoVoted: {}
        }
      )
      itemSelector: 'div.discussionitem'
      accountRef: "/user/" + Rally.environment.getContext().getUser().ObjectID
      prepareData: (data, index, record) ->
        if data.Message
          `var timestamp = data.CreationDate.getTime()`
          if not @tpl.whoVoted[data.User._ref]? or timestamp > @tpl.whoVoted[data.User._ref].when
            @tpl.whoVoted[data.User._ref] =
              post: data.ObjectID
              when: timestamp
              user: data.User._ref
              name: data.User._refObjectName
              vote: data.Message
        if index == @store.data.length - 1
          `var whenVoted = [], voteMap = {}`
          data.whoVoted = []
          for k, V of @tpl.whoVoted
            @tpl.accountVoted = V if k == @accountRef
            if @tpl.whoVoted.hasOwnProperty k
              whenVoted.push V.when
              voteMap[V.when] = V
          whenVoted.sort()
          for k in whenVoted
            D = new Date voteMap[k].when
            voteMap[k].when = Ext.util.Format.date(D, 'g:iA') + ' on ' + Ext.util.Format.date(D, 'm-d-Y')
            data.whoVoted.push voteMap[k]
          # console.log whenVoted
          # console.log @tpl.whenVoted
        # console.log 'prepareData. accountVoted = ' + @tpl.accountVoted
        data
      listeners:
        scope: @
        refresh: (view) ->
          StoryEstimator = Ext.create 'EstimateSelector',
            ParentApp: @
            accountId: Rally.environment.getContext().getUser().ObjectID
            renderTo: Ext.query('.estimateselector')[0]
          # console.log 'refresh. accountVoted = ' + view.tpl.accountVoted
          StoryEstimator.update view.tpl.accountVoted
          # reset template variables for subsequent displays
          view.tpl.accountVoted = false
          view.tpl.shownMessages = false
          view.tpl.shownDiscussion = false
          view.tpl.whoVoted = {}
          return
    }
    @down('#storyview').add @DiscussionThread

    return
}

Ext.define 'EstimateSelector', {
  extend: 'Ext.Container'
  # cls: 'estimateselector'
  # constructor uses config to populate items.
  # items: []
  config:
    accountId: 0
    cipher: 0
    # @cfg {Array} (required)
    # a list of values that can be used as story estimates
    deck: [
      { value: `00`, label: '?' }
      { value: `01`, label: '0' }
      { value: `02`, label: '&#189;' } # "½"
      { value: `03`, label: '1' }
      { value: `04`, label: '2' }
      { value: `05`, label: '3' }
      { value: `06`, label: '5' }
      { value: `07`, label: '8' }
      { value: `010`, label: '13' }
      { value: `011`, label: '20' }
      { value: `012`, label: '40' }
      { value: `013`, label: '100' }
      # { value: `014`, label: '' }
      # { value: `015`, label: '' }
      # { value: `016`, label: '' }
      # { value: `017`, label: '' }
    ]

  constructor: (config) ->
    @mergeConfig config
    @config.cipher = config.accountId % 10 if config.accountId?
    @callParent [config]
    return

  # update gets called before the template is processed.
  update: (data) ->
    if data.vote
      # console.log 'update. vote = ' + data.vote
      # values in 'data' passed by reference and later used by template.
      data.vote = @_decipher(data.vote)
      @callParent [data]

      # add control to delete previous vote
      Ext.create 'Ext.Component',
          data: data
          tpl: new Ext.XTemplate(
            '<tpl for=".">',
                '<span data-id="{post}">select a new estimate</span>',
            '</tpl>'
          )
          listeners:
            click:
              element: 'el'
              scope: @
              fn: @_onReselect
          renderTo: @.getEl()
    else
      # console.log 'update. no vote'
      @callParent [data]
      # initialize cards.
      # @todo any way to create these on initComponent and show/hide instead?
      for C in @config.deck
        Ext.create 'Ext.Component',
          id: 'pokercard-' + C.value
          cls: 'pokercard'
          html: C.label
          config: C
          listeners:
            click:
              element: 'el'
              scope: @
              fn: @_onCardClick
          renderTo: @.getEl()
    return

  tpl: new Ext.XTemplate(
    '<tpl for=".">',
      '<tpl if="vote">',
        '<h3>Your estimate: {vote}</h3>',
      '<tpl else>',
        '<h3>Select an estimate</h3>',
      '</tpl>', 
    '</tpl>',
  )

  # listeners:
  #   beforerender: () ->
  #     # debugger
  #     console.log("beforerender. cipher = " + @config.cipher)
  #     return

  # simple caesar cipher to obfuscate card values using last digit of user id.
  _encipher: (v) -> (v + @config.cipher) % @config.deck.length
  _decipher: (v) -> @config.deck[if (v = (v - @config.cipher) % @config.deck.length) < 0 then @config.deck.length + v else v].label

  # helper function bound to card's click event.
  _onCardClick: (e, t) ->
    selectedValue = @_encipher Ext.getCmp(t.id).config.value
    Message = [new Date().getTime(), @config.accountId, selectedValue]
    pokerMessage = @ParentApp.PokerMessage.compile Message, @ParentApp.Base62.encode
    Record = Ext.create @ParentApp.models['conversationpost']
    Record.set
      Artifact: @ParentApp.CurrentStory.data.keys[0]
      User: @config.accountId
      Text: 'Pointed this story with RallyPoker. <span style="display:none">' + encodeURIComponent(pokerMessage) + '<\/span>'
    Record.save
      success: (b, o) =>
        @ParentApp.DiscussionsStore.reload()
        return
      failure: (b, o) ->
        alert 'Error submitting your estimate. Please try again.'
        return
    return

  # helper functions bound to the "reselect" link.
  _onReselect: (e, t) ->
    EstimateStore = Ext.create 'Rally.data.WsapiDataStore',
      model: 'conversationpost'
      autoLoad: true
      filters: [{
        property: 'ObjectID'
        value: t.getAttribute 'data-id'
      }]
      limit: 1
      listeners:
        scope: @
        load: @_onEstimateStoreLoad
    return
  _onEstimateStoreLoad: (store, result, success) ->
    if success
      store.data.items[0].destroy
        success: () =>
          @ParentApp.DiscussionsStore.reload()
          return
        failure: () ->
          alert 'Error deleting your estimate. Please try again.'
          return
    return
}
