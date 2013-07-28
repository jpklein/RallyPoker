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

  Base62: do ->
    # Adapted from Javascript Base62 encode/decoder
    # Copyright (c) 2013 Andrew Nesbitt
    # See LICENSE at https://github.com/andrew/base62.js

    # Library that obfuscates numeric strings as case-sensitive,
    # alphanumeric strings
    chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
    return {
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

  # Given an enciphered message and the Account that created it, the Deck returns
  # the label (ie. point value) of the selected Card.
  # @todo allow non-team members to select to use different decks? include a hash
  # for each deck as part of the message to detect when a different deck was used
# Ext.define 'PokerDeck',
#   extend: 'Ext.Component'
  PokerDeck: do ->
    cards = ['?', '0', '&#189;', '1', '2', '3', '5', '8', '13', '20', '40', '100']
    # simple caesar cipher to obfuscate card values using last digit of user id.
    _encipher = (key, shift) -> (key + shift) % cards.length
    _decipher = (msg, shift) -> if (msg = (msg - shift) % cards.length) < 0 then cards.length + msg else msg
    return {
      listCards: -> { key: position, value: label } for label, position in cards
      pickCard: (key, uid) -> _encipher(key, uid % 10)
      revealCard: (msg, uid) -> cards[_decipher(msg, uid % 10)]
    }

  PokerMessage: do ->
    # helper fn to escape RegEx-reserved strings
    esc = (str) -> str.replace /[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"
    # [strings] ==> encoded message + custom delimiters
    sep = ['/', '&']
    msg = new RegExp "^" + sep[0] + "\\w+(?:" + sep[1] + "\\w+)+$"
    env = ['[[', ']]']
    pkg = new RegExp esc(env[0]) + "(" + sep[0] + ".+?)" + esc(env[1])
    return {
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
    @Account.ref = '/user/' + @Account.ObjectID
    @Account.isTeamMember = false
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
          for M in result[0].data.TeamMembers
            if M._ref == @Account.ref
              @Account.isTeamMember = true
              return
          # @getEl().unmask()
          return

    @IterationsStore = Ext.create 'Rally.data.WsapiDataStore', {
      # id: 'iterationsStore'
      model: 'Iteration'
      fetch: ['Name']
      sorters: [{ property: 'Name', direction: 'DESC' }]
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
            filters: [{ property: 'Iteration.Name', value: newValue }]
          }
          return
    }
    @down('#iterationfilter').add @IterationFilter

    @StoriesStore = Ext.create 'Rally.data.WsapiDataStore', {
      model: 'User Story'
      fetch: ['ObjectID', 'FormattedID', 'Name']
      sorters: [{ property: 'Name', direction: 'DESC' }]
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
              filters: [{ property: 'ObjectID', value: storyListItemId }]
            }
            # always load the store so that its view is reprocessed.
            @DiscussionsStore.load {
              filters: [{ property: 'Artifact.ObjectID', value: storyListItemId }]
            }
            @getLayout().setActiveItem 'storyview'
            return
    }
    @down('#storypicker').add @StoryList

    Ext.getCmp('storyback').on 'click', =>
      @getLayout().setActiveItem 'storypicker'
      @StoryPage.update {}
      @DiscussionThread.update {}
      @DiscussionThread.tpl.showEstimates = false
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

    # parse poker messages from discussion items.
    @DiscussionsStore = Ext.create 'Rally.data.WsapiDataStore', {
      model: 'conversationpost'
      fetch: ['User', 'CreationDate', 'Text', 'Message']
    }
    @DiscussionThread = Ext.create 'Ext.view.View', {
      store: @DiscussionsStore
      tpl: new Ext.XTemplate(
        '<tpl if="xindex == xcount"><tpl for=".">',
          '<tpl if="this.messageThread.length">',
            '<div class="messagethread">',
              '<h3>Who\'s Voted</h3>',
              '<ul class="messageitems">',
            '<tpl if="this.isTeamMember">',
              '<tpl for="whoVoted">',
                '<li>',
                  '<span class="pokercard pokercard-facedown"></span>',
                  '{name} at {when}',
                '</li>',
              '</tpl>'
              '</ul>',
            '<tpl else>',
              '<tpl if="this.showEstimates">',
                '<tpl for="whoVoted">',
                '<li>',
                  '<span class="pokercard pokercard-faceup">{[this.revealCard(values.vote, values.user)]}</span>',
                  ' by {name} at {when}',
                '</li>',
                '</tpl>'
              '<tpl else>',
                '<tpl for="whoVoted">',
                '<li>',
                  '<span class="pokercard pokercard-facedown"></span>',
                  '{name} at {when}',
                '</li>',
                '</tpl>',
              '</tpl>',
              '</ul>',
              '<span class="messagethread-reveal">Reveal</span>',
              '<span class="messagethread-reload">Reload</span>',
            '</tpl>',
            '</div>',
          '</tpl>',
            '<div class="estimateselector"></div>'
          '<tpl if="this.discussionThread.length">',
            '<div class="discussionthread">',
              '<h3>Discussion</h3>',
            '<tpl for="discussionThread">',
              '<div class="discussionitem">',
                '<small class="discussionitem-id">{name}: {when}</small>',
                '<p class="discussionitem-text">{text}</p>',
              '</div>',
            '</tpl>',
            '</div>',
          '</tpl>',
        '</tpl></tpl>',
        {
          isTeamMember: _this.Account.isTeamMember
          showEstimates: false
          revealCard: _this.PokerDeck.revealCard
          myVote: false
          whoVoted: {}
          messageThread: []
          discussionThread: []
        }
      )
      itemSelector: 'div.discussionitem'
      prepareData: (data, index, record) ->
        `var timestamp = data.CreationDate.getTime()`
        if message = _this.PokerMessage.extract data.Text
          if not @tpl.whoVoted[data.User._ref]? or timestamp > @tpl.whoVoted[data.User._ref].when
            @tpl.whoVoted[data.User._ref] =
              post: data.ObjectID
              when: timestamp
              user: data.User._ref
              name: data.User._refObjectName
              vote: (_this.PokerMessage.parse message, _this.Base62.decode).pop()
        else
          @tpl.discussionThread.push
            when: timestamp
            name: data.User._refObjectName
            text: data.Text

        if index == @store.data.length - 1
          `var whenVoted = [], voteMap = {}`
          data.whoVoted = []
          for k, V of @tpl.whoVoted
            if k is _this.Account.ref then @tpl.myVote = V
            if @tpl.whoVoted.hasOwnProperty k
              @tpl.messageThread.push V.when
              voteMap[V.when] = V
          @tpl.messageThread.sort()
          for k in @tpl.messageThread
            D = new Date voteMap[k].when
            voteMap[k].when = Ext.util.Format.date(D, 'g:iA') + ' on ' + Ext.util.Format.date(D, 'm-d-Y')
            A = /user\/(\d+)/.exec voteMap[k].user
            voteMap[k].user = A[1]
            data.whoVoted.push voteMap[k]
          data.discussionThread = @tpl.discussionThread
        return data
      listeners:
        scope: @
        refresh: (view) ->
          if @Account.isTeamMember
            # @todo any way to create this widget once and just hide/update/show?
            StoryEstimator = Ext.create 'EstimateSelector',
              ParentApp: @
              renderTo: Ext.query('.estimateselector')[0]
            StoryEstimator.update view.tpl.myVote
          else
            Ext.get(view.el.query('.messagethread-reveal')).on('click', view._onReveal, @)
            Ext.get(view.el.query('.messagethread-reload')).on('click', view._onReload, @)
          # reset template variables for subsequent displays
          view.tpl.myVote = false
          view.tpl.whoVoted = {}
          view.tpl.messageThread = []
          view.tpl.discussionThread = []
          return
      _onReveal: (e, t) ->
        # for C in Ext.get(t).prev('.messageitems').query('li .pokercard')
        #   Ext.get(C).setHTML @PokerDeck.revealCard(C.getAttribute('data-vote'), C.getAttribute('data-userid')) + ' by '
        @DiscussionThread.tpl.showEstimates = true
        @DiscussionsStore.reload()
        return
      _onReload: (e, t) ->
        @DiscussionsStore.reload()
        return
    }
    @down('#storyview').add @DiscussionThread

    return
}

