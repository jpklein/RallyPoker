// Generated by CoffeeScript 1.6.2
Ext.define('RallyPokerApp', {
  extend: 'Rally.app.App',
  componentCls: 'app',
  layout: 'card',
  items: [
    {
      id: 'storypicker',
      layout: {
        reserveScrollbar: true
      },
      autoScroll: true,
      dockedItems: [
        {
          items: [
            {
              id: 'iterationfilter',
              xtype: 'toolbar'
            }
          ]
        }
      ]
    }, {
      id: 'storyview',
      layout: {
        reserveScrollbar: true
      },
      autoScroll: true,
      dockedItems: [
        {
          items: [
            {
              id: 'storyheader',
              xtype: 'toolbar',
              items: [
                {
                  id: 'storyback',
                  xtype: 'button',
                  html: 'Back'
                }, {
                  id: 'storytitle',
                  xtype: 'component'
                }
              ]
            }
          ]
        }
      ]
    }
  ],
  Base62: (function() {
    var chars;

    chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"];
    return {
      encode: function(i) {
        var s;

        if (i === 0) {
          return;
        }
        s = '';
        while (i > 0) {
          s = chars[i % 62] + s;
          i = Math.floor(i / 62);
        }
        return s;
      },
      decode: function(a, b, c, d) {
        for (
          b = c = (a === (/\W|_|^$/.test(a += "") || a)) - 1;
          d = a.charCodeAt(c++);
        ) {
          b = b * 62 + d - [, 48, 29, 87][d >> 5];
        }
        return b;
      }
    };
  })(),
  PokerMessage: (function() {
    var env, msg, pkg, sep;

    sep = ['/', '&'];
    msg = new RegExp("^" + sep[0] + "\\w+(?:" + sep[1] + "\\w+)+$");
    env = ['[[', ']]'];
    pkg = new RegExp("\\[\\[(" + sep[0] + ".+)\\]\\]");
    return {
      compile: function(M) {
        var fn, s;

        fn = arguments[1] || function(x) {
          return x;
        };
        M[0] = sep[0] + fn(M[0]);
        s = M.length === 1 ? M[0] : M.reduce(function(p, c, i) {
          return p + sep[1] + fn(c);
        });
        return env[0] + s + env[1];
      },
      extract: function(s) {
        var a;

        if (!s || !(a = s.match(pkg))) {
          return false;
        } else {
          return a.pop();
        }
      },
      parse: function(s) {
        var M, i, _i, _len, _results;

        if (!msg.test(s)) {
          return false;
        }
        M = s.slice(1).split(sep[1]);
        if (arguments[1] == null) {
          return M;
        } else {
          _results = [];
          for (_i = 0, _len = M.length; _i < _len; _i += 1) {
            i = M[_i];
            _results.push(arguments[1](i));
          }
          return _results;
        }
      }
    };
  })(),
  launch: function() {
    var _this = this;

    this.IterationsStore = Ext.create('Rally.data.WsapiDataStore', {
      model: 'Iteration',
      fetch: ['Name'],
      sorters: [
        {
          property: 'Name',
          direction: 'DESC'
        }
      ],
      autoLoad: true,
      listeners: {
        load: function(store, result, success) {
          if (success) {
            _this.IterationFilter.setValue('Deprecated');
          }
        }
      }
    });
    this.IterationFilter = Ext.create('Ext.form.ComboBox', {
      fieldLabel: 'Iteration',
      store: this.IterationsStore,
      queryMode: 'local',
      displayField: 'Name',
      valueField: 'Name',
      listeners: {
        change: function(field, newValue, oldValue, options) {
          _this.StoriesStore.load({
            filters: [
              {
                property: 'Iteration.Name',
                value: newValue
              }
            ]
          });
        }
      }
    });
    this.down('#iterationfilter').add(this.IterationFilter);
    this.StoriesStore = Ext.create('Rally.data.WsapiDataStore', {
      model: 'User Story',
      fetch: ['ObjectID', 'FormattedID', 'Name'],
      sorters: [
        {
          property: 'Name',
          direction: 'DESC'
        }
      ]
    });
    this.StoryList = Ext.create('Ext.view.View', {
      store: this.StoriesStore,
      tpl: new Ext.XTemplate('<tpl for=".">', '<div style="padding: .5em 0;" class="storylistitem" data-id="{ObjectID}">', '<span class="storylistitem-id">{FormattedID}: {Name}</span>', '</div>', '</tpl>'),
      itemSelector: 'div.storylistitem',
      emptyText: 'No stories available',
      listeners: {
        click: {
          element: 'el',
          fn: function(e, t) {
            var StoryListItem, storyListItemName;

            StoryListItem = Ext.get(t).findParent('.storylistitem');
            storyListItemName = Ext.get(StoryListItem).child('.storylistitem-id').getHTML();
            Ext.get('storytitle').update(storyListItemName);
            _this.CurrentStory.load({
              filters: [
                {
                  property: 'ObjectID',
                  value: Ext.get(t).findParent('.storylistitem').getAttribute('data-id')
                }
              ]
            });
            _this.getLayout().setActiveItem('storyview');
          }
        }
      }
    });
    this.down('#storypicker').add(this.StoryList);
    Ext.getCmp('storyback').on('click', function() {
      _this.getLayout().setActiveItem('storypicker');
    });
    this.CurrentStory = Ext.create('Rally.data.WsapiDataStore', {
      model: 'userstory',
      limit: 1,
      fetch: ['ObjectID', 'LastUpdateDate', 'Description', 'Attachments', 'Notes', 'Discussion'],
      listeners: {
        load: function(store, result, success) {
          if (result[0].data.Discussion.length) {
            _this.DiscussionsStore.load({
              filters: [
                {
                  property: 'Artifact.ObjectID',
                  value: result[0].data.ObjectID
                }
              ]
            });
          }
        }
      }
    });
    this.StoryPage = Ext.create('Ext.view.View', {
      store: this.CurrentStory,
      tpl: new Ext.XTemplate('<tpl for=".">', '<div class="storydetail" data-id="{ObjectID}">', '<small class="storydetail-date">Last Updated: {[this.prettyDate(values.LastUpdateDate)]}</small>', '<div class="storydetail-description">', '{Description}', '</div>', '<div class="storydetail-attachments">', '<h3>Attachments<h3>{Attachments}', '</div>', '<div class="storydetail-notes">', '<h3>Notes<h3>{Notes}', '</div>', '</div>', '</tpl>', {
        prettyDate: function(date) {
          var day_diff, diff;

          diff = ((new Date()).getTime() - date.getTime()) / 1000;
          day_diff = Math.floor(diff / 86400);
          if (isNaN(day_diff) || day_diff < 0 || day_diff >= 31) {
            return;
          }
          return day_diff === 0 && (diff < 60 && "just now" || diff < 120 && "1 minute ago" || diff < 3600 && Math.floor(diff / 60) + " minutes ago" || diff < 7200 && "1 hour ago" || diff < 86400 && Math.floor(diff / 3600) + " hours ago") || day_diff === 1 && "Yesterday" || day_diff < 7 && day_diff + " days ago" || day_diff < 31 && Math.ceil(day_diff / 7) + " weeks ago";
        }
      }),
      itemSelector: 'div.storydetail'
    });
    this.down('#storyview').add(this.StoryPage);
    this.cnt = 0;
    this.DiscussionMessageField = new Ext.data.Field({
      name: 'Message',
      type: 'string',
      convert: function(v, rec) {
        var message, text;

        _this.cnt++;
        if (_this.cnt === 2) {
          message = [new Date().getTime(), _this.getContext().getUser().ObjectID, 020];
          text = rec.get('Text') + "<br/><p>" + _this.PokerMessage.compile(message, _this.Base62.encode) + "</p>";
        }
        if (message = _this.PokerMessage.extract(text)) {
          return (_this.PokerMessage.parse(message, _this.Base62.decode)).pop();
        } else {
          return false;
        }
      }
    });
    Rally.data.ModelFactory.getModel({
      type: 'conversationpost',
      success: function(Model) {
        Model.prototype.fields.items.push(_this.DiscussionMessageField);
        Model.setFields(Model.prototype.fields.items);
      }
    });
    this.DiscussionsStore = Ext.create('Rally.data.WsapiDataStore', {
      model: 'conversationpost',
      fetch: ['User', 'CreationDate', 'Text', 'Message'],
      listeners: {
        load: function(store, result, success) {
          _this.MessageAddNew.render(Ext.get('messageaddnew'));
        }
      }
    });
    this.DiscussionThread = Ext.create('Ext.view.View', {
      store: this.DiscussionsStore,
      tpl: new Ext.XTemplate('<tpl for=".">', '<tpl if="Message !== false">', '<tpl if="!this.shownMessages">', '{% this.shownMessages = true %}', '<div class="messagethread">', '<h3>Who\'s Voted</h3>', '<ul class="messageitems">', '</tpl>', '<li>{User._refObjectName}</li>', '</tpl>', '<tpl if="xindex == xcount && this.shownMessages">', '</ul>', '</div>', '</tpl>', '</tpl>', '<div id="messageaddnew"><h3>Cast your vote</h3></div>', '<tpl for=".">', '<tpl if="Message === false">', '<tpl if="!this.shownDiscussion">', '{% this.shownDiscussion = true %}', '<div class="discussionthread">', '<h3>Discussion</h3>', '</tpl>', '<div class="discussionitem">', '<small class="discussionitem-id">{User._refObjectName}: {CreationDate}</small>', '<p class="discussionitem-text">{Text}</p>', '</div>', '</tpl>', '<tpl if="xindex == xcount && this.shownDiscussion">', '</div>', '</tpl>', '</tpl>', {
        shownMessages: false,
        shownDiscussion: false
      }),
      itemSelector: 'div.discussionitem'
    });
    this.down('#storyview').add(this.DiscussionThread);
    this.Estimator = Ext.create('RallyPokerApp.EstimateSelector', {});
  }
});

Ext.define('RallyPokerApp.EstimateSelector', {
  extend: 'Ext.Container',
  cls: 'estimateselector',
  config: {
    deck: [
      {
        value: 00,
        label: '?'
      }, {
        value: 01,
        label: '0'
      }, {
        value: 02,
        label: '&#189;'
      }, {
        value: 03,
        label: '1'
      }, {
        value: 04,
        label: '2'
      }, {
        value: 05,
        label: '3'
      }, {
        value: 06,
        label: '5'
      }, {
        value: 07,
        label: '8'
      }, {
        value: 010,
        label: '13'
      }, {
        value: 011,
        label: '20'
      }, {
        value: 012,
        label: '40'
      }, {
        value: 013,
        label: '100'
      }
    ]
  },
  constructor: function(config) {
    debugger;    this.mergeConfig(config);
    return this.callParent([this.config]);
  }
});
