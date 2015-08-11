var log = console.log.bind(console);

var ReverseStreamComponent = React.createClass({
    getInitialState: function () {
        var cursor = this.props.client.openCursor(this.props.query);
        var pager = new LivefyreTimeline.models.simple.SimplePager(cursor, {autoLoad:true, size:50});
        pager.on('readable', this.onReadable.bind(this));
        pager.on('error', function (event) {
            // log('error', event);
        });
        pager.on('initialized', function (event) {
            // log("initialized");
        });

        pager.on('end', function () {
            // log("pager issued end");
            this.setState({done: true, estimated: false});
        }.bind(this));

        return {
            cursor: cursor,
            pager: pager,
            items: [],
            count: undefined,
            estimated: true,
            done: false,
            seen: {}
        };
    },

    onReadable: function (event) {
        // console.log("readable:", event);
        var pager = this.state.pager;
        var data = pager.read({loadOnFault: false});
        var new_items = this.state.items;
        var seen = this.state.seen;
        if (Array.isArray(data)) {
            // log("read:", data.length);
            data.map(function (item) {
                // console.log("" + item.tuuid + ": " + item.verb + ", " + item.published);
                if (seen[item.tuuid]) {
                    // console.log("duplicate!");
                    return;
                }
                seen[item.tuuid] = true;
                new_items.push(item);
            });
        } else {
            // log("unexpected; data is:", data);
        }
        if (pager.done()) {
            // log("we're at the end of the stream", pager.done(), pager.cursor.hasNext());
        }

        this.setState({
            items: new_items,
            estimated: !pager.done(),
            count: new_items.length,
            done: pager.done()
        });
    },

    loadMore: function () {
        this.state.pager.loadNextPage();
    },

    renderItem: function (item) {
        return (<this.props.itemComponent item={item} key={item.tuuid} />);    
    },

    bunchLikes: function (items) {
        //Bunch likes using JS :)
        return items;
    },

    render: function () {
        var ReactCSSTransitionGroup = React.addons.CSSTransitionGroup;
        var more = this.state.estimated ? (<button onClick={this.loadMore}>Load more</button>) : "";
        var plus = this.state.estimated ? '+' : '';
        var bunchedItems = this.bunchLikes(this.state.items);
        return (
            <div>
                <h2>Item Count: {this.state.count}{plus}</h2>
                <ReactCSSTransitionGroup transitionName="newActivity">
                    {bunchedItems.map(function (item) {
                        return this.renderItem(item);
                    }.bind(this))}
                </ReactCSSTransitionGroup>
                {more}<br />
                {close}
            </div>
        );
    }
});

var AlertActivityItem = React.createClass({
    render: function () {
        var i = this.props.item;
        var who = i.actor.handle || i.actor.displayName;
        var verb = i.verb == 'post' ? 'replied' : i.verb;
        var where = i.target;
        var what = i.object.content;
        console.log(where);
        var original = i.verb == 'like' ? i.object.content : i.object.inReplyTo.content;
        var when = new Date(i.published);

        console.log(when); 
        return (
            <div>
                <hr />
                <span>Your post in <a href={where.url}>{where.title}</a></span>:
                <div dangerouslySetInnerHTML={{__html: original}}></div>
                <div dangerouslySetInnerHTML={{__html: what}}></div>
                <span>{who} {verb} @ <i>{when.toString()}</i></span>
            </div>
        );
    }
});

var UserStream = React.createClass({
    
    getInitialState: function() {
        var user = this.props.user;
        var Precondition = LivefyreTimeline.Precondition;
        var RecentQuery = LivefyreTimeline.backends.chronos.cursors.RecentQuery;
        var ConnectionFactory = LivefyreTimeline.backends.factory('qa', {
            token: user.token
        });
        var realChronos = ConnectionFactory.chronos();
        var realQuery = RecentQuery("urn:livefyre:studio-qa-1.fyre.co:user=" + user.id.split("@")[0] + ":alertStream", 50);

        return {
            user: user,
            precondition: Precondition,
            chronos: realChronos,
            query: realQuery
        }
    },

    buildLink: function() {
        if ($('.fyre-activity-stream').length) {
            return;
        }
        var streamName = this.state.user.displayName + "'s Steam";
        var showLink = $("<div class='fyre-activity-stream'><a title='User Stream'>" + streamName + "</a></div>");
        showLink.click( function() {
                $('#activityStreamWrapper').show();
                return false;
            }
        );
        $('.fyre-login-bar').append(showLink);
    },

    closeModal: function() {
        $('#activityStreamWrapper').hide();
    },

    render: function() {
        this.buildLink();
        var streamName = this.state.user.displayName + "'s Steam";
        var close = <button onClick={this.closeModal}>Close</button>;
        return (
            <div id="activityStream">
                <div dangerouslySetInnerHTML={{__html: streamName}}></div>
                <ReverseStreamComponent itemComponent={AlertActivityItem} client={this.state.chronos} query={this.state.query} />
                {close}
            </div>
        );
    }
});

//Simple comments implementation
Livefyre.require(['fyre.conv#3', 'auth'], function(Conv, Auth) {
    new Conv({
        network: 'studio-qa-1.fyre.co',
        env: 'qa'
    }, 
    [{
        app: 'main',
        siteId: '290656',
        articleId: 'mikerulez',
        el: 'livefyre-app-custom-1438630270943',
    
    }],
    function (widget) {
        widget.on('initialRenderComplete', function() {
            if(localStorage.getItem('fyre-auth')) {
                var user = $.parseJSON(localStorage.getItem('fyre-auth')).value.profile;
                // buildMockStream();
                buildRealStream(user);
            }

        });
        widget.on('userLoggedIn', function() {
            if(localStorage.getItem('fyre-auth')) {
                var user = $.parseJSON(localStorage.getItem('fyre-auth')).value.profile;
                // buildMockStream();
                buildRealStream(user);
            }

        });
    });
    Auth.delegate({
        login: function(cb) {
            var lftoken = prompt('lftoken?');
            cb(null, { livefyre: lftoken });
        },
        logout: function(cb) {
            cb(null);
            killUserStream();
        }
    });
});

//Mock data. Not as react-orientented as real stream
function buildMockStream() {
    var MockChronosConnection = LivefyreTimeline.backends.chronos.connection.MockConnection;
    var Precondition = LivefyreTimeline.Precondition;
    var RecentQuery = LivefyreTimeline.backends.chronos.cursors.RecentQuery;

    var mockChronos = new MockChronosConnection([
        "https://rawgit.com/ninowalker/eeceb1d03fc44de918f2/raw/like.json",
        "https://rawgit.com/ninowalker/eeceb1d03fc44de918f2/raw/sample2.json"
    ]);
    var mockQuery = RecentQuery("urn:meow", 5);

    var showLink = $("<div class='fyre-activity-stream'><a title='Activity Stream'>Activity Stream</a></div>");
    showLink.click( function() {
            $('#activityStream').show();
            return false;
        }
    );
    $('.fyre-login-bar').append(showLink);
    React.render(
    (
        <div>
            <h3>Using a mocked datasource</h3>
            <ReverseStreamComponent itemComponent={AlertActivityItem} client={mockChronos} query={mockQuery} />
        </div>
     ), document.getElementById('activityStream'));
}

function buildRealStream(user) {
    React.render(
    (
        <UserStream user={user} />
    ), document.getElementById('activityStreamWrapper'));
}

function killUserStream() {
    $('.fyre-activity-stream').remove();
    return;
}