Ext.define 'EstimateSelector', {
  extend: 'Ext.Container'

  # template is processed during call to parent function using values in 'data'.
  update: (data) ->
    if data.vote
      data.vote = @ParentApp.PokerDeck.revealCard(data.vote, data.user)
      @callParent [data]

      # add control to delete previous vote.
      Ext.get(@el.query('.storypointer-reselect')).on('click', @_onReselect, @)
    else
      data = { deck: @ParentApp.PokerDeck.listCards() }
      @callParent [data]

      # initialize cards.
      # @todo any way to add these once on initComponent and show/hide instead?
      Ext.get(li).on('click', @_onCardClick, @) for li in @el.query('.pokercard')
    return

  tpl: new Ext.XTemplate(
    '<tpl for=".">',
      '<tpl if="vote">',
        '<h3>Your estimate: {vote}</h3>',
        '<span class="storypointer-reselect" data-postid="{post}">Select a new estimate</span>',
      '<tpl else>',
        '<h3>Select an estimate</h3>',
        # '<tpl if="xindex == xcount">',
        '<ul class="storypointer">',
        '<tpl for="deck">',
          '<li class="pokercard pokercard-faceup" data-cardid="{key}">',
            '<span>{value}</span>',
          '</li>',
        '</tpl>'
        '</ul>',
        # '</tpl>',
      '</tpl>', 
    '</tpl>',
  )

  # helper function bound to card's click event.
  _onCardClick: (e, t) ->
    key = Number Ext.get(t).findParent('.pokercard').getAttribute('data-cardid')
    Message = [
      new Date().getTime(),
      @ParentApp.Account.ObjectID,
      @ParentApp.PokerDeck.pickCard(key, @ParentApp.Account.ObjectID)
    ]
    message = @ParentApp.PokerMessage.compile Message, @ParentApp.Base62.encode
    Record = Ext.create @ParentApp.models['conversationpost']
    Record.set
      Artifact: @ParentApp.CurrentStory.data.keys[0]
      User: @ParentApp.Account.ObjectID
      Text: 'Pointed this story with RallyPoker. <span style="display:none">' + encodeURIComponent(message) + '<\/span>'
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
    Ext.create 'Rally.data.WsapiDataStore',
      model: 'conversationpost'
      autoLoad: true
      filters: [{ property: 'ObjectID', value: t.getAttribute('data-postid') }]
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
