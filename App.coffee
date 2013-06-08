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
    # [strings] ==> encoded message + custom delimiters
    sep = ['/', '&']
    msg = new RegExp("^" + sep[0] + "\\w+(?:" + sep[1] + "\\w+)+$")
    env = ['[[', ']]']
    pkg = new RegExp("\\[\\[(" + sep[0] + ".+)\\]\\]")

    {
      compile: (M) ->
        fn = arguments[1] || (x) -> x
        a = Ext.clone M
        a[0] = sep[0] + fn M[0]
        s = if a.length == 1 then a[0] else a.reduce (p, c, i) -> p + sep[1] + fn c
        env[0] + s + env[1]
      extract: (s) ->
        if not s or not (a = s.match pkg) then false else a.pop()
      parse: (s) ->
        return false if not msg.test s
        M = s.slice(1).split sep[1]
        if not arguments[1]? then M else arguments[1] i for i in M by 1
    }

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

    Ext.getCmp('storyback').on 'click', () =>
      @getLayout().setActiveItem 'storypicker'
      return

    @CurrentStory = Ext.create 'Rally.data.WsapiDataStore', {
      model: 'userstory'
      limit: 1,
      fetch: ['ObjectID', 'LastUpdateDate', 'Description', 'Attachments', 'Notes', 'Discussion']
      listeners:
        load: (store, result, success) =>
          if result[0].data.Discussion.length
            @DiscussionsStore.load {
              filters: [{
                # You gotta love it when a random guess comes together!
                property: 'Artifact.ObjectID'
                value: result[0].data.ObjectID
              }]
            }
          return
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

    # Damn it feels good to be a gangster.
    @cnt = 0
    @DiscussionMessageField = new Ext.data.Field {
      name: 'Message'
      # type: 'object'
      type: 'string'
      convert: (v, rec) =>
        # debugger
        @cnt++
        if @cnt == 2
          # Example message contents: UserID + 4-bit point-selection value
          message = [new Date().getTime(), @getContext().getUser().ObjectID, `020`]
          text = rec.get('Text') + "<br/><p>" + @PokerMessage.compile(message, @Base62.encode) + "</p>"

        # if message = @PokerMessage.extract text
        #   {
        #     exists: true
        #     body: (@PokerMessage.parse message, @Base62.decode).pop()
        #   }
        # else
        #   {
        #     exists: false
        #   }
        if message = @PokerMessage.extract text
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
      # listeners:
      #   load: (store, result, success) =>
      #     console.log store.model.prototype.fields.items
      #     console.log result[0].data
      #     debugger
      #     @MessageAddNew.render Ext.get('messageaddnew')
      #     return
    }
    @DiscussionThread = Ext.create 'Ext.view.View', {
      store: @DiscussionsStore
      tpl: new Ext.XTemplate(
        '<tpl for=".">',
          '<tpl if="Message !== false">',
            '<tpl if="!this.shownMessages">',
            '{% this.shownMessages = true %}',
              '<div class="messagethread">',
                '<h3>Who\'s Voted</h3>',
                '<ul class="messageitems">',
            '</tpl>',
                  '<li>{User._refObjectName}</li>',
          '</tpl>',
          '<tpl if="xindex == xcount && this.shownMessages">',
                '</ul>',
              '</div>',
          '</tpl>',
        '</tpl>',
              '<div id="messageaddnew"><h3>Cast your vote</h3></div>',
        '<tpl for=".">',
          '<tpl if="Message === false">',
            '<tpl if="!this.shownDiscussion">',
            '{% this.shownDiscussion = true %}',
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
          shownMessages: false
          shownDiscussion: false
        }
      )
      listeners:
        refresh: () ->
        # afterRender: () ->
          # debugger
          # @DiscussionThread.down('#messageaddnew').add @Estimator
          # Addnew = Ext.query('#messageaddnew')
          Ext.create 'RallyPokerApp.EstimateSelector', {renderTo: Ext.query('#messageaddnew')[0]}
          return
      itemSelector: 'div.discussionitem'
    }
    @down('#storyview').add @DiscussionThread

    return
}

Ext.define 'RallyPokerApp.EstimateSelector', {
  extend: 'Ext.Container'
  cls: 'estimateselector'
  # constructor uses config to populate items.
  items: []
  config:
    # @cfg {Array} (required)
    # a list of values that can be used as story estimates
    deck: [
      { value: `00`, label: '?' }
      { value: `01`, label: '0' }
      { value: `02`, label: '&#189;' } # "½"?
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

    # helper function bound to card's click event.
    _onCardClick = (e, t) =>
      _this = Ext.getCmp 'RallyPokerApp'
      userId = @getContext().getUser().ObjectID
      message = [new Date().getTime(), userId, Ext.getCmp(t.id).config.value]
      compiled = @PokerMessage.compile message, @Base62.encode
      record = Ext.create @models['conversationpost']
      record.set {
        Artifact: @CurrentStory.data.keys[0]
        User: userId
        Text: 'Pointed this story with RallyPoker.<span style="display:none">' + encodeURIComponent(compiled) + '<\/span>'
      }
      # debugger;
      record.save {
        # success: (b, o) ->
        #   return
        failure: (b, o) ->
          debugger;
          alert 'it borked :('
          return
      }
      return
    # initialize cards.
    for c in @config.deck
      @items.push
        xtype: 'component'
        id: 'pokercard-' + c.value
        cls: 'pokercard'
        html: c.label
        config: c
        listeners:
          click:
            element: 'el'
            fn: _onCardClick

    @callParent [@config]
    return
}
