var MockChronosConnection = LivefyreTimeline.backends.chronos.connection.MockConnection;
var Precondition = LivefyreTimeline.Precondition;
var RecentQuery = LivefyreTimeline.backends.chronos.cursors.RecentQuery;
var SimplePager = LivefyreTimeline.models.simple.SimplePager;
var ReactCSSTransitionGroup = React.addons.CSSTransitionGroup;

var mockChronos = new MockChronosConnection([
    "https://rawgit.com/ninowalker/eeceb1d03fc44de918f2/raw/like.json",
    "https://rawgit.com/ninowalker/eeceb1d03fc44de918f2/raw/sample2.json"
]);
var mockQuery = RecentQuery("urn:meow", 5);
var log = console.log.bind(console);

var ConnectionFactory = LivefyreTimeline.backends.factory('qa', {
    token: "eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9.eyJkb21haW4iOiAic3R1ZGlvLXFhLTEuZnlyZS5jbyIsICJleHBpcmVzIjogMTQ0MDcxMzczNi41NDUwMzIsICJ1c2VyX2lkIjogIlRFTVAtNjcxZWI2MTQwNDU4MWIwOCJ9.ZzRLomJSKL6OkqbxqPKdLDgpyeDH3A6HxUZS8t2bGIg"
});

var realChronos = ConnectionFactory.chronos();
var realQuery = RecentQuery("urn:livefyre:studio-qa-1.fyre.co:user=TEMP-671eb61404581b08:alertStream", 1);


var ReverseStreamComponent = React.createClass({
    getInitialState: function () {
        var cursor = this.props.client.openCursor(this.props.query);
        var pager = new SimplePager(cursor, {autoLoad: false});
        pager.on('readable', this.onReadable.bind(this));
        pager.on('error', function (event) {
            log('error', event);
        });
        pager.on('initialized', function (event) {
            log("initialized");
        });

        pager.on('end', function () {
            log("pager issued end")
            this.setState({done: true, estimated: false})
        }.bind(this));

        return {
            cursor: cursor,
            pager: pager,
            items: [],
            count: undefined,
            estimated: true,
            done: false,
            seen: {}
        }
    },

    onReadable: function (event) {
        console.log("readable:", event);
        var pager = this.state.pager;
        var data = pager.read({loadOnFault: false});
        var new_items = this.state.items;
        var seen = this.state.seen;
        if (Array.isArray(data)) {
            log("read:", data.length);
            data.map(function (item) {
                console.log("" + item.tuuid + ": " + item.verb + ", " + item.published);
                if (seen[item.tuuid]) {
                    console.log("duplicate!");
                    return;
                }
                seen[item.tuuid] = true;
                new_items.push(item);
            });
        } else {
            log("unexpected; data is:", data);
        }
        if (pager.done()) {
            log("we're at the end of the stream", pager.done(), pager.cursor.hasNext())
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

    render: function () {
        var more = this.state.estimated ? (<button onClick={this.loadMore}>Load more</button>) : "";
        var plus = this.state.estimated ? '+' : '';
        return (
            <div>
                <h2>Item Count: {this.state.count}{plus}</h2>
                <ReactCSSTransitionGroup transitionName="newActivity">
                    {this.state.items.map(function (item) {
                        return this.renderItem(item);
                    }.bind(this))}
                </ReactCSSTransitionGroup>
                {more}
            </div>
        );
    }
});


var AlertActivityItem = React.createClass({
    render: function () {
        var i = this.props.item;
        var who = i.actor.handle || i.actor.displayName;
        var verb = i.verb == 'post' ? 'replied' : i.verb;
        var where = i.target.title;
        var what = i.object.content;
        var original = i.verb == 'like' ? i.object.content : i.object.inReplyTo.content;
        var when = i.published;
        return (
            <div>
                <hr />
                <span>Your post in {where}</span>:
                <div dangerouslySetInnerHTML={{__html: original}}></div>
                <span>{who} {verb} @ <i>{when}</i></span>
            </div>
        );
    }
})


React.render(
    (
        <div>
            <h3>Using a mocked datasource</h3>
            <ReverseStreamComponent itemComponent={AlertActivityItem} client={mockChronos} query={mockQuery} />
            <hr/>
            <h3>Using a real datasource</h3>
            <ReverseStreamComponent itemComponent={AlertActivityItem} client={realChronos} query={realQuery} />
        </div>
    ), document.getElementById('app'));